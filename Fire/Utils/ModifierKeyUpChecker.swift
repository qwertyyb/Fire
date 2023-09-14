//
//  KeyUpChecker.swift
//  Fire
//
//  Created by marchyang on 2020/10/26.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import AppKit
import Carbon

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }

}

class ModifierKeyUpChecker {
    init(_ modifier: ModifierKey) {
        checkModifierKey = modifier
    }
    let checkModifierKey: ModifierKey
    private var checkModifier: NSEvent.ModifierFlags {
        switch self.checkModifierKey {
        case .command:
            return NSEvent.ModifierFlags.command
        case .control:
            return NSEvent.ModifierFlags.control
        case .shift:
            return NSEvent.ModifierFlags.shift
        case .option:
            return NSEvent.ModifierFlags.option
        case .function:
            return NSEvent.ModifierFlags.function
        default:
            return NSEvent.ModifierFlags.shift
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
        default:
            return []
        }
    }

    private let delayInterval = 0.3

    private var lastTime: Date = Date()

    private func checkModifierKeyUp (event: NSEvent) -> Bool {
        guard checkKeyCode.contains(Int(event.keyCode)) else { return false }
        if event.type == .flagsChanged
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .init(rawValue: 0)
            && Date() - lastTime <= delayInterval {
            // modifier keyup event
            lastTime = Date(timeInterval: -3600*4, since: Date())
            return true
        }
        return false
    }

    private func checkModifierKeyDown(event: NSEvent) -> Bool {
        let isKeyDown = event.type == .flagsChanged
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == checkModifier
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
}
