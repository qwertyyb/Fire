//
//  TempEnState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/1.
//  临时英文模式：触发符、状态判断与 placeholder 候选生成。
//

import Foundation
import Carbon

struct TempEnState: InputState {

    static let trigger: String = ";"

    static func shouldEnter(_ event: KeyInput, context: InputContext) -> Bool {
        return context.origin.isEmpty && event.characters == Self.trigger
    }

    var store: any EngineStore
    var config: any EngineConfig
    var punctuationHandler: PunctuationHandler
    var subState: (any InputState)?

    init(
        store: any EngineStore,
        config: any EngineConfig,
        punctuationHandler: PunctuationHandler
    ) {
        self.store = store
        self.config = config
        self.punctuationHandler = punctuationHandler
    }

    mutating func handle(_ event: KeyInput, context: inout any InputContext) -> HandleResult {
        var origin = context.origin
        if event.characters == Self.trigger && origin == Self.trigger {
            return handleDoubleTrigger(&context)
        }
        if event.keyCode == kVK_Return {
            let text = String(origin.dropFirst())
            store.recentCommittedTexts.append(text)
            context.commit(text)
            return .exit(true)
        }
        if EngineUtils.isEscapeKey(event) {
            origin = ""
        } else if EngineUtils.isDeleteKey(event) {
            origin = String(origin.dropLast())
        } else if let char = event.characters {
            origin += char
        }
        context.origin = origin
        if origin.isEmpty {
            return .exit(true)
        }

        updatePlaceholder(&context)
        return .stay(true)
    }

    mutating func didEnter(_ context: inout any InputContext) {
        context.origin = Self.trigger
        updatePlaceholder(&context)
    }

    mutating func willExit(_ context: inout any InputContext) {
        context.origin = ""
        context.curPage = 1
        context.candidates = []
    }

    private mutating func handleDoubleTrigger(_ context: inout any InputContext) -> HandleResult {
        guard let result = punctuationHandler.handle(Self.trigger, config: config) else {
            context.commit(Self.trigger)
            return .exit(true)
        }
        switch result {
        case .commit(let text):
            context.commit(text)
            return .exit(true)
        case .candidates(let list):
            context.origin = Self.trigger
            let candidates = list.map { Candidate(code: "", text: $0, type: .unknown) }
            return .transition(PunctuationCandidateState(candidates, config: config), output: true)
        }
    }

    private func updatePlaceholder(_ context: inout any InputContext) {
        context.candidates = [
            Candidate(
                code: context.origin,
                text: "",
                type: .placeholder,
                label: "临时英文(空格输出半角符号,连敲;键两下输出全角符号)"
            )
        ]
        context.curPage = 1
        context.hasNext = false
    }
}
