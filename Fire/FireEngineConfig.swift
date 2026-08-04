//
//  FireEngineConfig.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/4.
//
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
    
    static let shared = FireEngineConfig()
}
