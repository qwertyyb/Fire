import Testing
@testable import Fire

private struct StubPunctuationTransformer: PunctuationTransformer {
    let results: [String: PunctuationMapping]

    func transform(_ origin: String) -> PunctuationMapping? {
        results[origin]
    }
}

private func makeTempEnState(
    store: MockEngineStore = MockEngineStore(),
    config: MockEngineConfig = MockEngineConfig(),
    results: [String: PunctuationMapping] = [:]
) -> TempEnState {
    TempEnState(
        store: store,
        config: config,
        punctuationHandler: PunctuationHandler(transformer: StubPunctuationTransformer(results: results))
    )
}

struct TempEnStateTests {
    @Test func shouldEnter_whenOriginEmptyAndSemicolon() {
        let context = MockInputContext()
        #expect(TempEnState.shouldEnter(Key.semicolon(), context: context))
    }

    @Test func shouldEnter_rejectsWhenOriginNotEmpty() {
        let context = MockInputContext()
        context.origin = "a"
        #expect(!TempEnState.shouldEnter(Key.semicolon(), context: context))
    }

    @Test func didEnter_setsPlaceholderCandidate() {
        var state = makeTempEnState()
        let mock = MockInputContext()
        var context: any InputContext = mock

        state.didEnter(&context)

        #expect(mock.origin == TempEnState.trigger)
        #expect(mock.candidates.count == 1)
        #expect(mock.candidates.first?.type == .placeholder)
    }

    @Test func handle_appendsCharacters() {
        var state = makeTempEnState()
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        _ = state.handle(Key.a(), context: &context, exitState: {})

        #expect(mock.origin == ";a")
    }

    @Test func handle_escape_clearsAndExits() {
        var state = makeTempEnState()
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        var didExit = false

        _ = state.handle(Key.escape(), context: &context, exitState: { didExit = true })

        #expect(didExit)
        #expect(mock.origin.isEmpty)
    }

    @Test func handle_return_commitsTextAndExits() {
        let store = MockEngineStore()
        var state = makeTempEnState(store: store)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        _ = state.handle(Key.a(), context: &context, exitState: {})
        var didExit = false

        _ = state.handle(Key.returnKey(), context: &context, exitState: { didExit = true })

        #expect(didExit)
        #expect(mock.committed == ["a"])
        #expect(store.recentCommittedTexts == ["a"])
    }

    @Test func handle_doubleTrigger_commit_exitsAndCommits() {
        var state = makeTempEnState(results: [";": .commit("；")])
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        var didExit = false

        _ = state.handle(Key.semicolon(), context: &context, exitState: { didExit = true })

        #expect(didExit)
        #expect(mock.committed == ["；"])
    }

    @Test func handle_doubleTrigger_candidates_entersInnerState() {
        var state = makeTempEnState(results: [";": .candidates([";", "；"])])
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        var didExit = false

        _ = state.handle(Key.semicolon(), context: &context, exitState: { didExit = true })

        #expect(!didExit)
        #expect(mock.origin == ";")
        #expect(mock.candidates.map(\.text) == [";", "；"])
    }

    @Test func handle_doubleTrigger_candidates_selectThenExitsTempEn() {
        var state = makeTempEnState(results: [";": .candidates([";", "；"])])
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        var didExit = false
        let exit = { didExit = true }

        _ = state.handle(Key.semicolon(), context: &context, exitState: exit)
        _ = state.handle(Key.digit(2), context: &context, exitState: exit)

        #expect(didExit)
        #expect(mock.committed == ["；"])
    }
}
