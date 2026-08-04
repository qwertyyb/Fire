//
//  KeyUpChecker.swift
//  Fire
//
//  Created by marchyang on 2020/10/26.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import AppKit
import Carbon
import Defaults

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }

}

class ModifierKeyPressChecker {
    var checkModifierKey: ModifierKey
    private var checkModifier: NSEvent.ModifierFlags {
        switch self.checkModifierKey {
        case .command:
            return NSEvent.ModifierFlags.command
        case .control:
            return NSEvent.ModifierFlags.control
        case .shift, .leftShift, .rightShift:
            // leftShift/rightShift 统一映射到 shift 标志位，系统 flagsChanged 事件中左右 Shift 共享同一个 modifier flag
            return NSEvent.ModifierFlags.shift
        case .option:
            return NSEvent.ModifierFlags.option
        case .function:
            return NSEvent.ModifierFlags.function
        }
    }
    var checkKeyCode: [Int] {
        switch self.checkModifierKey {
        case .shift:
            return [kVK_Shift, kVK_RightShift]
        case .leftShift:
            return [kVK_Shift]
        case .rightShift:
            return [kVK_RightShift]
        case .command:
            return [kVK_Command, kVK_RightCommand]
        case .control:
            return [kVK_Control, kVK_RightControl]
        case .option:
            return [kVK_Option, kVK_RightOption]
        case .function:
            return [kVK_Function]
        }
    }

    private let delayInterval = 0.2

    private var lastTime: Date = Date()

    private func checkModifierKeyUp (event: NSEvent) -> Bool {
        guard checkKeyCode.contains(Int(event.keyCode)) else { return false }
        if event.type == .flagsChanged
            && event.modifierFlags == .init(rawValue: 0)
            && Date() - lastTime <= delayInterval {
            // modifier keyup event
            lastTime = Date(timeInterval: -3600*4, since: Date())
            return true
        }
        return false
    }

    private func checkModifierKeyDown(event: NSEvent) -> Bool {
        let isKeyDown = event.type == .flagsChanged
            && event.modifierFlags == checkModifier
            && checkKeyCode.contains(Int(event.keyCode))
        if isKeyDown {
            // modifier keydown event
            lastTime = Date()
        } else {
            lastTime = Date(timeInterval: -3600*4, since: Date())
        }
        return false
    }

    // 检查修饰键被按下并抬起
    func check(_ event: NSEvent) -> Bool {
        return checkModifierKeyUp(event: event) || checkModifierKeyDown(event: event)
    }
    
    private func handler(event: NSEvent) {
        if check(event) {
            callback(event)
        }
    }
    
    private var monitors: [Any?] = []
    private let callback: (NSEvent) -> Void
    
    init(modifierKey: ModifierKey, callback: @escaping (NSEvent) -> Void) {
        self.checkModifierKey = modifierKey
        self.callback = callback
        // 由于使用IMKInputController recognizedEvents在一些场景下不能监听到flagChanged事件，比如保存文件和lanchPad场景
        // 所以这里需要使用NSEvent.addGlobalMonitorForEvents监听shift键被按下
        // 保存 globalMonitor 引用，用于 deinit 时移除
        // 必须先完成全部存储属性初始化，再在闭包里捕获 self
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] (event) in
                FireLog.input.debug("globalMonitorForEvents flagsChanged: \(String(describing: event), privacy: .public)")
                self?.handler(event: event)
            }
        ]
    }
    
    deinit {
        monitors.forEach { monitor in
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
