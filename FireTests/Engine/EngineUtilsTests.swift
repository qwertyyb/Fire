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
}
