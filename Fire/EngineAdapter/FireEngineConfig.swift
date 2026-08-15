//
//  FireEngineConfig.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/4.
//
import AppKit
import Carbon
import Defaults

struct FireEngineConfig: EngineConfig {
    var disableEnMode: Bool {
        Defaults[.disableEnMode]
    }
    
    var toggleInputModeKey: ModifierKey {
        Defaults[.toggleInputModeKey]
    }
    
    var candidatesDirection: CandidatesDirection {
        Defaults[.candidatesDirection]
    }

    var candidateCount: Int {
        Defaults[.candidateCount]
    }
    
    var enableDotAfterNumber: Bool {
        Defaults[.enableDotAfterNumber]
    }
    
    var enableColonAfterNumber: Bool {
        Defaults[.enableColonAfterNumber]
    }
    
    var wubiFifthCommit: Bool {
        Defaults[.wubiFifthCommit]
    }
    
    var wubiAutoCommit: Bool {
        Defaults[.wubiAutoCommit]
    }
    
    var codeMode: CodeMode {
        Defaults[.codeMode]
    }
    
    var extraCandidateSelectKeys: ExtraCandidateSelectKeys {
        Defaults[.extraCandidateSelectKeys]
    }
    
    var disableTempEnMode: Bool {
        Defaults[.disableTempEnMode]
    }

    var quickCombineShortcut: InputShortcut? {
        Defaults[.quickCombineShortcut].value
    }

    var pinCandidateShortcut: DigitInputShortcut? {
        Defaults[.pinCandidateShortcut].value
    }

    var deleteCandidateShortcut: DigitInputShortcut? {
        Defaults[.deleteCandidateShortcut].value
    }

    var enablePunctuationAutoPair: Bool {
        Defaults[.enablePunctuationAutoPair]
    }
    
    static let shared = FireEngineConfig()
}

extension FireEngineConfig {
    static let defaultQuickCombine = InputShortcut(
        keyCode: UInt16(kVK_ANSI_Equal),
        modifiers: .control
    )
    static let defaultPinCandidate = DigitInputShortcut(modifiers: [.control, .option])
    static let defaultDeleteCandidate = DigitInputShortcut(modifiers: [.control, .shift])
}
