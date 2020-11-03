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

class ModifierKeyUpChecker {
    init(_ modifier: NSEvent.ModifierFlags) {
        checkModifier = modifier
    }
    private let checkModifier: NSEvent.ModifierFlags

    // 上上步按下的键
    private var lastLastModifier: NSEvent.ModifierFlags = .init(rawValue: 0)

    // 上步按下的键
    private var lastModifier: NSEvent.ModifierFlags = .init(rawValue: 0)

    private func isKeyPress(_ event: NSEvent) -> Bool {
        return event.type == .flagsChanged
            && event.modifierFlags == .init(rawValue: 0) // 当前flags为0
            && lastModifier == checkModifier    // 上次按键的flags为checkModifier
            && lastLastModifier == .init(rawValue: 0) // 上上次的按键flags为0
    }

    // 检查shift键被按下并抬起
    func check(_ event: NSEvent) -> Bool {
        var flag = false
        if isKeyPress(event) {  // shift键按下抬起，flags序列: 0, shift, 0
            flag = true
        }
        lastLastModifier = lastModifier
        lastModifier = event.type == .flagsChanged ? event.modifierFlags : .init(rawValue: 0)
        return flag
    }
}
