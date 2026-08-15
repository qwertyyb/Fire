//
//  InputShortcutTests.swift
//  FireTests
//

import AppKit
import Carbon
import Testing
@testable import Fire

struct InputShortcutTests {
    @Test func quickCombineDefault_matchesControlEqual() {
        let shortcut = InputShortcut.defaultQuickCombine
        #expect(shortcut.matches(Key.ctrlEqual()))
    }

    @Test func pinCandidateDefault_matchesControlOptionDigit() {
        let shortcut = DigitInputShortcut.defaultPinCandidate
        #expect(shortcut.matches(Key.ctrlOptionDigit(2)))
        #expect(!shortcut.matches(Key.ctrlShiftDigit(2)))
    }

    @Test func deleteCandidateDefault_matchesControlShiftDigit() {
        let shortcut = DigitInputShortcut.defaultDeleteCandidate
        #expect(shortcut.matches(Key.ctrlShiftDigit(2)))
        #expect(!shortcut.matches(Key.ctrlOptionDigit(2)))
    }

    @Test func displayLabel_quickCombine() {
        let shortcut = InputShortcut.defaultQuickCombine
        #expect(shortcut.displayLabel == "control+=")
    }

    @Test func displayLabel_digitShortcut() {
        let shortcut = DigitInputShortcut.defaultPinCandidate
        #expect(shortcut.displayLabel == "control+option+数字")
    }

    @Test func conflicts_detectsSameDigitModifiers() {
        let pin = DigitInputShortcut(modifiers: [.control, .shift])
        let delete = DigitInputShortcut(modifiers: [.control, .shift])
        let conflict = InputShortcutFormatting.conflicts(
            quickCombine: .defaultQuickCombine,
            pinCandidate: pin,
            deleteCandidate: delete
        )
        #expect(conflict != nil)
    }

    @Test func conflicts_allowsDistinctDefaults() {
        #expect(InputShortcutFormatting.conflicts(
            quickCombine: .defaultQuickCombine,
            pinCandidate: .defaultPinCandidate,
            deleteCandidate: .defaultDeleteCandidate
        ) == nil)
    }

    @Test func conflicts_ignoresNilShortcuts() {
        #expect(InputShortcutFormatting.conflicts(
            quickCombine: nil,
            pinCandidate: .defaultPinCandidate,
            deleteCandidate: nil
        ) == nil)
    }

    @Test func storedShortcut_cleared_persistsAsNil() {
        let stored = StoredInputShortcut(value: nil, placeholder: .defaultQuickCombine)
        #expect(stored.value == nil)
        let active = StoredInputShortcut(value: .defaultQuickCombine, placeholder: .defaultQuickCombine)
        #expect(active.value == .defaultQuickCombine)
    }
}
