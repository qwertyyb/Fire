//
//  EngineUtils.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//

import Carbon
import Defaults

enum EngineUtils {
    static func isDeleteKey (_ event: KeyInput) -> Bool {
        // 按退格键或control+h
        return event.modifiers.isEmpty && event.keyCode == kVK_Delete || event.modifiers == .control && event.keyCode == kVK_ANSI_H
    }
    
    static func isEscapeKey(_ event: KeyInput) -> Bool {
        // 按Esc或control+u
        return event.modifiers.isEmpty && event.keyCode == kVK_Escape || event.modifiers == .control && event.keyCode == kVK_ANSI_U
    }
    
    static let toggleInputModeKeyUpChecker = ModifierKeyUpChecker()
}
