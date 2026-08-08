@testable import Fire

final class MockEngineStore: EngineStore {
    var inputMode: InputMode = .zhhans
    var recentCommittedTexts: [String] = []
}
