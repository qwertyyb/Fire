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

        let result = state.handle(Key.a(), context: &context)

        #expect(result.isStay)
        #expect(result.handled)
        #expect(mock.origin == ";a")
    }

    @Test func handle_escape_clearsAndExits() {
        var state = makeTempEnState()
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        let result = state.handle(Key.escape(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(mock.origin.isEmpty)
    }

    @Test func handle_return_commitsTextAndExits() {
        let store = MockEngineStore()
        var state = makeTempEnState(store: store)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        _ = state.handle(Key.a(), context: &context)

        let result = state.handle(Key.returnKey(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(mock.committed == ["a"])
        #expect(store.recentCommittedTexts == ["a"])
    }

    @Test func handle_doubleTrigger_commit_exitsAndCommits() {
        var state = makeTempEnState(results: [";": .commit("；")])
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        let result = state.handle(Key.semicolon(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(mock.committed == ["；"])
    }

    @Test func handle_doubleTrigger_candidates_transitionsToPunctuationCandidateState() {
        var state = makeTempEnState(results: [";": .candidates([";", "；"])])
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        let result = state.handle(Key.semicolon(), context: &context)

        #expect(result.isTransition)
        #expect(result.handled)
        #expect(mock.origin == ";")

        guard case .transition(var newState, _) = result else { return }
        newState.didEnter(&context)
        #expect(mock.candidates.map(\.text) == [";", "；"])
    }
}
