import Foundation

/// Tracks per-rule escalation state for the unlock challenge.
///
/// Stored in `RuleStore` (UserDefaults, App Group) so the state survives
/// app kills between unlock attempts.
struct UnlockAttempt: Identifiable, Codable, Hashable {

    // MARK: - Identity

    var id: UUID { ruleID }
    var ruleID: UUID

    // MARK: - Escalation tracking

    /// When the most recent successful unlock for this rule occurred.
    var lastUnlockedAt: Date?

    /// Number of times the rule has been unlocked within the current escalation window.
    /// Resets to 0 when `Date() - lastUnlockedAt > escalationWindowSeconds`.
    var unlockCountInWindow: Int

    /// Current difficulty multiplier applied to the base challenge (1×, 2×, 3×, …).
    var currentMultiplier: Int

    // MARK: - Init

    init(ruleID: UUID,
         lastUnlockedAt: Date? = nil,
         unlockCountInWindow: Int = 0,
         currentMultiplier: Int = 1) {
        self.ruleID = ruleID
        self.lastUnlockedAt = lastUnlockedAt
        self.unlockCountInWindow = unlockCountInWindow
        self.currentMultiplier = currentMultiplier
    }

    // MARK: - Escalation helpers

    /// Updates escalation state after a successful unlock.
    /// - Parameter escalationWindowMinutes: The window length from the parent Rule.
    mutating func recordUnlock(escalationWindowMinutes: Int) {
        let now = Date()
        let windowSeconds = Double(escalationWindowMinutes) * 60

        if let last = lastUnlockedAt, now.timeIntervalSince(last) < windowSeconds {
            unlockCountInWindow += 1
            currentMultiplier = min(unlockCountInWindow + 1, 5) // cap at 5×
        } else {
            // Outside the window — reset the escalation counter.
            unlockCountInWindow = 1
            currentMultiplier = 1
        }

        lastUnlockedAt = now
    }

    /// Whether the escalation window is still active right now.
    func isInEscalationWindow(escalationWindowMinutes: Int) -> Bool {
        guard let last = lastUnlockedAt else { return false }
        let windowSeconds = Double(escalationWindowMinutes) * 60
        return Date().timeIntervalSince(last) < windowSeconds
    }

    /// Resets all escalation state (e.g. when the rule is paused/re-enabled).
    mutating func reset() {
        lastUnlockedAt = nil
        unlockCountInWindow = 0
        currentMultiplier = 1
    }
}
