import Carbon
import Testing
@testable import Fire

struct PunctuationCandidateStateTests {
    private func makeCandidates(_ texts: [String]) -> [Candidate] {
        texts.map { Candidate(code: $0, text: $0, type: .unknown) }
    }

    private func makeState(
        texts: [String],
        config: MockEngineConfig = MockEngineConfig()
    ) -> (state: PunctuationCandidateState, config: MockEngineConfig) {
        (PunctuationCandidateState(makeCandidates(texts), config: config), config)
    }

    @Test func didEnter_showsFirstPage() {
        var config = MockEngineConfig()
        config.candidateCount = 2
        var (state, _) = makeState(texts: ["[", "【", "「", "『"], config: config)
        let mock = MockInputContext()
        mock.origin = "["
        var context: any InputContext = mock

        state.didEnter(&context)

        #expect(mock.candidates.map(\.text) == ["[", "【"])
        #expect(mock.curPage == 1)
        #expect(mock.selectedIndex == 0)
        #expect(mock.hasNext)
    }

    @Test func didEnter_singlePage_hasNoNext() {
        var (state, _) = makeState(texts: ["[", "【"])
        let mock = MockInputContext()
        var context: any InputContext = mock

        state.didEnter(&context)

        #expect(mock.candidates.map(\.text) == ["[", "【"])
        #expect(!mock.hasNext)
    }

    @Test func handle_digitSelect_commitsAndExits() {
        var (state, _) = makeState(texts: ["[", "【", "「"])
        let mock = MockInputContext()
        mock.origin = "["
        var context: any InputContext = mock
        state.didEnter(&context)

        let result = state.handle(Key.digit(2), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(mock.committed == ["【"])
    }

    @Test func handle_space_commitsSelected() {
        var (state, _) = makeState(texts: ["[", "【", "「"])
        let mock = MockInputContext()
        mock.origin = "["
        var context: any InputContext = mock
        state.didEnter(&context)
        mock.selectedIndex = 1

        let result = state.handle(Key.space(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(mock.committed == ["【"])
    }

    @Test func handle_return_commitsOriginAndExits() {
        var (state, _) = makeState(texts: ["[", "【"])
        let mock = MockInputContext()
        mock.origin = "["
        var context: any InputContext = mock
        state.didEnter(&context)

        let result = state.handle(Key.returnKey(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(mock.committed == ["["])
    }

    @Test func handle_escape_exitsWithoutCommit() {
        var (state, _) = makeState(texts: ["[", "【"])
        let mock = MockInputContext()
        mock.origin = "["
        var context: any InputContext = mock
        state.didEnter(&context)

        let result = state.handle(Key.escape(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(mock.committed.isEmpty)
    }

    @Test func handle_delete_exitsWithoutCommit() {
        var (state, _) = makeState(texts: ["[", "【"])
        let mock = MockInputContext()
        mock.origin = "["
        var context: any InputContext = mock
        state.didEnter(&context)

        let result = state.handle(Key.delete(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(mock.committed.isEmpty)
    }

    @Test func handle_nextPage_showsSecondPage() {
        var config = MockEngineConfig()
        config.candidateCount = 2
        var (state, _) = makeState(texts: ["[", "【", "「", "『"], config: config)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        let result = state.handle(Key.downArrow(), context: &context)

        #expect(result.isStay)
        #expect(result.handled)
        #expect(mock.curPage == 2)
        #expect(mock.candidates.map(\.text) == ["「", "『"])
        #expect(!mock.hasNext)
        #expect(mock.selectedIndex == 0)
    }

    @Test func handle_prevPage_goesBackToFirstPage() {
        var config = MockEngineConfig()
        config.candidateCount = 2
        var (state, _) = makeState(texts: ["[", "【", "「", "『"], config: config)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        _ = state.handle(Key.downArrow(), context: &context)

        let result = state.handle(Key.upArrow(), context: &context)

        #expect(result.isStay)
        #expect(result.handled)
        #expect(mock.curPage == 1)
        #expect(mock.candidates.map(\.text) == ["[", "【"])
        #expect(mock.hasNext)
    }

    @Test func handle_extraCandidateKey_commitsSecondCandidate() {
        var config = MockEngineConfig()
        config.extraCandidateSelectKeys = .semicolonQuote
        var (state, _) = makeState(texts: ["[", "【", "「"], config: config)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        let result = state.handle(Key.semicolon(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(mock.committed == ["【"])
    }

    @Test func willExit_clearsContext() {
        var (state, _) = makeState(texts: ["[", "【"])
        let mock = MockInputContext()
        mock.origin = "["
        mock.curPage = 2
        mock.hasNext = true
        mock.selectedIndex = 1
        var context: any InputContext = mock
        state.didEnter(&context)

        state.willExit(&context)

        #expect(mock.origin.isEmpty)
        #expect(mock.candidates.isEmpty)
        #expect(mock.curPage == 1)
        #expect(!mock.hasNext)
        #expect(mock.selectedIndex == 0)
    }
}
