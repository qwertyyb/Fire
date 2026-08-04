//
//  EngineStore.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/3.
//
import Defaults

protocol EngineStore {
    var inputMode: InputMode { get set }
    var recentCommittedTexts: [String] { get set }
}

enum InputMode: String, Defaults.Serializable {
    case zhhans
    case enUS
}

final class DefaultEngineStore: EngineStore {
    static let shared = DefaultEngineStore()
    
    private static let maxRecentCount = 20
    
    var recentCommittedTexts: [String] = [] {
        didSet (val) {
            if recentCommittedTexts.count > Self.maxRecentCount {
                recentCommittedTexts.removeFirst()
            }
        }
    }
    var inputMode: InputMode = .zhhans
}
