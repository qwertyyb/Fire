//
//  InputShortcut.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/15.
//

import AppKit
import Carbon
import Defaults
import SwiftUI

struct InputShortcut: Codable, Defaults.Serializable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt

    init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(.deviceIndependentFlagsMask).rawValue
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)
    }

    func matches(_ event: KeyInput) -> Bool {
        event.keyCode == keyCode && event.modifiers.rawValue == modifiers
    }

    var displayLabel: String {
        InputShortcutFormatting.label(modifiers: modifierFlags, keyCode: keyCode)
    }

    static let defaultQuickCombine = InputShortcut(
        keyCode: UInt16(kVK_ANSI_Equal),
        modifiers: .control
    )
}

struct DigitInputShortcut: Codable, Defaults.Serializable, Equatable {
    var modifiers: UInt

    init(modifiers: UInt) {
        self.modifiers = modifiers
    }

    init(modifiers: NSEvent.ModifierFlags) {
        self.modifiers = modifiers.intersection(.deviceIndependentFlagsMask).rawValue
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)
    }

    func matches(_ event: KeyInput) -> Bool {
        guard event.modifiers.rawValue == modifiers else { return false }
        return InputShortcut.digitByKeyCode[event.keyCode] != nil
    }

    var displayLabel: String {
        InputShortcutFormatting.label(modifiers: modifierFlags, keyCode: nil, includeDigitPlaceholder: true)
    }

    static let defaultPinCandidate = DigitInputShortcut(modifiers: [.control, .option])
    static let defaultDeleteCandidate = DigitInputShortcut(modifiers: [.control, .shift])
}

/// Defaults 对 Optional 赋 nil 会删除键并回退到 Key 默认值，无法持久化「已清除」。
/// 用 explicit cleared 状态写入 UserDefaults。
struct StoredShortcut<T: Codable & Defaults.Serializable & Equatable>: Codable, Defaults.Serializable, Equatable {
    private enum State: String, Codable {
        case active
        case cleared
    }

    private var state: State
    private var shortcut: T

    var value: T? {
        state == .active ? shortcut : nil
    }

    init(active shortcut: T) {
        state = .active
        self.shortcut = shortcut
    }

    init(value: T?, placeholder: T) {
        if let value {
            state = .active
            shortcut = value
        } else {
            state = .cleared
            shortcut = placeholder
        }
    }
}

typealias StoredInputShortcut = StoredShortcut<InputShortcut>
typealias StoredDigitInputShortcut = StoredShortcut<DigitInputShortcut>

enum InputShortcutFormatting {
    static let digitByKeyCode: [UInt16: Int] = [
        UInt16(kVK_ANSI_1): 1, UInt16(kVK_ANSI_2): 2, UInt16(kVK_ANSI_3): 3,
        UInt16(kVK_ANSI_4): 4, UInt16(kVK_ANSI_5): 5, UInt16(kVK_ANSI_6): 6,
        UInt16(kVK_ANSI_7): 7, UInt16(kVK_ANSI_8): 8, UInt16(kVK_ANSI_9): 9,
    ]

    static let modifierKeyCodes: Set<UInt16> = [
        UInt16(kVK_Shift), UInt16(kVK_RightShift),
        UInt16(kVK_Control), UInt16(kVK_RightControl),
        UInt16(kVK_Option), UInt16(kVK_RightOption),
        UInt16(kVK_Command), UInt16(kVK_RightCommand),
        UInt16(kVK_Function),
        UInt16(kVK_CapsLock),
    ]

    static func label(
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16?,
        includeDigitPlaceholder: Bool = false
    ) -> String {
        var parts = modifierLabels(for: modifiers)
        if includeDigitPlaceholder {
            parts.append("数字")
        } else if let keyCode {
            parts.append(keyLabel(for: keyCode))
        }
        return parts.joined(separator: "+")
    }

    static func modifierLabels(for flags: NSEvent.ModifierFlags) -> [String] {
        var labels: [String] = []
        if flags.contains(.control) { labels.append("control") }
        if flags.contains(.option) { labels.append("option") }
        if flags.contains(.shift) { labels.append("shift") }
        if flags.contains(.command) { labels.append("command") }
        if flags.contains(.function) { labels.append("fn") }
        return labels
    }

    static func keyLabel(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_Space: return "space"
        case kVK_Return: return "return"
        case kVK_Escape: return "esc"
        case kVK_Delete: return "delete"
        case kVK_Tab: return "tab"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            if let digit = digitByKeyCode[keyCode] {
                return "\(digit)"
            }
            if keyCode >= UInt16(kVK_ANSI_A), keyCode <= UInt16(kVK_ANSI_Z) {
                let scalar = UnicodeScalar(Int(keyCode - UInt16(kVK_ANSI_A)) + Int(UnicodeScalar("a").value))!
                return String(Character(scalar))
            }
            return "键\(keyCode)"
        }
    }

    static func conflicts(
        quickCombine: InputShortcut?,
        pinCandidate: DigitInputShortcut?,
        deleteCandidate: DigitInputShortcut?
    ) -> String? {
        if let pin = pinCandidate, let delete = deleteCandidate,
           pin.modifiers == delete.modifiers {
            return "「候选词置顶」与「删除候选词」使用了相同的修饰键组合"
        }
        if let quickCombine, let pin = pinCandidate,
           quickCombine.modifiers == pin.modifiers,
           digitByKeyCode[quickCombine.keyCode] != nil {
            return "「快速组词」与「候选词置顶」冲突"
        }
        if let quickCombine, let delete = deleteCandidate,
           quickCombine.modifiers == delete.modifiers,
           digitByKeyCode[quickCombine.keyCode] != nil {
            return "「快速组词」与「删除候选词」冲突"
        }
        return nil
    }
}

extension InputShortcut {
    static var digitByKeyCode: [UInt16: Int] {
        InputShortcutFormatting.digitByKeyCode
    }
}

struct InputShortcutDisplay: View {
    let modifiers: NSEvent.ModifierFlags
    var keyCode: UInt16?
    var includeDigitPlaceholder: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            let labels = InputShortcutFormatting.modifierLabels(for: modifiers)
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                if index > 0 {
                    Text("+")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                modifierIcon(label)
            }
            if includeDigitPlaceholder {
                Text("+")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                KeyCap("数字")
            } else if let keyCode {
                Text("+")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                KeyCap(InputShortcutFormatting.keyLabel(for: keyCode))
            }
        }
    }

    @ViewBuilder
    private func modifierIcon(_ label: String) -> some View {
        if let systemName = modifierSystemName(label) {
            KeyCap(icon: systemName)
        }
    }

    private func modifierSystemName(_ label: String) -> String? {
        switch label {
        case "control": return "control"
        case "option": return "option"
        case "shift": return "shift"
        case "command": return "command"
        case "fn": return "globe"
        default: return nil
        }
    }
}
