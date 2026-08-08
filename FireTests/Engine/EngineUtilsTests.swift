import Carbon
import Testing
@testable import Fire

struct EngineUtilsTests {
    @Test func isDeleteKey_matchesDeleteAndCtrlH() {
        #expect(EngineUtils.isDeleteKey(Key.delete()))
        #expect(EngineUtils.isDeleteKey(Key.keyDown(keyCode: kVK_ANSI_H, modifiers: .control)))
    }

    @Test func isDeleteKey_rejectsOtherKeys() {
        #expect(!EngineUtils.isDeleteKey(Key.a()))
        #expect(!EngineUtils.isDeleteKey(Key.keyDown(keyCode: kVK_ANSI_H)))
    }

    @Test func isEscapeKey_matchesEscapeAndCtrlU() {
        #expect(EngineUtils.isEscapeKey(Key.escape()))
        #expect(EngineUtils.isEscapeKey(Key.keyDown(keyCode: kVK_ANSI_U, modifiers: .control)))
    }

    @Test func isEscapeKey_rejectsOtherKeys() {
        #expect(!EngineUtils.isEscapeKey(Key.a()))
    }

    @Test func extraCandidateIndex_semicolonQuote() {
        var config = MockEngineConfig()
        config.extraCandidateSelectKeys = .semicolonQuote

        #expect(EngineUtils.extraCandidateIndex(for: Key.semicolon(), config: config) == 1)
        #expect(EngineUtils.extraCandidateIndex(for: Key.keyDown(keyCode: kVK_ANSI_Quote, characters: "'"), config: config) == 2)
        #expect(EngineUtils.extraCandidateIndex(for: Key.a(), config: config) == nil)
    }

    @Test func extraCandidateIndex_commaPeriod() {
        var config = MockEngineConfig()
        config.extraCandidateSelectKeys = .commaPeriod

        #expect(EngineUtils.extraCandidateIndex(for: Key.keyDown(keyCode: kVK_ANSI_Comma, characters: ","), config: config) == 1)
        #expect(EngineUtils.extraCandidateIndex(for: Key.period(), config: config) == 2)
    }

    @Test func extraCandidateIndex_disabled_returnsNil() {
        var config = MockEngineConfig()
        config.extraCandidateSelectKeys = .disabled

        #expect(EngineUtils.extraCandidateIndex(for: Key.semicolon(), config: config) == nil)
    }

    @Test func isNextPageKey_matchesEqualAndHorizontalDownArrow() {
        var config = MockEngineConfig()
        config.candidatesDirection = .horizontal

        #expect(EngineUtils.isNextPageKey(Key.equal(), config: config))
        #expect(EngineUtils.isNextPageKey(Key.downArrow(), config: config))
        #expect(!EngineUtils.isNextPageKey(Key.upArrow(), config: config))
    }

    @Test func isPrevPageKey_matchesMinusAndHorizontalUpArrow() {
        var config = MockEngineConfig()
        config.candidatesDirection = .horizontal

        #expect(EngineUtils.isPrevPageKey(Key.minus(), config: config))
        #expect(EngineUtils.isPrevPageKey(Key.upArrow(), config: config))
        #expect(!EngineUtils.isPrevPageKey(Key.downArrow(), config: config))
    }
}
