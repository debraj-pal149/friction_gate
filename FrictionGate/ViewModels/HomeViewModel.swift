import Foundation
import Combine

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Dependencies

    private let ruleStore: RuleStore
    private let blockingService: BlockingService
    private let deviceActivityService: DeviceActivityService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published state

    /// Mirrors `ruleStore.rules` so Views only need to observe this ViewModel.
    @Published var rules: [Rule] = []

    /// Which rule IDs currently have an active ManagedSettings shield.
    /// Used for the "Blocked / Unlocked" badge — NOT for the toggle.
    @Published var shieldedRuleIDs: Set<UUID> = []

    /// Set when the user taps a toggle to DISABLE an active rule.
    /// HomeView presents UnlockView so the user must complete the challenge.
    /// On dismiss, if the challenge succeeded, the rule is deactivated.
    @Published var pendingDisableFromToggle: Rule? = nil

    /// Set when the user taps a toggle to UNLOCK a currently-blocked app
    /// outside of the disable-rule flow (legacy direct-unlock path).
    @Published var pendingUnlockFromToggle: Rule? = nil

    /// Set when the user tries to RE-LOCK an app while a session is still active.
    /// HomeView shows a confirmation alert.
    @Published var pendingRelockRule: Rule? = nil

    /// Human-friendly message for the re-lock confirmation alert.
    @Published private(set) var relockMessage: String = ""

    // MARK: - Init

    init(
        ruleStore: RuleStore,
        blockingService: BlockingService = .shared,
        deviceActivityService: DeviceActivityService = .shared
    ) {
        self.ruleStore = ruleStore
        self.blockingService = blockingService
        self.deviceActivityService = deviceActivityService

        ruleStore.$rules
            .assign(to: &$rules)
    }

    // MARK: - Rules management

    func refreshRules() {
        ruleStore.load()
    }

    func deleteRule(_ rule: Rule) {
        blockingService.removeShield(for: rule)
        deviceActivityService.removeSchedules(for: rule)
        ruleStore.delete(rule)
        ruleStore.resetAttempt(for: rule.id)
        shieldedRuleIDs.remove(rule.id)
    }

    // MARK: - Shield state

    /// Reads the live ManagedSettings state for every rule and updates
    /// `shieldedRuleIDs`.  Call on every app foreground and after actions.
    func refreshShieldStates() {
        let blocked = rules.filter { blockingService.isShielded($0) }.map(\.id)
        shieldedRuleIDs = Set(blocked)
    }

    // MARK: - Toggle tap handler
    //
    // The toggle reflects WHETHER THE RULE IS ACTIVE (not paused / disabled),
    // regardless of whether the app is currently shielded.
    //
    //   • rule active   → user wants to DISABLE it → challenge required
    //   • rule inactive → user wants to RE-ENABLE  → immediate, no challenge

    func handleToggleTap(for rule: Rule) {
        if rule.isActive {
            // User wants to disable the rule — require the rule's challenge first.
            pendingDisableFromToggle = rule
        } else {
            // Rule is off — re-enable it immediately.
            enableRule(rule)
        }
    }

    /// Called by HomeView after the "disable" UnlockView dismisses.
    /// If the challenge was completed (shield was removed), we deactivate the rule.
    func didDismissDisableChallenge() {
        guard let rule = pendingDisableFromToggle else { return }
        pendingDisableFromToggle = nil
        refreshShieldStates()

        // The challenge succeeded when UnlockViewModel removed the shield.
        // (Cancelled challenge leaves the shield in place.)
        if !shieldedRuleIDs.contains(rule.id) {
            deactivateRule(rule)
        }
    }

    /// Called by HomeView after the legacy UnlockView dismisses.
    func didDismissUnlock() {
        pendingUnlockFromToggle = nil
        refreshShieldStates()
    }

    /// Called after the user confirms early re-lock via the alert.
    func confirmRelock() {
        guard let rule = pendingRelockRule else { return }
        applyRelockNow(rule)
        pendingRelockRule = nil
    }

    func cancelRelock() {
        pendingRelockRule = nil
    }

    // MARK: - Enable / disable helpers

    private func enableRule(_ rule: Rule) {
        guard var updated = ruleStore.rules.first(where: { $0.id == rule.id }) else { return }
        updated.isActive = true
        ruleStore.update(updated)
        // Re-register DeviceActivity schedules.
        deviceActivityService.registerSchedules(for: updated)
        // Apply shield immediately for unconditional (always-block) rules.
        if updated.conditions.isEmpty {
            blockingService.applyShield(for: updated)
            shieldedRuleIDs.insert(updated.id)
        }
        refreshShieldStates()
    }

    private func deactivateRule(_ rule: Rule) {
        guard var updated = ruleStore.rules.first(where: { $0.id == rule.id }) else { return }
        updated.isActive = false
        ruleStore.update(updated)
        // Remove the live shield in case it is still on for any reason.
        blockingService.removeShield(for: updated)
        shieldedRuleIDs.remove(updated.id)
        // Cancel session relock timer and all DeviceActivity schedules.
        let shared = UserDefaults(suiteName: "group.com.debrajpal.frictiongate")
        shared?.removeObject(forKey: "session_expires_\(updated.id.uuidString)")
        deviceActivityService.cancelSessionRelock(for: updated.id)
        deviceActivityService.removeSchedules(for: updated)
    }

    // MARK: - Private helpers

    private func applyRelockNow(_ rule: Rule) {
        // Clear any active session so the shield sticks.
        UserDefaults(suiteName: "group.com.debrajpal.frictiongate")?
            .removeObject(forKey: "session_expires_\(rule.id.uuidString)")
        deviceActivityService.cancelSessionRelock(for: rule.id)

        blockingService.applyShield(for: rule)
        shieldedRuleIDs.insert(rule.id)
    }

    private func remainingSessionMinutes(for ruleID: UUID) -> Int? {
        guard let defaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate")
        else { return nil }
        let expiryTS = defaults.double(forKey: "session_expires_\(ruleID.uuidString)")
        guard expiryTS > 0 else { return nil }
        let remaining = expiryTS - Date().timeIntervalSince1970
        guard remaining > 0 else { return nil }
        return max(1, Int(ceil(remaining / 60)))
    }

    private func buildRelockMessage(rule: Rule, remainingMinutes: Int) -> String {
        let app = rule.appDisplayName.isEmpty ? "This app" : rule.appDisplayName
        let timer = remainingMinutes == 1
            ? "about a minute"
            : "about \(remainingMinutes) minutes"
        let challenges = challengeSummary(for: rule)
        return "\(app) will lock itself automatically in \(timer). " +
               "If you lock it now, you'll need to \(challenges) to get back in, and the timer will reset."
    }

    private func challengeSummary(for rule: Rule) -> String {
        let parts = rule.challenges.map { challenge -> String in
            switch challenge {
            case .steps(let n):     return "walk \(n) steps"
            case .maths(let c):     return "solve \(c) maths \(c == 1 ? "problem" : "problems")"
            case .typeSentence:     return "type out a sentence"
            case .wait(let m):      return "wait \(m) \(m == 1 ? "minute" : "minutes")"
            case .writeReason:      return "write out why you want to use it"
            }
        }
        switch parts.count {
        case 0:  return "complete a challenge"
        case 1:  return parts[0]
        case 2:  return "\(parts[0]) and \(parts[1])"
        default:
            return parts.dropLast().joined(separator: ", ") + ", and \(parts.last!)"
        }
    }
}

