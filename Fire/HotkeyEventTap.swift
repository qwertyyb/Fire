//
//  HotkeyEventTap.swift
//  Fire
//
//  Created by 虚幻 on 2024/12/23.
//  Copyright © 2024 qwertyyb. All rights reserved.
//

import Cocoa
import Carbon
import Defaults

/// 系统级事件拦截器，在应用收到键盘事件之前拦截热键组合键。
///
/// 某些应用（如 Sublime Text、VS Code 等）会拦截 Ctrl+数字 等组合键，
/// 不转发给 InputMethodKit 输入法，导致业火五笔的热键失效。
/// 本类使用 CGEventTap 在系统级拦截这些事件，消费掉（应用收不到），
/// 然后通过输入控制器的事件处理链正常处理。
class HotkeyEventTap {
    static let shared = HotkeyEventTap()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    private let digitKeyCodes: Set<UInt16> = [
        UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3),
        UInt16(kVK_ANSI_4), UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_6),
        UInt16(kVK_ANSI_7), UInt16(kVK_ANSI_8), UInt16(kVK_ANSI_9)
    ]
    private let equalKeyCode = UInt16(kVK_ANSI_Equal)

    /// 启动事件拦截
    func start() {
        guard !isRunning else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<HotkeyEventTap>.fromOpaque(refcon).takeUnretainedValue()
                return tap.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            NSLog("[HotkeyEventTap] 创建事件拦截失败，请授予辅助功能权限")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            NSLog("[HotkeyEventTap] 创建 RunLoop 源失败")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        isRunning = true
        NSLog("[HotkeyEventTap] 已启动")
    }

    /// 停止事件拦截
    func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        NSLog("[HotkeyEventTap] 已停止")
    }

    /// 检查当前进程是否拥有辅助功能权限
    /// 用于在 event tap 创建失败时给予更友好的提示
    static var isProcessTrusted: Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - 事件处理

    private func isFireSelf() -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    /// 检测当前事件是否为业火五笔的热键
    private func isHotkey(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        let relevantFlags: CGEventFlags = [.maskControl, .maskShift, .maskCommand, .maskAlternate]
        let modifiers = flags.intersection(relevantFlags)
        let hotkeyFlag = Defaults[.hotkeyModifier].cgEventFlag

        // {hotkey}+Shift+数字 / {hotkey}+数字 / {hotkey}+=
        if modifiers == [hotkeyFlag, .maskShift] && digitKeyCodes.contains(keyCode) { return true }
        if modifiers == hotkeyFlag && digitKeyCodes.contains(keyCode) { return true }
        if modifiers == hotkeyFlag && keyCode == equalKeyCode { return true }
        return false
    }

    /// 将热键事件转发给输入控制器处理
    private func forwardToInputController(cgEvent: CGEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 再次确认业火五笔仍为当前输入法
            guard InputSource.shared.isSelected() else { return }

            guard let controller = CandidatesWindow.shared.inputController else { return }
            guard let nsEvent = NSEvent(cgEvent: cgEvent) else { return }
            _ = controller.handle(nsEvent, client: controller.client())
        }
    }

    /// CGEventTap 回调的处理核心
    /// - Returns: 返回 nil 表示消费事件（应用收不到），返回 event 表示放行
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByUserInput, .tapDisabledByTimeout:
            NSLog("[HotkeyEventTap] 拦截器已被禁用（\(type == .tapDisabledByUserInput ? "用户" : "超时")）")
            return nil
        case .keyDown:
            break
        default:
            return Unmanaged.passUnretained(event)
        }

        // 在 Fire 自身（偏好设置等）窗口时不拦截，避免影响正常 UI 操作
        guard !isFireSelf() else {
            return Unmanaged.passUnretained(event)
        }

        // 仅当业火五笔是当前选中输入法时才拦截
        guard InputSource.shared.isSelected() else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        guard isHotkey(keyCode: keyCode, flags: flags) else {
            return Unmanaged.passUnretained(event)
        }

        NSLog("[HotkeyEventTap] 拦截热键: keyCode=\(keyCode) flags=\(flags.rawValue)")

        // 消费事件（应用收不到），转发给输入控制器处理
        forwardToInputController(cgEvent: event)
        return nil
    }
}
