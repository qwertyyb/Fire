import Foundation
import Testing
@testable import Fire

struct EngineTests {
    @Test func toggleInputMode_switchesBetweenZhAndEn() {
        let store = MockEngineStore()
        store.inputMode = .zhhans
        let engine = Engine()
        engine.store = store

        engine.toggleInputMode()
        #expect(store.inputMode == .enUS)

        engine.toggleInputMode()
        #expect(store.inputMode == .zhhans)
    }

    @Test func toggleInputMode_withSameMode_isNoOp() {
        let store = MockEngineStore()
        store.inputMode = .zhhans
        let engine = Engine()
        engine.store = store

        engine.toggleInputMode(.zhhans)
        #expect(store.inputMode == .zhhans)
    }

    @Test func toggleInputMode_setsExplicitMode() {
        let store = MockEngineStore()
        store.inputMode = .zhhans
        let engine = Engine()
        engine.store = store

        engine.toggleInputMode(.enUS)
        #expect(store.inputMode == .enUS)
    }

    @Test func toggleInputMode_postsNotification() {
        let store = MockEngineStore()
        store.inputMode = .zhhans
        let engine = Engine()
        engine.store = store

        var receivedUserInfo: [AnyHashable: Any]?
        let observer = NotificationCenter.default.addObserver(
            forName: Engine.inputModeChanged,
            object: nil,
            queue: nil
        ) { notification in
            receivedUserInfo = notification.userInfo
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        engine.toggleInputMode()

        #expect(receivedUserInfo?["oldVal"] as? InputMode == .zhhans)
        #expect(receivedUserInfo?["val"] as? InputMode == .enUS)
        #expect(receivedUserInfo?["label"] as? String == "英")
    }
}
