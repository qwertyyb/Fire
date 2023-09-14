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

    var checkKeyCode: [UInt16] {
        var result: [Int] {
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
        return result.compactMap { UInt16($0) }
    }

    private let delayInterval = 0.3
    private var previousKeyCode: UInt16?
    private var lastTime: Date = .init()

    private func registerModifierKeyDown(event: NSEvent) {
        var isKeyDown: Bool = event.type == .flagsChanged
        isKeyDown = isKeyDown && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == checkModifier
        isKeyDown = isKeyDown && checkKeyCode.contains(event.keyCode)
        lastTime = isKeyDown ? .init() : .init(timeInterval: .infinity * -1, since: Date())
        previousKeyCode = isKeyDown ? event.keyCode : nil
    }

    // To confirm that only the shift key is "pressed-and-released".
    public func check(_ event: NSEvent) -> Bool {
        var met: Bool = event.type == .flagsChanged
        met = met && checkKeyCode.contains(event.keyCode)
        met = met && event.keyCode == previousKeyCode // 檢查 KeyCode 一致性。
        met = met && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
        met = met && Date() - lastTime <= delayInterval
        _ = met ? lastTime = .init(timeInterval: .infinity * -1, since: Date()) : registerModifierKeyDown(event: event)
        return met
    }
}
