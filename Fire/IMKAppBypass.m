//
//  IMKAppBypass.m
//  Fire
//
//! Debug-only helper that short-circuits IMKInputController business methods
//! when the client is Xcode (or another configured app), so Cmd+R debugging
//! with breakpoints does not freeze the client via synchronous IMK XPC.
//!
//! Rules from the design notes:
//! - No logging / os_log / NSLog on the hook hot path (libLogRedirect deadlock).
//! - Re-evaluate client identity on every call (IMK reuses controllers).
//! - Locate the controller class via Info.plist, not a hard-coded class name.
//! - Bypass business init via objc_msgSendSuper so IMKInputController still inits.
//!

#if DEBUG

#import "IMKAppBypass.h"

#import <AppKit/AppKit.h>
#import <InputMethodKit/InputMethodKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <os/lock.h>

#pragma mark - Bypass list

static NSMutableSet<NSString *> *sBypassedBundleIDs;
static dispatch_once_t sBypassOnce;
static os_unfair_lock sBypassLock = OS_UNFAIR_LOCK_INIT;

static NSArray<NSString *> *DefaultBypassedBundleIDs(void) {
    return @[ @"com.apple.dt.Xcode" ];
}

static void EnsureBypassList(void) {
    dispatch_once(&sBypassOnce, ^{
        sBypassedBundleIDs = [NSMutableSet setWithArray:DefaultBypassedBundleIDs()];
    });
}

void IMKAppBypassAddBundleID(NSString *bundleID) {
    if (bundleID.length == 0) {
        return;
    }
    EnsureBypassList();
    os_unfair_lock_lock(&sBypassLock);
    [sBypassedBundleIDs addObject:bundleID];
    os_unfair_lock_unlock(&sBypassLock);
}

void IMKAppBypassRemoveBundleID(NSString *bundleID) {
    if (bundleID.length == 0) {
        return;
    }
    EnsureBypassList();
    os_unfair_lock_lock(&sBypassLock);
    [sBypassedBundleIDs removeObject:bundleID];
    os_unfair_lock_unlock(&sBypassLock);
}

static BOOL IsBundleIDBypassed(NSString *bundleID) {
    if (bundleID.length == 0) {
        return NO;
    }
    EnsureBypassList();
    os_unfair_lock_lock(&sBypassLock);
    BOOL hit = [sBypassedBundleIDs containsObject:bundleID];
    os_unfair_lock_unlock(&sBypassLock);
    return hit;
}

#pragma mark - Client identity

static NSString *BundleIDFromObject(id object) {
    if (object == nil) {
        return nil;
    }

    if ([object isKindOfClass:[NSString class]]) {
        return (NSString *)object;
    }

    if ([object isKindOfClass:[NSRunningApplication class]]) {
        return [(NSRunningApplication *)object bundleIdentifier];
    }

    // IMKTextInput / client objects expose bundleIdentifier.
    if ([object respondsToSelector:@selector(bundleIdentifier)]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(object, @selector(bundleIdentifier));
        if ([value isKindOfClass:[NSString class]]) {
            return (NSString *)value;
        }
    }

    return nil;
}

