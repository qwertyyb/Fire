//
//  checkShiftUp.swift
//  Fire
//
//  Created by 虚幻 on 2020/8/15.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

import Cocoa
import InputMethodKit

// 检查shift键被抬起
func createCheckShiftKeyUpFn() -> (NSEvent) -> Bool {
    var lastModifier: NSEvent.ModifierFlags = .init(rawValue: 0)
    func checkShiftKeyUp(_ event: NSEvent) -> Bool {
        if event.type == .flagsChanged && event.modifierFlags == .init(rawValue: 0) && lastModifier == .shift {  // shift键抬起
            lastModifier = event.modifierFlags
            return true
        }
        lastModifier = event.type == .flagsChanged ? event.modifierFlags : .init(rawValue: 0)
        return false
    }
    return  checkShiftKeyUp
}

let checkShiftKeyUp = createCheckShiftKeyUpFn()
