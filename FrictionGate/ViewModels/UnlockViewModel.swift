import Foundation
import Combine

// MARK: - MathsProblem

/// A single arithmetic problem for the maths unlock challenge.
struct MathsProblem: Equatable {
    let question: String
    let correctAnswer: Int

    /// Generates a random arithmetic problem.
    ///
    /// - Parameter difficulty: 1–5 scale; higher values use larger numbers.
    static func generate(difficulty: Int = 1) -> MathsProblem {
        let d      = max(1, min(difficulty, 5))
        let maxN   = 5 + d * 5          // range 10–30 depending on difficulty
        let a      = Int.random(in: 2...maxN)
        let b      = Int.random(in: 2...maxN)

        switch Int.random(in: 0...2) {
        case 1:                         // Subtraction — always positive result
            let big = max(a, b), small = min(a, b)
            return MathsProblem(question: "\(big) − \(small)", correctAnswer: big - small)
        case 2:                         // Multiplication — smaller numbers to stay sane
            let x = Int.random(in: 2...9)
            let y = Int.random(in: 2...9)
            return MathsProblem(question: "\(x) × \(y)", correctAnswer: x * y)
        default:                        // Addition
            return MathsProblem(question: "\(a) + \(b)", correctAnswer: a + b)
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
        scaledChallenges  = rule.challenges.map { $0.scaled(by: multiplier) }
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
        stepMonitor.stopMonitoring()
        waitTimerCancellable?.cancel()
        startChallenge(at: currentChallengeIndex + 1)
    }

    // MARK: - Step challenge

    private func startStepChallenge(required: Int) {
        stepMonitor.startMonitoring(from: challengeStartedAt)

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
        stepMonitor.stopMonitoring()
        waitTimerCancellable?.cancel()
    }
}
