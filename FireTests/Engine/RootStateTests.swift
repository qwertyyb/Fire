import AppKit
import Carbon
import Testing
@testable import Fire

struct RootStateTests {
    @Test func charKey_appendsOriginAndFetchesCandidates() {
        let (root, _, dict, _) = TestFixtures.makeRootState()
        dict.candidatesByOrigin["a"] = [TestFixtures.candidate("啊", code: "a")]
        let mock = MockInputContext()
        var context: any InputContext = mock

        let handled = root.handle(Key.a(), context: &context, exitState: {})

        #expect(handled == true)
        #expect(mock.origin == "a")
        #expect(mock.candidates.first?.text == "啊")
    }

    @Test func deleteKey_shortensOrigin() {
        let (root, _, _, _) = TestFixtures.makeRootState()
        let mock = MockInputContext()
        mock.origin = "ab"
        var context: any InputContext = mock

        let handled = root.handle(Key.delete(), context: &context, exitState: {})

        #expect(handled == true)
        #expect(mock.origin == "a")
        #expect(mock.curPage == 1)
    }

    @Test func deleteKey_onEmptyOrigin_returnsFalse() {
        let (root, _, _, _) = TestFixtures.makeRootState()
        let mock = MockInputContext()
        var context: any InputContext = mock

        let handled = root.handle(Key.delete(), context: &context, exitState: {})

        #expect(handled == false)
    }

    @Test func escKey_clearsOrigin() {
        let (root, _, _, _) = TestFixtures.makeRootState()
        let mock = MockInputContext()
        mock.origin = "abc"
        var context: any InputContext = mock

        let handled = root.handle(Key.escape(), context: &context, exitState: {})

        #expect(handled == true)
        #expect(mock.origin.isEmpty)
    }

    @Test func enterKey_commitsOrigin() {
        let (root, _, _, _) = TestFixtures.makeRootState()
        let mock = MockInputContext()
        mock.origin = "abc"
        var context: any InputContext = mock

        let handled = root.handle(Key.returnKey(), context: &context, exitState: {})

        #expect(handled == true)
        #expect(mock.committed == ["abc"])
        #expect(mock.origin.isEmpty)
    }

    @Test func spaceKey_commitsSelectedCandidate() {
        let (root, store, _, _) = TestFixtures.makeRootState()
        let mock = MockInputContext()
        mock.origin = "a"
        mock.candidates = [TestFixtures.candidate("啊", code: "a")]
        mock.selectedIndex = 0
        var context: any InputContext = mock

        let handled = root.handle(Key.space(), context: &context, exitState: {})

        #expect(handled == true)
        #expect(mock.committed == ["啊"])
        #expect(store.recentCommittedTexts == ["啊"])
        #expect(mock.origin.isEmpty)
    }

    @Test func numberKey_selectsCandidateByIndex() {
        let (root, _, _, _) = TestFixtures.makeRootState()
        let mock = MockInputContext()
        mock.origin = "a"
        mock.candidates = [
            TestFixtures.candidate("啊", code: "a"),
            TestFixtures.candidate("阿", code: "a"),
        ]
        var context: any InputContext = mock

        let handled = root.handle(Key.digit(2), context: &context, exitState: {})

        #expect(handled == true)
        #expect(mock.committed == ["阿"])
        #expect(mock.origin.isEmpty)
    }

    @Test func predictor_convertsPeriodAfterNumber() {
        let (root, _, _, _) = TestFixtures.makeRootState()
        let mock = MockInputContext()
        mock.textBefore = "3"
        var context: any InputContext = mock

        let handled = root.handle(Key.period(), context: &context, exitState: {})

        #expect(handled == true)
        #expect(mock.committed == ["."])
    }

    @Test func nextPage_and_prevPage() {
        let (root, _, dict, _) = TestFixtures.makeRootState()
        dict.candidatesByOrigin["a"] = [TestFixtures.candidate("啊", code: "a")]
        dict.hasNextPages["a"] = true
        let mock = MockInputContext()
        mock.origin = "a"
        mock.hasNext = true
        var context: any InputContext = mock

        #expect(root.nextPage(&context) == true)
        #expect(mock.curPage == 2)

        #expect(root.prevPage(&context) == true)
        #expect(mock.curPage == 1)
    }

    @Test func hotkey_pinsCandidateToFirst() {
        let (root, _, dict, _) = TestFixtures.makeRootState()
        let first = TestFixtures.candidate("啊", code: "a")
        let second = TestFixtures.candidate("阿", code: "a")
        dict.candidatesByOrigin["a"] = [first, second]
        let mock = MockInputContext()
        mock.origin = "a"
        mock.candidates = [first, second]
        var context: any InputContext = mock

        let handled = root.handle(Key.ctrlOptionDigit(2), context: &context, exitState: {})

        #expect(handled == true)
        #expect(dict.setFirstCalls.count == 1)
        #expect(dict.setFirstCalls.first?.candidate.text == "阿")
    }

    @Test func flagsChangeHandler_shiftToggle_commitsOriginAndSwitchesMode() {
        var config = MockEngineConfig()
        config.toggleInputModeKey = .shift
        let store = MockEngineStore()
        let engine = Engine()
        engine.store = store
        let root = RootState(dict: MockEngineDictManager(), config: config, store: store, engine: engine)
        let mock = MockInputContext()
        mock.origin = "abc"
        var context: any InputContext = mock

        let handled = root.handle(Key.shiftModifierPress(), context: &context, exitState: {})

        #expect(handled == true)
        #expect(mock.committed == ["abc"])
        #expect(mock.origin.isEmpty)
        #expect(store.inputMode == .enUS)
    }

    @Test func flagsChangeHandler_commandModifier_returnsFalse() {
        let (root, _, _, _) = TestFixtures.makeRootState()
        let mock = MockInputContext()
        var context: any InputContext = mock
        let event = Key.flagsChanged(keyCode: kVK_Command, modifiers: .command)

        let handled = root.flagsChangeHandler(event, context: &context)

        #expect(handled == false)
    }

    @Test func enModeHandler_returnsFalseInEnglishMode() {
        let (root, store, _, _) = TestFixtures.makeRootState()
        store.inputMode = .enUS
        let mock = MockInputContext()
        var context: any InputContext = mock

        let handled = root.handle(Key.a(), context: &context, exitState: {})

        #expect(handled == false)
    }
}
