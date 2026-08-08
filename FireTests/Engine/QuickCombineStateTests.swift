import Testing
@testable import Fire

struct QuickCombineStateTests {
    @Test func combineText_joinsRecentCommits() {
        let store = MockEngineStore()
        store.recentCommittedTexts = ["你", "好", "世"]
        let state = QuickCombineState(count: 2, dict: MockEngineDictManager(), store: store)

        #expect(state.combineText(2) == "好世")
        #expect(state.combineText(3) == "你好世")
    }

    @Test func handle_leftArrow_increasesCount() {
        let store = MockEngineStore()
        store.recentCommittedTexts = ["A", "你", "好", "世"]
        let dict = MockEngineDictManager()
        dict.wubiCodes["好世"] = "abc"
        dict.wubiCodes["你好世"] = "abcd"
        var state = QuickCombineState(count: 2, dict: dict, store: store)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        _ = state.handle(Key.leftArrow(), context: &context, exitState: {})

        #expect(mock.origin == "abcd")
    }

    @Test func handle_return_addsUserTextAndExits() {
        let store = MockEngineStore()
        store.recentCommittedTexts = ["你", "好"]
        let dict = MockEngineDictManager()
        dict.wubiCodes["你好"] = "wq"
        var state = QuickCombineState(count: 2, dict: dict, store: store)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        var didExit = false

        _ = state.handle(Key.returnKey(), context: &context, exitState: { didExit = true })

        #expect(didExit)
        #expect(dict.addedUserTexts.count == 1)
        #expect(dict.addedUserTexts[0].origin == "wq")
        #expect(dict.addedUserTexts[0].text == "你好")
        #expect(mock.messages.first?.contains("你好") == true)
    }

    @Test func handle_escape_exitsWithoutAddingUserText() {
        let store = MockEngineStore()
        store.recentCommittedTexts = ["你", "好"]
        let dict = MockEngineDictManager()
        dict.wubiCodes["你好"] = "wq"
        var state = QuickCombineState(count: 2, dict: dict, store: store)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)
        var didExit = false

        _ = state.handle(Key.escape(), context: &context, exitState: { didExit = true })

        #expect(didExit)
        #expect(dict.addedUserTexts.isEmpty)
    }
}
