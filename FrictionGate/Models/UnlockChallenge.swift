import Foundation

/// The challenge the user must complete in order to unlock a blocked app.
///
/// Challenges can be multiplied during escalation (see `UnlockAttempt.currentMultiplier`).
/// For example, a `steps(required: 500)` challenge at 2× escalation becomes 1 000 steps.
enum UnlockChallenge: Codable, Hashable {

    /// Walk `required` steps (cumulative since the block was applied).
    case steps(required: Int)

    /// Solve `count` mental arithmetic problems (3, 5, or 10).
    case maths(count: Int)

    /// Type an exact sentence character-by-character (paste disabled).
    case typeSentence(sentence: String)

    /// Wait `minutes` minutes before the unlock button becomes active.
    case wait(minutes: Int)

    /// Write a free-text reason for unlocking the app (encourages mindfulness).
    case writeReason

    // MARK: - Defaults

    static let defaultSteps: UnlockChallenge = .steps(required: 1_000)
    static let defaultMaths: UnlockChallenge = .maths(count: 5)
    static let defaultWait:  UnlockChallenge = .wait(minutes: 5)

    // MARK: - Display helpers

    var displayName: String {
        switch self {
        case .steps:        return "Walk steps"
        case .maths:        return "Solve maths"
        case .typeSentence: return "Type a sentence"
        case .wait:         return "Wait it out"
        case .writeReason:  return "Write your reason"
        }
    }

    var shortDescription: String {
        switch self {
        case .steps(let n):          return "Walk \(n) steps"
        case .maths(let c):          return "Solve \(c) maths problems"
        case .typeSentence:          return "Type a sentence"
        case .wait(let m):           return "Wait \(m) min"
        case .writeReason:           return "Write a reason"
        }
    }

    // MARK: - Escalation

    /// Returns a new challenge scaled by `multiplier`, preserving the challenge type.
    /// `typeSentence` and `writeReason` are unaffected by the multiplier.
    func scaled(by multiplier: Int) -> UnlockChallenge {
        guard multiplier > 1 else { return self }
        switch self {
        case .steps(let n):          return .steps(required: n * multiplier)
        case .maths(let c):          return .maths(count: min(c * multiplier, 20))
        case .wait(let m):           return .wait(minutes: m * multiplier)
        case .typeSentence, .writeReason: return self
        }
    }
}
