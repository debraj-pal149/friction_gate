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

    /// Set when the user initiates a pause on a rule.  The View presents a
    /// `PauseRuleView` sheet bound to this value.
    @Published var pendingPauseRule: Rule?

    /// The exact 5-line text the user must type to confirm the pause.
    /// Generated from `pendingPauseRule` by `startPause(for:)`.
    @Published private(set) var pauseConfirmationText: String = ""

    // MARK: - Init

    init(
        ruleStore: RuleStore,
        blockingService: BlockingService = .shared,
        deviceActivityService: DeviceActivityService = .shared
    ) {
        self.ruleStore = ruleStore
        self.blockingService = blockingService
        self.deviceActivityService = deviceActivityService

        // Keep rules in sync with the store without duplicating state.
        ruleStore.$rules
            .assign(to: &$rules)
    }

    // MARK: - Rules management

    /// Reloads rules from App Group UserDefaults.
    func refreshRules() {
        ruleStore.load()
    }

    /// Deletes a rule, removing its shield and DeviceActivity schedules.
    func deleteRule(_ rule: Rule) {
        blockingService.removeShield(for: rule)
        deviceActivityService.removeSchedules(for: rule)
        ruleStore.delete(rule)
        ruleStore.resetAttempt(for: rule.id)
    }

    /// Toggles `isActive` without a confirmation flow.
    /// Use `startPause(for:)` when you want friction (the type-to-pause sheet).
    func toggleActive(_ rule: Rule) {
        var updated = rule
        updated.isActive.toggle()
        updated.isPaused = false
        updated.pauseUntil = nil
        ruleStore.update(updated)

        if updated.isActive {
            deviceActivityService.registerSchedules(for: updated)
        } else {
            deviceActivityService.removeSchedules(for: updated)
            blockingService.removeShield(for: updated)
        }
    }

    // MARK: - Pause flow (type-to-confirm, architecture doc §9)

    /// Begins the pause flow.  Populates `pauseConfirmationText` and sets
    /// `pendingPauseRule` so the View can present the confirmation sheet.
    func startPause(for rule: Rule) {
        pendingPauseRule = rule
        pauseConfirmationText = generatePauseText(for: rule)
    }

    /// Applies the pause after the user has typed the confirmation text exactly.
    ///
    /// - Parameter duration: How long to pause the rule (default: 30 minutes).
    func confirmPause(for rule: Rule, duration: TimeInterval = 30 * 60) {
        var updated = rule
        updated.isPaused = true
        updated.pauseUntil = Date().addingTimeInterval(duration)
        ruleStore.update(updated)
        blockingService.removeShield(for: updated)
        deviceActivityService.removeSchedules(for: updated)
        cancelPause()
    }

    /// Cancels the pending pause flow without making any changes.
    func cancelPause() {
        pendingPauseRule = nil
        pauseConfirmationText = ""
    }

    // MARK: - Pause text (architecture doc §9)

    /// Generates the 5-line type-to-pause text for a given rule.
    ///
    /// The text is deterministic for a rule, so it can be pre-generated and
    /// displayed to the user before they start typing.
    func generatePauseText(for rule: Rule) -> String {
        let app  = rule.appDisplayName
        let cond = rule.conditions.first?.pauseDescription ?? "this time of day"
        return [
            "I am choosing to pause my \(app) block right now.",
            "This rule exists because I decided I use \(app) too much during \(cond).",
            "Pausing it is a conscious choice, not a mindless one.",
            "I take full responsibility for how I use this time.",
            "I will re-enable this rule when I am done.",
        ].joined(separator: "\n")
    }
}

// MARK: - BlockCondition display helpers
//
// Defined here so both HomeViewModel and RuleBuilderViewModel (same module) can
// use them without an extra file.  Pure Swift — no UIKit or SwiftUI imports needed.

extension BlockCondition {

    /// A concise human-readable description of when this condition is active.
    /// Used in the rule review summary and the pause confirmation text.
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

    /// Variant phrased for mid-sentence use in the pause confirmation text.
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

// Free helpers — file-private so they don't pollute the module namespace.

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
