import Foundation
import Combine

// MARK: - MathsProblem

/// A single arithmetic problem for the maths unlock challenge.
struct MathsProblem: Equatable {
    let question: String
    let correctAnswer: Int

    // MARK: - Generator

    /// Generates a random arithmetic problem scaled to `difficulty` (1–5).
    ///
    /// | Level | What you get                                              |
    /// |-------|-----------------------------------------------------------|
    /// | 1     | 2-digit +/−, times-table ×                               |
    /// | 2     | 3-digit +/−, 2-digit × 1-digit, clean division           |
    /// | 3     | 3-digit +/−, 2-digit × 2-digit, two-step expression      |
    /// | 4     | Large two-step (a×b + c, a×b − c×d), squares             |
    /// | 5     | Three-step expressions, squares, 15%/25% percentages     |
    static func generate(difficulty: Int = 1) -> MathsProblem {
        let d = max(1, min(difficulty, 5))
        switch d {
        case 1:  return level1()
        case 2:  return level2()
        case 3:  return level3()
        case 4:  return level4()
        default: return level5()
        }
    }

    // MARK: - Difficulty levels

    /// Level 1 — two-digit +/−, full times table (up to 12×12)
    private static func level1() -> MathsProblem {
        switch Int.random(in: 0...2) {
        case 1:
            let a = Int.random(in: 15...99), b = Int.random(in: 10...a)
            return .init(question: "\(a) − \(b)", correctAnswer: a - b)
        case 2:
            let x = Int.random(in: 2...12), y = Int.random(in: 2...12)
            return .init(question: "\(x) × \(y)", correctAnswer: x * y)
        default:
            let a = Int.random(in: 15...79), b = Int.random(in: 15...79)
            return .init(question: "\(a) + \(b)", correctAnswer: a + b)
        }
    }

    /// Level 2 — 3-digit +/−, 2-digit × 1-digit, clean integer division
    private static func level2() -> MathsProblem {
        switch Int.random(in: 0...2) {
        case 1:
            let a = Int.random(in: 100...499), b = Int.random(in: 50...a)
            return .init(question: "\(a) − \(b)", correctAnswer: a - b)
        case 2:
            // Generate guaranteed clean division: pick divisor and quotient first.
            let divisor  = Int.random(in: 3...12)
            let quotient = Int.random(in: 8...25)
            let dividend = divisor * quotient
            return .init(question: "\(dividend) ÷ \(divisor)", correctAnswer: quotient)
        default:
            let a = Int.random(in: 100...499), b = Int.random(in: 100...499)
            return .init(question: "\(a) + \(b)", correctAnswer: a + b)
        }
    }

    /// Level 3 — 2-digit × 2-digit, two-step  (a + b × c,  a × b − c)
    private static func level3() -> MathsProblem {
        switch Int.random(in: 0...2) {
        case 1:
            // 2-digit × 2-digit
            let x = Int.random(in: 11...35), y = Int.random(in: 11...25)
            return .init(question: "\(x) × \(y)", correctAnswer: x * y)
        case 2:
            // a × b + c  (BODMAS — multiply first)
            let x = Int.random(in: 6...15), y = Int.random(in: 6...15)
            let c = Int.random(in: 10...99)
            return .init(question: "\(x) × \(y) + \(c)", correctAnswer: x * y + c)
        default:
            // a × b − c
            let x = Int.random(in: 8...20), y = Int.random(in: 8...15)
            let product = x * y
            let c = Int.random(in: 10...min(99, product - 1))
            return .init(question: "\(x) × \(y) − \(c)", correctAnswer: product - c)
        }
    }

    /// Level 4 — large two-step, squares of 11–25, a×b + c×d
    private static func level4() -> MathsProblem {
        switch Int.random(in: 0...2) {
        case 1:
            // Square of a 2-digit number
            let n = Int.random(in: 11...25)
            return .init(question: "\(n)²", correctAnswer: n * n)
        case 2:
            // a × b + c × d
            let a = Int.random(in: 6...15), b = Int.random(in: 6...12)
            let c = Int.random(in: 4...10), d = Int.random(in: 4...10)
            return .init(question: "(\(a) × \(b)) + (\(c) × \(d))",
                         correctAnswer: a * b + c * d)
        default:
            // Large three-digit + / − with a ×
            let x = Int.random(in: 12...30), y = Int.random(in: 12...20)
            let c = Int.random(in: 50...200)
            let sign = Bool.random()
            if sign {
                return .init(question: "\(x) × \(y) + \(c)", correctAnswer: x * y + c)
            } else {
                let product = x * y
                let sub = Int.random(in: 10...min(c, product - 1))
                return .init(question: "\(x) × \(y) − \(sub)", correctAnswer: product - sub)
            }
        }
    }

