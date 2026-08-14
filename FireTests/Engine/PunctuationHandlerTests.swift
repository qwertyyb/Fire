import Testing
@testable import Fire

private struct StubPunctuationTransformer: PunctuationTransformer {
    let results: [String: PunctuationMapping]

    func transform(_ origin: String) -> PunctuationMapping? {
        results[origin]
    }
}

struct PunctuationHandlerTests {
    private func makeHandler(_ results: [String: PunctuationMapping]) -> PunctuationHandler {
        PunctuationHandler(transformer: StubPunctuationTransformer(results: results))
    }

    @Test func handle_unknownKey_returnsNil() {
        let handler = makeHandler([:])
        let config = MockEngineConfig()

        #expect(handler.handle("?", config: config) == nil)
    }

    @Test func handle_commitWithAutoPair_appendsClosingSymbol() {
        let handler = makeHandler(["(": .commit("（")])
        var config = MockEngineConfig()
        config.enablePunctuationAutoPair = true

        guard case .commit(let text)? = handler.handle("(", config: config) else {
            Issue.record("expected commit result")
            return
        }
        #expect(text == "（）")
    }

    @Test func handle_pairWithoutAutoPair_alternatesLeftAndRight() {
        let handler = makeHandler(["\"": .pair(left: "“", right: "”")])
        var config = MockEngineConfig()
        config.enablePunctuationAutoPair = false

        guard case .commit(let first)? = handler.handle("\"", config: config) else {
            Issue.record("expected first commit")
            return
        }
        guard case .commit(let second)? = handler.handle("\"", config: config) else {
            Issue.record("expected second commit")
            return
        }
        guard case .commit(let third)? = handler.handle("\"", config: config) else {
            Issue.record("expected third commit")
            return
        }

        #expect(first == "“")
        #expect(second == "”")
        #expect(third == "“")
    }

    @Test func handle_candidatesWithAutoPair_appendsPairs() {
        let handler = makeHandler(["[": .candidates(["[", "【"])])
        var config = MockEngineConfig()
        config.enablePunctuationAutoPair = true

        guard case .candidates(let list)? = handler.handle("[", config: config) else {
            Issue.record("expected candidates result")
            return
        }
        #expect(list == ["[]", "【】"])
    }

    @Test func handle_candidatesWithoutAutoPair_returnsRawList() {
        let handler = makeHandler(["[": .candidates(["[", "【", "「"])])
        var config = MockEngineConfig()
        config.enablePunctuationAutoPair = false

        guard case .candidates(let list)? = handler.handle("[", config: config) else {
            Issue.record("expected candidates result")
            return
        }
        #expect(list == ["[", "【", "「"])
    }
}
