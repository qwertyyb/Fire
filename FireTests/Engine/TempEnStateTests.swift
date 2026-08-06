import Testing
@testable import Fire

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
        var state = TempEnState(store: MockEngineStore())
        let mock = MockInputContext()
        var context: any InputContext = mock

        state.didEnter(&context)

        #expect(mock.origin == TempEnState.trigger)
        #expect(mock.candidates.count == 1)
        #expect(mock.candidates.first?.type == .placeholder)
    }

    @Test func handle_appendsCharacters() {
        var state = TempEnState(store: MockEngineStore())
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        _ = state.handle(Key.a(), context: &context, exitState: {})

        #expect(mock.origin == ";a")
    }

    @Test func handle_escape_clearsAndExits() {
        var state = TempEnState(store: MockEngineStore())
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
        var state = TempEnState(store: store)
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
}