    /// Level 5 — three-step expressions, squares, percentages
    private static func level5() -> MathsProblem {
        switch Int.random(in: 0...2) {
        case 1:
            // (a × b) − (c × d) + e   three operations
            let a = Int.random(in: 8...20),  b = Int.random(in: 8...15)
            let c = Int.random(in: 4...10),  d = Int.random(in: 4...10)
            let e = Int.random(in: 10...50)
            let ans = a * b - c * d + e
            return .init(question: "(\(a)×\(b)) − (\(c)×\(d)) + \(e)", correctAnswer: ans)
        case 2:
            // Square + product
            let n = Int.random(in: 12...20)
            let x = Int.random(in: 4...12), y = Int.random(in: 4...12)
            return .init(question: "\(n)² + \(x) × \(y)",
                         correctAnswer: n * n + x * y)
        default:
            // Percentage: what is X% of Y (using 10, 15, 20, 25, 50)
            let pcts = [10, 15, 20, 25, 50]
            let pct  = pcts.randomElement()!
            // Choose Y so result is always a clean integer
            let base = [20, 40, 60, 80, 100, 120, 150, 200, 240, 300, 400, 500]
                .randomElement()!
            let ans  = base * pct / 100
            return .init(question: "What is \(pct)% of \(base)?", correctAnswer: ans)
        }
    }
}

// MARK: - UnlockViewModel

/// Manages the entire unlock flow for a single `Rule`.
///
/// ## Challenge sequencing
/// A Rule can have multiple `UnlockChallenge`s.  The user completes them one at
/// a time, in order.  `currentChallenge` exposes the active one.  After all
/// challenges pass, `isUnlocked` is set and `BlockingService` removes the shield.
///
/// ## Escalation (architecture doc §8)
/// On init the ViewModel loads the stored `UnlockAttempt` for this rule.  If the
/// previous unlock was within `rule.escalationWindowMinutes` AND escalation is
/// enabled, the base challenges are scaled by `currentMultiplier` (2×, 3×, up to 5×).
///
/// ## Paste prevention (typeSentence challenge)
/// The ViewModel validates `typedSentence == requiredSentence` character-by-character,
/// but **disabling paste** requires a `UIViewRepresentable` wrapper around `UITextField`.
/// ⚠️  Build `PasteBlockingTextField` in Phase 5.  The ViewModel is correct now.
@MainActor
final class UnlockViewModel: ObservableObject {

    // MARK: - Core data

    let rule: Rule

    private let ruleStore: RuleStore
    private let stepMonitor: StepMonitor
    private let blockingService: BlockingService

    // MARK: - Escalation state

    @Published private(set) var attempt: UnlockAttempt
    @Published private(set) var currentMultiplier: Int = 1
    @Published private(set) var isEscalating: Bool = false

    // MARK: - Challenge sequence

    private var scaledChallenges: [UnlockChallenge] = []

    @Published private(set) var currentChallengeIndex: Int = 0

    var currentChallenge: UnlockChallenge? {
        guard currentChallengeIndex < scaledChallenges.count else { return nil }
        return scaledChallenges[currentChallengeIndex]
    }

    /// Total number of challenges the user must complete.
    var totalChallenges: Int { scaledChallenges.count }

    /// `true` once every challenge in the sequence has been passed.
    @Published private(set) var isUnlocked: Bool = false

    // MARK: - Step challenge

    @Published private(set) var stepsFromStart: Int = 0
    @Published private(set) var stepsSinceMidnight: Int = 0

    private var challengeStartedAt: Date = Date()
    private var stepCancellable: AnyCancellable?

    // MARK: - Maths challenge

