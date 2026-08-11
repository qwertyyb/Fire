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

        let result = state.handle(Key.leftArrow(), context: &context)

        #expect(result.isStay)
        #expect(result.handled)
        #expect(mock.origin == "abcd")
    }

    @Test func handle_leftArrow_twice_increasesCountToFour() {
        let store = MockEngineStore()
        store.recentCommittedTexts = ["A", "你", "好", "世"]
        let dict = MockEngineDictManager()
        dict.wubiCodes["好世"] = "abc"
        dict.wubiCodes["你好世"] = "abcd"
        dict.wubiCodes["A你好世"] = "abcde"
        var state = QuickCombineState(count: 2, dict: dict, store: store)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        _ = state.handle(Key.leftArrow(), context: &context)
        let result = state.handle(Key.leftArrow(), context: &context)

        #expect(result.isStay)
        #expect(result.handled)
        #expect(mock.origin == "abcde")
    }

    @Test func handle_rightArrow_decreasesCount() {
        let store = MockEngineStore()
        store.recentCommittedTexts = ["A", "你", "好", "世"]
        let dict = MockEngineDictManager()
        dict.wubiCodes["好世"] = "abc"
        dict.wubiCodes["你好世"] = "abcd"
        var state = QuickCombineState(count: 2, dict: dict, store: store)
        let mock = MockInputContext()
        var context: any InputContext = mock
        state.didEnter(&context)

        _ = state.handle(Key.leftArrow(), context: &context)
        let result = state.handle(Key.rightArrow(), context: &context)

        #expect(result.isStay)
        #expect(result.handled)
        #expect(mock.origin == "abc")
    }

    @Test func viaRootState_leftArrowTwice_persistsCount() {
        let store = MockEngineStore()
        store.inputMode = .zhhans
        store.recentCommittedTexts = ["A", "你", "好", "世"]
        let dict = MockEngineDictManager()
        dict.wubiCodes["好世"] = "abc"
        dict.wubiCodes["你好世"] = "abcd"
        dict.wubiCodes["A你好世"] = "abcde"
        let (root, _, _, _) = TestFixtures.makeRootState(store: store, dict: dict)
        let mock = MockInputContext()
        var context: any InputContext = mock

        _ = root.handle(Key.ctrlEqual(), context: &context)
        #expect(root.subState is QuickCombineState)
        #expect(mock.origin == "abc")

        _ = root.handle(Key.leftArrow(), context: &context)
        #expect(mock.origin == "abcd")

        let result = root.handle(Key.leftArrow(), context: &context)

        #expect(result.isStay)
        #expect(result.handled)
        #expect(mock.origin == "abcde")
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

        let result = state.handle(Key.returnKey(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
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

        let result = state.handle(Key.escape(), context: &context)

        #expect(result.isExit)
        #expect(result.handled)
        #expect(dict.addedUserTexts.isEmpty)
    }
}