/// Triple check union: frontmost app / call argument / controller.client.
/// Never cache the result — one controller instance switches across apps.
static BOOL ShouldBypassIMKCall(id controller, id object) {
    if (IsBundleIDBypassed(NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier)) {
        return YES;
    }
    if (IsBundleIDBypassed(BundleIDFromObject(object))) {
        return YES;
    }
    if ([controller respondsToSelector:@selector(client)]) {
        id client = ((id (*)(id, SEL))objc_msgSend)(controller, @selector(client));
        if (IsBundleIDBypassed(BundleIDFromObject(client))) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Controller class discovery

static Class ResolveInputControllerClass(void) {
    NSString *className =
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"InputMethodServerControllerClass"];
    NSString *moduleName =
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"];
    if (className.length == 0) {
        return Nil;
    }
    if (moduleName.length > 0) {
        className = [className stringByReplacingOccurrencesOfString:@"$(PRODUCT_MODULE_NAME)"
                                                         withString:moduleName];
    }
    return NSClassFromString(className);
}

#pragma mark - Method hook helpers

typedef id (^IMKBypassReplacementFactory)(__unsafe_unretained Class originClass,
                                          SEL originCMD,
                                          IMP (^originalIMPProvider)(void));

/// Replace `sel` on `cls` only when this class has its own implementation.
static BOOL HookDirectMethod(Class cls, SEL sel, IMKBypassReplacementFactory factory) {
    if (cls == Nil || factory == nil) {
        return NO;
    }

    Method method = class_getInstanceMethod(cls, sel);
    if (method == NULL) {
        return NO;
    }

    Class superCls = class_getSuperclass(cls);
    if (superCls != Nil) {
        Method superMethod = class_getInstanceMethod(superCls, sel);
        if (superMethod != NULL &&
            method_getImplementation(method) == method_getImplementation(superMethod)) {
            // Inherited from superclass — not a direct override on this class.
            return NO;
        }
    }

    IMP originalIMP = method_getImplementation(method);
    IMP (^originalIMPProvider)(void) = ^{
        return originalIMP;
    };

    id replacementBlock = factory(cls, sel, originalIMPProvider);
    if (replacementBlock == nil) {
        return NO;
    }

    IMP newIMP = imp_implementationWithBlock(replacementBlock);
    const char *types = method_getTypeEncoding(method);
    class_replaceMethod(cls, sel, newIMP, types);
    return YES;
}

/// Walk from leaf controller class up to (but not including) IMKInputController
/// and hook every class that directly implements `sel`.
static void HookAlongInheritance(Class leaf, SEL sel, IMKBypassReplacementFactory factory) {
    Class imkRoot = [IMKInputController class];
    for (Class cls = leaf; cls != Nil && cls != imkRoot; cls = class_getSuperclass(cls)) {
        HookDirectMethod(cls, sel, factory);
    }
}

#pragma mark - Hooks

static void InstallIMKAppBypassHooks(void) {
    Class controllerClass = ResolveInputControllerClass();
    if (controllerClass == Nil) {
        return;
    }
    EnsureBypassList();

    // initWithServer:delegate:client: — skip business init body; keep IMKInputController init.
    HookAlongInheritance(controllerClass, @selector(initWithServer:delegate:client:),
                          ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
        return ^id(__unsafe_unretained id selfObject, id server, id delegate, id client) {
            BOOL shouldBypass = ShouldBypassIMKCall(nil, client);
            if (shouldBypass && originClass != IMKInputController.class) {
                struct objc_super superInfo;
                superInfo.receiver = selfObject;
                superInfo.super_class = class_getSuperclass(originClass);
                id (*superInit)(struct objc_super *, SEL, id, id, id) =
                    (id (*)(struct objc_super *, SEL, id, id, id))objc_msgSendSuper;
                return superInit(&superInfo, originCMD, server, delegate, client);
            }
            id (*orig)(id, SEL, id, id, id) =
                (id (*)(id, SEL, id, id, id))originalIMPProvider();
            return orig(selfObject, originCMD, server, delegate, client);
        };
    });

    // activateServer: / deactivateServer: / commitComposition: — void, early return.
    void (^installVoidSenderHook)(SEL) = ^(SEL sel) {
        HookAlongInheritance(controllerClass, sel,
                             ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            (void)originClass;
            return ^void(__unsafe_unretained id selfObject, id sender) {
                if (ShouldBypassIMKCall(selfObject, sender)) {
                    return;
                }
                void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))originalIMPProvider();
                orig(selfObject, originCMD, sender);
            };
        });
    };
    installVoidSenderHook(@selector(activateServer:));
    installVoidSenderHook(@selector(deactivateServer:));
    installVoidSenderHook(@selector(commitComposition:));

    // handleEvent:client: / handle:client: — BOOL, return NO (do not consume).
    // Swift override `handle(_:client:)` maps to either selector depending on SDK.
    void (^installHandleHook)(SEL) = ^(SEL sel) {
        HookAlongInheritance(controllerClass, sel,
                             ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            (void)originClass;
            return ^BOOL(__unsafe_unretained id selfObject, id eventOrNil, id client) {
                if (ShouldBypassIMKCall(selfObject, client ?: eventOrNil)) {
                    return NO;
                }
                BOOL (*orig)(id, SEL, id, id) =
                    (BOOL (*)(id, SEL, id, id))originalIMPProvider();
                return orig(selfObject, originCMD, eventOrNil, client);
            };
        });
    };
    installHandleHook(@selector(handleEvent:client:));
    installHandleHook(sel_registerName("handle:client:"));

    // inputText:client:
    HookAlongInheritance(controllerClass, @selector(inputText:client:),
                          ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
        (void)originClass;
        return ^BOOL(__unsafe_unretained id selfObject, id string, id client) {
            if (ShouldBypassIMKCall(selfObject, client)) {
                return NO;
            }
            BOOL (*orig)(id, SEL, id, id) = (BOOL (*)(id, SEL, id, id))originalIMPProvider();
            return orig(selfObject, originCMD, string, client);
        };
    });

    // inputText:key:modifiers:client:
    HookAlongInheritance(controllerClass, @selector(inputText:key:modifiers:client:),
                          ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
        (void)originClass;
        return ^BOOL(__unsafe_unretained id selfObject, id string, NSInteger keyCode,
                     NSUInteger modifiers, id client) {
            if (ShouldBypassIMKCall(selfObject, client)) {
                return NO;
            }
            BOOL (*orig)(id, SEL, id, NSInteger, NSUInteger, id) =
                (BOOL (*)(id, SEL, id, NSInteger, NSUInteger, id))originalIMPProvider();
            return orig(selfObject, originCMD, string, keyCode, modifiers, client);
        };
    });

    // didCommandBySelector:client:
    HookAlongInheritance(controllerClass, @selector(didCommandBySelector:client:),
                          ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
        (void)originClass;
        return ^BOOL(__unsafe_unretained id selfObject, SEL commandSelector, id client) {
            if (ShouldBypassIMKCall(selfObject, client)) {
                return NO;
            }
            BOOL (*orig)(id, SEL, SEL, id) =
                (BOOL (*)(id, SEL, SEL, id))originalIMPProvider();
            return orig(selfObject, originCMD, commandSelector, client);
        };
    });

    // recognizedEvents: — return 0 so IMK stops delivering key events for this client.
    HookAlongInheritance(controllerClass, @selector(recognizedEvents:),
                          ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
        (void)originClass;
        return ^NSUInteger(__unsafe_unretained id selfObject, id sender) {
            if (ShouldBypassIMKCall(selfObject, sender)) {
                return 0;
            }
            NSUInteger (*orig)(id, SEL, id) =
                (NSUInteger (*)(id, SEL, id))originalIMPProvider();
            return orig(selfObject, originCMD, sender);
        };
    });

    // menu — return nil so status bar menu path does not enter business code.
    HookAlongInheritance(controllerClass, @selector(menu),
                          ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
        (void)originClass;
        return ^id(__unsafe_unretained id selfObject) {
            if (ShouldBypassIMKCall(selfObject, nil)) {
                return nil;
            }
            id (*orig)(id, SEL) = (id (*)(id, SEL))originalIMPProvider();
            return orig(selfObject, originCMD);
        };
    });

    // showPreferences: — void early return.
    HookAlongInheritance(controllerClass, @selector(showPreferences:),
                          ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
        (void)originClass;
        return ^void(__unsafe_unretained id selfObject, id sender) {
            if (ShouldBypassIMKCall(selfObject, sender)) {
                return;
            }
            void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))originalIMPProvider();
            orig(selfObject, originCMD, sender);
        };
    });
}

__attribute__((constructor))
static void IMKAppBypassConstructor(void) {
    InstallIMKAppBypassHooks();
}

#endif /* DEBUG */