    @Published private(set) var mathsProblems: [MathsProblem] = []
    @Published private(set) var mathsIndex: Int = 0
    @Published var mathsAnswer: String = ""
    @Published private(set) var mathsAnswerWrong: Bool = false

    var mathsProgress: String {
        guard !mathsProblems.isEmpty else { return "" }
        return "\(mathsIndex + 1) / \(mathsProblems.count)"
    }

    // MARK: - Sentence challenge
    //
    // ⚠️  Paste disabling requires UIViewRepresentable (PasteBlockingTextField).
    // Build in Phase 5.  Matching logic is complete here.

    @Published var typedSentence: String = ""

    var requiredSentence: String {
        if case .typeSentence(let s) = currentChallenge { return s }
        return ""
    }

    var sentenceMatchesRequired: Bool { typedSentence == requiredSentence }

    // MARK: - Wait challenge

    @Published private(set) var waitSecondsRemaining: Int = 0
    @Published private(set) var waitExpired: Bool = false
    private var waitTimerCancellable: AnyCancellable?

    var waitProgress: Double {
        guard case .wait(let mins) = currentChallenge, mins > 0 else { return 0 }
        let total = Double(mins * 60)
        return max(0, min(1, 1 - Double(waitSecondsRemaining) / total))
    }

    // MARK: - Reason challenge

    @Published var writtenReason: String = ""
    static let minimumReasonLength = 20

