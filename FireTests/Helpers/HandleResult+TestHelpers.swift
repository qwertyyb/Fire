@testable import Fire

extension HandleResult {
    var handled: Bool {
        switch self {
        case .stay(let output), .exit(let output), .transition(_, let output):
            return output
        }
    }

    var isExit: Bool {
        if case .exit = self { return true }
        return false
    }

    var isStay: Bool {
        if case .stay = self { return true }
        return false
    }

    var isTransition: Bool {
        if case .transition = self { return true }
        return false
    }
}
