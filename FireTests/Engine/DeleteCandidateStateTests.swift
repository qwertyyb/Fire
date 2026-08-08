import Testing
@testable import Fire

struct DeleteCandidateStateTests {
    @Test func shouldEnter_withCtrlShiftDigit() {
        let context = MockInputContext()
        context.candidates = [
            TestFixtures.candidate("啊"),
            TestFixtures.candidate("阿"),
        ]

        #expect(DeleteCandidateState.shouldEnter(Key.ctrlShiftDigit(2), context: context))
    }

    @Test func shouldEnter_rejectsPlaceholderCandidate() {
        let context = MockInputContext()
        context.candidates = [
            Candidate(code: "x", text: "", type: .placeholder, label: "提示"),
        ]

        #expect(!DeleteCandidateState.shouldEnter(Key.ctrlShiftDigit(1), context: context))
    }

    @Test func handle_return_blocksCandidateAndExits() {
        let dict = MockEngineDictManager()
        let candidate = TestFixtures.candidate("啊")
        var state = DeleteCandidateState(candidate: candidate, dict: dict)
        let mock = MockInputContext()
        mock.origin = "a"
        var context: any InputContext = mock
        state.didEnter(&context)
        var didExit = false

        _ = state.handle(Key.returnKey(), context: &context, exitState: { didExit = true })

        #expect(didExit)
        #expect(dict.blockedCandidates.map(\.text) == ["啊"])
        #expect(mock.messages.first?.contains("啊") == true)
    }

    @Test func handle_escape_exitsWithoutBlocking() {
        let dict = MockEngineDictManager()
        let candidate = TestFixtures.candidate("啊")
        var state = DeleteCandidateState(candidate: candidate, dict: dict)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        var didExit = false

        _ = state.handle(Key.escape(), context: &context, exitState: { didExit = true })

        #expect(didExit)
        #expect(dict.blockedCandidates.isEmpty)
    }

    @Test func willExit_restoresPageAndSelection() {
        let dict = MockEngineDictManager()
        let candidate = TestFixtures.candidate("啊")
        var state = DeleteCandidateState(candidate: candidate, dict: dict)
        let mock = MockInputContext()
        mock.curPage = 2
        mock.selectedIndex = 1
        var context: any InputContext = mock
        state.didEnter(&context)

        state.willExit(&context)

        #expect(mock.curPage == 2)
        #expect(mock.selectedIndex == 1)
    }
}