    var reasonIsValid: Bool {
        writtenReason.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumReasonLength
    }

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        rule: Rule,
        ruleStore: RuleStore,
        stepMonitor: StepMonitor? = nil,
        blockingService: BlockingService? = nil
    ) {
        self.rule             = rule
        self.ruleStore        = ruleStore
        self.stepMonitor      = stepMonitor ?? StepMonitor()
        self.blockingService  = blockingService ?? BlockingService.shared

        // Load persisted escalation state.
        self.attempt = ruleStore.attempt(for: rule.id)

        buildScaledChallenges()
        startChallenge(at: 0)
    }

    // MARK: - Escalation setup

    private func buildScaledChallenges() {
        let inWindow   = attempt.isInEscalationWindow(
            escalationWindowMinutes: rule.escalationWindowMinutes
        )
        let multiplier = (rule.escalationEnabled && inWindow) ? attempt.currentMultiplier : 1
        currentMultiplier = multiplier
        isEscalating      = multiplier > 1
        scaledChallenges  = rule.challengesByDifficulty.map { $0.scaled(by: multiplier) }
    }

    // MARK: - Challenge lifecycle

    private func startChallenge(at index: Int) {
        guard index < scaledChallenges.count else {
            completeAllChallenges()
            return
        }
        currentChallengeIndex = index
        challengeStartedAt    = Date()
        mathsAnswerWrong      = false

        switch scaledChallenges[index] {
        case .steps(let required):
            startStepChallenge(required: required)
        case .maths(let count):
            startMathsChallenge(count: count)
        case .typeSentence:
            typedSentence = ""
        case .wait(let minutes):
            startWaitCountdown(totalSeconds: minutes * 60)
        case .writeReason:
            writtenReason = ""
        }
    }

    /// Advances to the next challenge, or finalises the unlock if all are done.
    func advanceToNextChallenge() {
        stepCancellable?.cancel()
        stepMonitor.stopLiveStepTracking()
        waitTimerCancellable?.cancel()
        startChallenge(at: currentChallengeIndex + 1)
    }

    // MARK: - Step challenge

    private func startStepChallenge(required: Int) {
        stepMonitor.startLiveStepTracking(from: challengeStartedAt)

        // Observe step count and auto-advance when the goal is reached.
        stepCancellable = stepMonitor.$stepsFromTrackingStart
            .sink { [weak self] steps in
                guard let self else { return }
                self.stepsFromStart = steps
                if steps >= required {
                    self.stepCancellable?.cancel()
                    self.advanceToNextChallenge()
                }
            }

        stepMonitor.$stepsSinceMidnight
            .assign(to: \.stepsSinceMidnight, on: self)
            .store(in: &cancellables)
    }

    /// Triggers an immediate HealthKit refresh (for the "Check now" button).
    func refreshStepsNow() {
        stepMonitor.refreshNow()
    }

    // MARK: - Maths challenge

    private func startMathsChallenge(count: Int) {
        mathsProblems = (0..<count).map { _ in
            MathsProblem.generate(difficulty: currentMultiplier)
        }
        mathsIndex   = 0
        mathsAnswer  = ""
    }

    /// Validates the current maths answer and advances to the next problem.
    /// Sets `mathsAnswerWrong = true` if the answer is incorrect.
    func submitMathsAnswer() {
        guard mathsIndex < mathsProblems.count else { return }

        let expected = mathsProblems[mathsIndex].correctAnswer
        guard let submitted = Int(mathsAnswer.trimmingCharacters(in: .whitespaces)),
              submitted == expected
        else {
            mathsAnswerWrong = true
            return
        }

        mathsAnswerWrong = false
        mathsAnswer      = ""
        mathsIndex      += 1

        if mathsIndex >= mathsProblems.count {
            advanceToNextChallenge()
        }
    }

    // MARK: - Sentence challenge

    /// Advances past the sentence challenge.  Only callable when `sentenceMatchesRequired`.
    func submitSentenceChallenge() {
        guard sentenceMatchesRequired else { return }
        advanceToNextChallenge()
    }

    // MARK: - Wait challenge

    private func startWaitCountdown(totalSeconds: Int) {
        waitSecondsRemaining = totalSeconds
        waitExpired          = false

        waitTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.waitSecondsRemaining > 0 {
                    self.waitSecondsRemaining -= 1
                } else {
                    self.waitTimerCancellable?.cancel()
                    self.waitExpired = true
                }
            }
    }

    /// Advances past the wait challenge.  Only callable once `waitExpired == true`.
    func confirmWaitComplete() {
        guard waitExpired else { return }
        advanceToNextChallenge()
    }

    // MARK: - Reason challenge

    /// Advances past the reason challenge.  Only callable when `reasonIsValid`.
    func submitReason() {
        guard reasonIsValid else { return }
        advanceToNextChallenge()
    }

    // MARK: - Completion

    private func completeAllChallenges() {
        // Remove the ManagedSettings shield so the app can open immediately.
        blockingService.removeShield(for: rule)

        // Grant the user a session — write expiry to App Group UserDefaults so
        // both the main app and the DeviceActivity extension can respect it.
        let sessionExpiry = Date().addingTimeInterval(Double(rule.sessionDurationMinutes) * 60)
        UserDefaults(suiteName: "group.com.debrajpal.frictiongate")?
            .set(sessionExpiry.timeIntervalSince1970,
                 forKey: "session_expires_\(rule.id.uuidString)")

        // Schedule a DeviceActivity relock that fires at the exact session-expiry
        // moment — this re-locks the app even while the user is still inside it,
        // without requiring Friction to be in the foreground.
        DeviceActivityService.shared.scheduleSessionRelock(for: rule)

        // Update the rule's unlock bookkeeping.
        var updatedRule = rule
        updatedRule.lastUnlockedAt = Date()
        updatedRule.unlockCount   += 1
        ruleStore.update(updatedRule)

        // Record the unlock in the escalation state machine.
        var updatedAttempt = ruleStore.attempt(for: rule.id)
        updatedAttempt.recordUnlock(escalationWindowMinutes: rule.escalationWindowMinutes)
        ruleStore.saveAttempt(updatedAttempt)

        // Clear the "pending unlock" flag that the shield extension wrote.
        UserDefaults(suiteName: "group.com.debrajpal.frictiongate")?
            .removeObject(forKey: "pending_unlock_rule_id")

        isUnlocked = true
    }

    // MARK: - Cleanup

    /// Call from the View's `.onDisappear` when the user abandons the unlock screen.
    /// Does NOT record an unlock or modify escalation state.
    func abandon() {
        stepCancellable?.cancel()
        stepMonitor.stopLiveStepTracking()
        waitTimerCancellable?.cancel()
        // Clear the pending unlock key so Friction doesn't re-show the screen
        // on the next foreground if the user cancelled without completing.
        UserDefaults(suiteName: "group.com.debrajpal.frictiongate")?
            .removeObject(forKey: "pending_unlock_rule_id")
        UserDefaults(suiteName: "group.com.debrajpal.frictiongate")?
            .removeObject(forKey: "pending_unlock_timestamp")
    }
}
