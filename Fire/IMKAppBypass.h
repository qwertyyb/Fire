//
//  IMKAppBypass.h
//  Fire
//
//  Debug-only IMK client bypass for Xcode (and other configured apps).
//  Prevents synchronous IMK XPC replies from freezing the client while the
//  input method is paused on a breakpoint.
//

#ifndef IMKAppBypass_h
#define IMKAppBypass_h

#import <Foundation/Foundation.h>

#if DEBUG

NS_ASSUME_NONNULL_BEGIN

/// Add a client bundle ID that should skip the input method business path.
void IMKAppBypassAddBundleID(NSString *bundleID);

/// Remove a previously added bypass bundle ID.
void IMKAppBypassRemoveBundleID(NSString *bundleID);

NS_ASSUME_NONNULL_END

#endif /* DEBUG */

#endif /* IMKAppBypass_h */
