//
//  Engine.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/4.
//

import Foundation

class Engine {
    static let shared = Engine()
    
    static func isPair(_ text: String) -> Bool {
        return PunctuationHandler.isPair(text)
    }
    
    static let inputModeChanged = Notification.Name("Fire.inputModeChanged")
    
    var store: any EngineStore = DefaultEngineStore.shared
    func createSession(dict: some EngineDictManager, config: some EngineConfig) -> RootState {
        return RootState(
            dict: dict,
            config: config,
            store: store,
            punctuationTransformer: FirePunctuationTransformer()
        )
    }
    var inputMode: InputMode {
        self.store.inputMode
    }
    func toggleInputMode(_ nextInputMode: InputMode? = nil) {
        if nextInputMode != nil, self.store.inputMode == nextInputMode {
            return
        }

        let oldVal = store.inputMode
        if let nextInputMode = nextInputMode, nextInputMode != store.inputMode {
            store.inputMode = nextInputMode
        } else {
            store.inputMode = store.inputMode == .enUS ? .zhhans : .enUS
        }
        NotificationCenter.default.post(name: Self.inputModeChanged, object: nil, userInfo: [
            "oldVal": oldVal,
            "val": store.inputMode,
            "label": store.inputMode == .enUS ? "英" : "中"
        ])
    }
}
