//
//  KeyUpChecker.swift
//  Fire
//
//  Created by marchyang on 2020/10/26.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Foundation
import Carbon
import Cocoa

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }

}

class ModifierKeyUpChecker {
    init(_ modifier: NSEvent.ModifierFlags) {
        checkModifier = modifier
    }
    let checkModifier: NSEvent.ModifierFlags
    var checkKeyCode: Int {
        switch self.checkModifier {
        case .shift:
            return kVK_Shift
        case .command:
            return kVK_Command
        case .control:
            return kVK_Control
        case .option:
            return kVK_Option
        default:
            return 0
        }
    }

    private let delayInterval = 0.3

    private var lastTime: Date = Date()

    private func checkModifierKeyUp (event: NSEvent) -> Bool {
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
        if event.type == .flagsChanged
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == checkModifier
            && event.keyCode == checkKeyCode {
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
