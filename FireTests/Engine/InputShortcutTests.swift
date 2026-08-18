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
        let shortcut = FireEngineConfig.defaultQuickCombine
        #expect(shortcut.matches(Key.ctrlEqual()))
    }

    @Test func pinCandidateDefault_matchesControlOptionDigit() {
        let shortcut = FireEngineConfig.defaultPinCandidate
        #expect(shortcut.matches(Key.ctrlOptionDigit(2)))
        #expect(!shortcut.matches(Key.ctrlShiftDigit(2)))
    }

    @Test func deleteCandidateDefault_matchesControlShiftDigit() {
        let shortcut = FireEngineConfig.defaultDeleteCandidate
        #expect(shortcut.matches(Key.ctrlShiftDigit(2)))
        #expect(!shortcut.matches(Key.ctrlOptionDigit(2)))
    }

    @Test func displayLabel_quickCombine() {
        let shortcut = FireEngineConfig.defaultQuickCombine
        #expect(shortcut.displayLabel == "control+=")
    }

    @Test func displayLabel_digitShortcut() {
        let shortcut = FireEngineConfig.defaultPinCandidate
        #expect(shortcut.displayLabel == "control+option+数字")
    }

    @Test func conflicts_detectsSameDigitModifiers() {
        let pin = DigitInputShortcut(modifiers: [.control, .shift])
        let delete = DigitInputShortcut(modifiers: [.control, .shift])
        let conflict = InputShortcutFormatting.conflicts(
            quickCombine: FireEngineConfig.defaultQuickCombine,
            pinCandidate: pin,
            deleteCandidate: delete
        )
        #expect(conflict != nil)
    }

    @Test func conflicts_allowsDistinctDefaults() {
        #expect(InputShortcutFormatting.conflicts(
            quickCombine: FireEngineConfig.defaultQuickCombine,
            pinCandidate: FireEngineConfig.defaultPinCandidate,
            deleteCandidate: FireEngineConfig.defaultDeleteCandidate
        ) == nil)
    }

    @Test func conflicts_ignoresNilShortcuts() {
        #expect(InputShortcutFormatting.conflicts(
            quickCombine: nil,
            pinCandidate: FireEngineConfig.defaultPinCandidate,
            deleteCandidate: nil
        ) == nil)
    }

    @Test func storedShortcut_cleared_persistsAsNil() {
        let stored = StoredInputShortcut(value: nil, placeholder: FireEngineConfig.defaultQuickCombine)
        #expect(stored.value == nil)
        let active = StoredInputShortcut(value: FireEngineConfig.defaultQuickCombine, placeholder: FireEngineConfig.defaultQuickCombine)
        #expect(active.value == FireEngineConfig.defaultQuickCombine)
    }
}