// MARK: - BlockCondition display helpers

extension BlockCondition {

    var displayDescription: String {
        switch self {
        case .timeWindow(let start, let end, let days):
            return "\(days.displayName) from \(blockTimeLabel(start)) to \(blockTimeLabel(end))"
        case .afterWakeUp(let mins):
            return "the first \(blockDurationLabel(mins)) after waking up"
        case .beforeSleep(_, let mins):
            return "the \(blockDurationLabel(mins)) before sleep"
        case .dailyOpenLimit(let max):
            return "opening it more than \(max) time\(max == 1 ? "" : "s") per day"
        }
    }

    var pauseDescription: String {
        switch self {
        case .timeWindow(let start, let end, let days):
            return "\(days.displayName) between \(blockTimeLabel(start)) and \(blockTimeLabel(end))"
        case .afterWakeUp(let mins):
            return "the first \(blockDurationLabel(mins)) after waking up"
        case .beforeSleep(_, let mins):
            return "the \(blockDurationLabel(mins)) before sleep"
        case .dailyOpenLimit(let max):
            return "the \(max == 1 ? "first" : "first \(max)") open\(max == 1 ? "" : "s") per day"
        }
    }
}

private func blockTimeLabel(_ dc: DateComponents) -> String {
    let h = dc.hour ?? 0
    let m = dc.minute ?? 0
    let period = h < 12 ? "am" : "pm"
    let hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
    return m == 0
        ? "\(hour12)\(period)"
        : "\(hour12):\(String(format: "%02d", m))\(period)"
}

private func blockDurationLabel(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    switch (h, m) {
    case (0, _): return m == 1 ? "minute"  : "\(m) minutes"
    case (_, 0): return h == 1 ? "hour"    : "\(h) hours"
    default:     return "\(h)h \(m)m"
    }
}
