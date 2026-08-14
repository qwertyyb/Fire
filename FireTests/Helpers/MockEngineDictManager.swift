@testable import Fire

final class MockEngineDictManager: EngineDictManager {
    var candidatesByOrigin: [String: [Candidate]] = [:]
    var hasNextPages: [String: Bool] = [:]
    var wubiCodes: [String: String] = [:]
    var blockedTexts: Set<String> = []
    var addedUserTexts: [(origin: String, text: String)] = []
    var setFirstCalls: [(origin: String, candidate: Candidate)] = []
    var blockedCandidates: [Candidate] = []

    func query(_ origin: String, page: Int) -> (candidates: [Candidate], hasNext: Bool) {
        (candidatesByOrigin[origin] ?? [], hasNextPages[origin, default: false])
    }

    func queryWubiCode(_ text: String) -> String? {
        wubiCodes[text]
    }

    func setCandidateToFirst(_ origin: String, candidate: Candidate) {
        setFirstCalls.append((origin, candidate))
    }

    func blockCandidate(_ candidate: Candidate) {
        blockedCandidates.append(candidate)
        blockedTexts.insert(candidate.text)
    }

    func isBlocked(_ text: String) -> Bool {
        blockedTexts.contains(text)
    }

    func unblockText(_ text: String) {
        blockedTexts.remove(text)
    }

    func addUserText(origin: String, text: String) {
        addedUserTexts.append((origin, text))
    }
}
