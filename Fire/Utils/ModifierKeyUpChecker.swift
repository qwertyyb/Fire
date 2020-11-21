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
    init(_ modifier: NSEvent.ModifierFlags, keyCode: Int) {
        checkModifier = modifier
        checkKeyCode = keyCode
    }
    let checkModifier: NSEvent.ModifierFlags
    let checkKeyCode: Int

    private let delayInterval = 0.3

    private var lastTime: Date = Date()

    // 检查修饰键被按下并抬起
    func check(_ event: NSEvent) -> Bool {
        let flag = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .flagsChanged
            && flag == .init(rawValue: 0)
            && Date() - lastTime <= delayInterval {
            // modifier keyup event
            lastTime = Date(timeInterval: -3600*4, since: Date())
            return true
        }
        if event.type == .flagsChanged && flag == checkModifier && event.keyCode == checkKeyCode {
            // modifier keydown event
            lastTime = Date()
        } else {
            lastTime = Date(timeInterval: -3600*4, since: Date())
        }
        return false
    }
}
