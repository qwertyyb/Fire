//
//  PunctuationCandidateState.swift
//  Fire
//
//  Created by qwertyyb on 2026/8/8.
//

import Carbon

struct PunctuationCandidateState: InputState {
    private let allCandidates: [Candidate]
    private let config: any EngineConfig

    private var totalPage: Int {
        let pageSize = max(config.candidateCount, 1)
        return (allCandidates.count + pageSize - 1) / pageSize
    }

    init(_ candidates: [Candidate], config: any EngineConfig) {
        self.allCandidates = candidates
        self.config = config
    }

    private func pageCandidates(for page: Int) -> [Candidate] {
        let pageSize = max(config.candidateCount, 1)
        let start = (page - 1) * pageSize
        guard start < allCandidates.count else { return [] }
        let end = min(start + pageSize, allCandidates.count)
        return Array(allCandidates[start..<end])
    }

    private mutating func updatePage(_ context: inout any InputContext, page: Int, selectedIndex: Int = 0) {
        context.curPage = page
        context.selectedIndex = selectedIndex
        context.candidates = pageCandidates(for: page)
        context.hasNext = page < totalPage
    }

    private mutating func commitCandidate(_ context: inout any InputContext, _ candidate: Candidate, exitState: () -> Void) {
        context.commit(candidate.text)
        exitState()
    }

    private mutating func commitSelected(_ context: inout any InputContext, exitState: () -> Void) {
        guard context.selectedIndex < context.candidates.count else { return }
        commitCandidate(&context, context.candidates[context.selectedIndex], exitState: exitState)
    }

    mutating func handle(_ event: KeyInput, context: inout any InputContext, exitState: () -> Void) -> Bool? {
        if EngineUtils.isNextPageKey(event, config: config) {
            if context.hasNext {
                updatePage(&context, page: context.curPage + 1)
            }
            return true
        }

        if EngineUtils.isPrevPageKey(event, config: config) {
            if context.curPage > 1 {
                updatePage(&context, page: context.curPage - 1)
            }
            return true
        }

        if EngineUtils.isNextSelectKey(event, config: config) {
            if context.selectedIndex < context.candidates.count - 1 {
                context.selectedIndex += 1
            } else if context.hasNext {
                updatePage(&context, page: context.curPage + 1)
            }
            return true
        }

        if EngineUtils.isPrevSelectKey(event, config: config) {
            if context.selectedIndex > 0 {
                context.selectedIndex -= 1
            } else if context.curPage > 1 {
                updatePage(&context, page: context.curPage - 1)
                context.selectedIndex = context.candidates.count - 1
            }
            return true
        }

        if let char = event.characters, let pos = Int(char), pos > 0 {
            let index = pos - 1
            if index < context.candidates.count {
                commitCandidate(&context, context.candidates[index], exitState: exitState)
            }
            return true
        }

        if let index = EngineUtils.extraCandidateIndex(for: event, config: config),
           index < context.candidates.count {
            commitCandidate(&context, context.candidates[index], exitState: exitState)
            return true
        }

        if event.keyCode == kVK_Space {
            commitSelected(&context, exitState: exitState)
            return true
        }

        if event.keyCode == kVK_Return {
            context.commit(context.origin)
            exitState()
            return true
        }

        if EngineUtils.isEscapeKey(event) {
            exitState()
            return true
        }

        if EngineUtils.isDeleteKey(event) {
            exitState()
            return true
        }

        return true
    }

    mutating func didEnter(_ context: inout any InputContext) {
        updatePage(&context, page: 1)
    }

    mutating func willExit(_ context: inout any InputContext) {
        context.origin = ""
        context.candidates = []
        context.curPage = 1
        context.hasNext = false
        context.selectedIndex = 0
    }
}
