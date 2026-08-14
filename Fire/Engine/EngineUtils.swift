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
    
    static func isNextPageKey(_ event: KeyInput, config: any EngineConfig) -> Bool {
        return event.keyCode == kVK_ANSI_Equal ||
        (event.keyCode == kVK_DownArrow && config.candidatesDirection == .horizontal) ||
        (event.keyCode == kVK_RightArrow && config.candidatesDirection == .vertical)
    }
    static func isPrevPageKey(_ event: KeyInput, config: any EngineConfig) -> Bool {
        return event.keyCode == kVK_ANSI_Minus ||
        (event.keyCode == kVK_UpArrow && config.candidatesDirection == .horizontal) ||
        (event.keyCode == kVK_LeftArrow && config.candidatesDirection == .vertical)
    }
    
    static func isNextSelectKey(_ event: KeyInput, config: any EngineConfig) -> Bool {
        return (event.keyCode == kVK_RightArrow && config.candidatesDirection == .horizontal) ||
        (event.keyCode == kVK_DownArrow && config.candidatesDirection == .vertical)
    }
    static func isPrevSelectKey(_ event: KeyInput, config: any EngineConfig) -> Bool {
        return (event.keyCode == kVK_LeftArrow && config.candidatesDirection == .horizontal) ||
        (event.keyCode == kVK_UpArrow && config.candidatesDirection == .vertical)
    }

    static func extraCandidateIndex(for event: KeyInput, config: any EngineConfig) -> Int? {
        guard let string = event.characters else { return nil }
        switch config.extraCandidateSelectKeys {
        case .semicolonQuote:
            switch string {
            case ";": return 1
            case "'": return 2
            default: return nil
            }
        case .commaPeriod:
            switch string {
            case ",": return 1
            case ".": return 2
            default: return nil
            }
        case .disabled:
            return nil
        }
    }
}
