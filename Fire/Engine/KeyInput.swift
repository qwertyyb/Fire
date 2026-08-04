//
//  KeyInput.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//
import AppKit

struct KeyInput: Equatable {
    enum EventType: Equatable {
        case keyDown
        case flagsChanged
        case modifierPress
    }

    let type: EventType
    let keyCode: UInt16
    let characters: String?
    let charactersIgnoringModifiers: String?
    /// 已 intersection(.deviceIndependentFlagsMask)，剔除设备相关的脏标志位
    let modifiers: NSEvent.ModifierFlags

    init(event: NSEvent) {
        self.type = event.type == .flagsChanged ? .flagsChanged : .keyDown
        self.keyCode = event.keyCode
        self.characters = event.type == .flagsChanged ? nil : event.characters
        self.charactersIgnoringModifiers = event.type == .flagsChanged ? nil : event.charactersIgnoringModifiers
        self.modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    }

    // 测试用便利构造
    init(
        type: EventType = .keyDown,
        keyCode: UInt16,
        characters: String? = nil,
        charactersIgnoringModifiers: String? = nil,
        modifiers: NSEvent.ModifierFlags = []
    ) {
        self.type = type
        self.keyCode = keyCode
        self.characters = characters
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.modifiers = modifiers.intersection(.deviceIndependentFlagsMask)
    }
}
