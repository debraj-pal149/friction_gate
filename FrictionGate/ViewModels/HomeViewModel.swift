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

    var rulesByDifficulty: [Rule] {
        rules.sorted { lhs, rhs in
            if lhs.difficultyScore == rhs.difficultyScore {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.difficultyScore < rhs.difficultyScore
        }
    }

    /// Which rule IDs currently have an active ManagedSettings shield.
    /// Used for the "Blocked / Unblocked" status in Home.
    @Published var shieldedRuleIDs: Set<UUID> = []

    /// Set when user requests to unlock an app. HomeView presents UnlockView.
    @Published var pendingUnlockRule: Rule? = nil

    /// Set when the user tries to RE-LOCK an app while a session is still active.
    /// HomeView shows a confirmation alert.
    @Published var pendingRelockRule: Rule? = nil

    /// Human-friendly message for the re-lock confirmation alert.
    @Published private(set) var relockMessage: String = ""

    // MARK: - Init

    init(
        ruleStore: RuleStore,
        blockingService: BlockingService? = nil,
        deviceActivityService: DeviceActivityService? = nil
    ) {
        self.ruleStore = ruleStore
        self.blockingService = blockingService ?? BlockingService.shared
        self.deviceActivityService = deviceActivityService ?? DeviceActivityService.shared

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

    // MARK: - Unlock flow

    func requestUnlock(for rule: Rule) {
        pendingUnlockRule = rule
    }

    func didDismissUnlock() {
        pendingUnlockRule = nil
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
        let parts = rule.challengesByDifficulty.map { challenge -> String in
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
