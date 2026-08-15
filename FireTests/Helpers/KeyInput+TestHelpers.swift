import AppKit
import Carbon
@testable import Fire

enum Key {
    static func keyDown(
        keyCode: Int,
        characters: String? = nil,
        modifiers: NSEvent.ModifierFlags = []
    ) -> KeyInput {
        KeyInput(
            type: .keyDown,
            keyCode: UInt16(keyCode),
            characters: characters,
            charactersIgnoringModifiers: characters,
            modifiers: modifiers
        )
    }

    static func a() -> KeyInput { keyDown(keyCode: kVK_ANSI_A, characters: "a") }
    static func b() -> KeyInput { keyDown(keyCode: kVK_ANSI_B, characters: "b") }
    static func z() -> KeyInput { keyDown(keyCode: kVK_ANSI_Z, characters: "z") }
    static func semicolon() -> KeyInput { keyDown(keyCode: kVK_ANSI_Semicolon, characters: ";") }
    static func delete() -> KeyInput { keyDown(keyCode: kVK_Delete) }
    static func space() -> KeyInput { keyDown(keyCode: kVK_Space, characters: " ") }
    static func returnKey() -> KeyInput { keyDown(keyCode: kVK_Return) }
    static func escape() -> KeyInput { keyDown(keyCode: kVK_Escape) }
    static func period() -> KeyInput { keyDown(keyCode: kVK_ANSI_Period, characters: ".") }
    static func equal() -> KeyInput { keyDown(keyCode: kVK_ANSI_Equal, characters: "=") }
    static func minus() -> KeyInput { keyDown(keyCode: kVK_ANSI_Minus, characters: "-") }
    static func leftArrow() -> KeyInput { keyDown(keyCode: kVK_LeftArrow) }
    static func rightArrow() -> KeyInput { keyDown(keyCode: kVK_RightArrow) }
    static func upArrow() -> KeyInput { keyDown(keyCode: kVK_UpArrow) }
    static func downArrow() -> KeyInput { keyDown(keyCode: kVK_DownArrow) }

    static func digit(_ n: Int) -> KeyInput {
        let keyCodes = [
            kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
            kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
        ]
        return keyDown(keyCode: keyCodes[n - 1], characters: "\(n)")
    }

    static func shiftModifierPress() -> KeyInput {
        KeyInput(type: .modifierPress, keyCode: UInt16(kVK_Shift), modifiers: .shift)
    }

    static func flagsChanged(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> KeyInput {
        KeyInput(type: .flagsChanged, keyCode: UInt16(keyCode), modifiers: modifiers)
    }

    static func ctrlShiftDigit(_ n: Int) -> KeyInput {
        digit(n).withModifiers([.control, .shift])
    }

    static func ctrlOptionDigit(_ n: Int) -> KeyInput {
        digit(n).withModifiers([.control, .option])
    }

    static func withShortcut(_ shortcut: InputShortcut) -> KeyInput {
        keyDown(
            keyCode: Int(shortcut.keyCode),
            characters: InputShortcutFormatting.keyLabel(for: shortcut.keyCode),
            modifiers: shortcut.modifierFlags
        )
    }

    static func withDigitShortcut(_ shortcut: DigitInputShortcut, digit n: Int) -> KeyInput {
        digit(n).withModifiers(shortcut.modifierFlags)
    }

    static func ctrlEqual() -> KeyInput {
        equal().withModifiers(.control)
    }
}

private extension KeyInput {
    func withModifiers(_ modifiers: NSEvent.ModifierFlags) -> KeyInput {
        KeyInput(
            type: type,
            keyCode: keyCode,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            modifiers: modifiers
        )
    }
}
