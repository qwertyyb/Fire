//
//  InputShortcut.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/15.
//

import Carbon

struct InputShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt

    init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    func matches(_ event: KeyInput) -> Bool {
        event.keyCode == keyCode && event.modifiers.rawValue == modifiers
    }

    static let digitByKeyCode: [UInt16: Int] = [
        UInt16(kVK_ANSI_1): 1, UInt16(kVK_ANSI_2): 2, UInt16(kVK_ANSI_3): 3,
        UInt16(kVK_ANSI_4): 4, UInt16(kVK_ANSI_5): 5, UInt16(kVK_ANSI_6): 6,
        UInt16(kVK_ANSI_7): 7, UInt16(kVK_ANSI_8): 8, UInt16(kVK_ANSI_9): 9,
    ]
}

struct DigitInputShortcut: Codable, Equatable {
    var modifiers: UInt

    init(modifiers: UInt) {
        self.modifiers = modifiers
    }

    func matches(_ event: KeyInput) -> Bool {
        guard event.modifiers.rawValue == modifiers else { return false }
        return InputShortcut.digitByKeyCode[event.keyCode] != nil
    }
}
