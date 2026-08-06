@testable import Fire

struct MockEngineConfig: EngineConfig {
    var disableEnMode = false
    var toggleInputModeKey: ModifierKey = .shift
    var candidatesDirection: CandidatesDirection = .horizontal
    var enableDotAfterNumber = true
    var enableColonAfterNumber = true
    var wubiFifthCommit = false
    var wubiAutoCommit = false
    var codeMode: CodeMode = .wubi
    var extraCandidateSelectKeys: ExtraCandidateSelectKeys = .disabled
    var disableTempEnMode = false
}
