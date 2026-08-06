import Foundation
@testable import Fire

final class MockInputContext: InputContext {
    var origin = ""
    var candidates: [Candidate] = []
    var hasNext = false
    var curPage = 1
    var selectedIndex = 0
    var committed: [String] = []
    var messages: [String] = []
    var textBefore = ""

    func getTextBefore(_ count: Int) -> String { textBefore }
    func commit(_ text: String) { committed.append(text) }
    func commitCandidate(_ candidate: Candidate, confirmed: Bool) { committed.append(candidate.text) }
    func moveCursor(_ offset: Int) {}
    func showMessage(_ message: String) { messages.append(message) }
}
