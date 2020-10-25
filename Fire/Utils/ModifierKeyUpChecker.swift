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
        lastModifier = .init(rawValue: 0)
    }
    private let checkModifier: NSEvent.ModifierFlags

    private var lastModifier: NSEvent.ModifierFlags

    // 检查shift键被抬起
    func check(_ event: NSEvent) -> Bool {
        if event.type == .flagsChanged
            && event.modifierFlags == .init(rawValue: 0)
            && lastModifier == checkModifier {  // shift键抬起
            lastModifier = event.modifierFlags
            return true
        }
        lastModifier = event.type == .flagsChanged ? event.modifierFlags : .init(rawValue: 0)
        return false
    }
}
