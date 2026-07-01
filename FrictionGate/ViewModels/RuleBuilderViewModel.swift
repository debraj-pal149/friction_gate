import Foundation
import Combine
import FamilyControls
import ManagedSettings

// MARK: - Builder step

/// Represents each screen in the rule-creation flow.
enum BuilderStep: Int, CaseIterable {
    case appPicker      = 0   // Screen 1 — pick the app
    case conditionPicker      // Screen 2 — choose when to block
    case challengePicker      // Screen 3 — choose unlock challenges
    case escalation           // Screen 4 — escalation & session settings
    case review               // Screen 5 — confirm and save
}

// MARK: - RuleBuilderViewModel

@MainActor
final class RuleBuilderViewModel: ObservableObject {

    // MARK: - Dependencies

    private let ruleStore: RuleStore
    private let deviceActivityService: DeviceActivityService

    // MARK: - Step tracking

    @Published var currentStep: BuilderStep = .appPicker

    // MARK: - App selection
    //
    // `activitySelection` is bound directly to `FamilyActivityPicker` in the View.
    // `appDisplayName` is now an **optional user-defined nickname** — the real name
    // and icon come from `Label(application)` using the OS token.
    // `appBundleID` is kept for any string-based lookups but may be nil on device.

    @Published var activitySelection: FamilyActivitySelection = FamilyActivitySelection()
    @Published var appDisplayName: String = ""   // optional nickname
    @Published var appBundleID: String? = nil

    /// The first selected `ApplicationToken` — use with `Label(token)` in SwiftUI
    /// for privacy-compliant OS-rendered icon and name display.
    var applicationToken: ApplicationToken? {
        activitySelection.applicationTokens.first
    }

    /// All selected application tokens from FamilyActivityPicker.
    var selectedApplicationTokens: [ApplicationToken] {
        Array(activitySelection.applicationTokens)
    }

    // MARK: - Block conditions

    @Published var conditions: [BlockCondition] = []

    // MARK: - Unlock challenges

    @Published var challenges: [UnlockChallenge] = []

    var challengesSortedByDifficulty: [UnlockChallenge] {
        challenges.sorted { lhs, rhs in
            if lhs.difficultyScore == rhs.difficultyScore {
                return lhs.displayName < rhs.displayName
            }
            return lhs.difficultyScore < rhs.difficultyScore
        }
    }

    // MARK: - Escalation & session

    @Published var escalationEnabled: Bool = false
    @Published var escalationWindowMinutes: Int = 120
    @Published var sessionDurationMinutes: Int = 20
    @Published var ruleConflictMessage: String? = nil

    // MARK: - Init

    init(
        ruleStore: RuleStore,
        deviceActivityService: DeviceActivityService = .shared
    ) {
        self.ruleStore = ruleStore
        self.deviceActivityService = deviceActivityService
    }

    // MARK: - Validation

    // An app is selected as soon as the picker returns a token.
    // appDisplayName (nickname) is no longer required to advance.
    var isAppSelected: Bool {
        !activitySelection.applicationTokens.isEmpty
    }

    var hasConditions:  Bool { !conditions.isEmpty }
    var hasChallenges:  Bool { !challenges.isEmpty }

    var isValid: Bool { isAppSelected && hasConditions && hasChallenges }

    /// Whether the user can advance past the current step.
    var canAdvance: Bool {
        switch currentStep {
        case .appPicker:       return isAppSelected
        case .conditionPicker: return hasConditions
        case .challengePicker: return hasChallenges
        case .escalation:      return true   // always optional — user can skip
        case .review:          return isValid
        }
    }

    // MARK: - Step navigation

    func nextStep() {
        if currentStep == .conditionPicker,
           let conflict = firstTimeWindowConflictMessage() {
            ruleConflictMessage = conflict
            return
        }
        guard canAdvance,
              let next = BuilderStep(rawValue: currentStep.rawValue + 1)
        else { return }
        currentStep = next
    }

    func previousStep() {
        guard let prev = BuilderStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    // MARK: - Conditions

    func addCondition(_ condition: BlockCondition) {
        guard !conditions.contains(condition) else { return }
        conditions.append(condition)
    }

    func removeCondition(_ condition: BlockCondition) {
        conditions.removeAll { $0 == condition }
    }

    func removeCondition(at offsets: IndexSet) {
        conditions.remove(atOffsets: offsets)
    }

    // MARK: - Challenges

    func addChallenge(_ challenge: UnlockChallenge) {
        guard !challenges.contains(challenge) else { return }
        challenges.append(challenge)
    }

    func removeChallenge(_ challenge: UnlockChallenge) {
        challenges.removeAll { $0 == challenge }
    }

    func removeChallenge(at offsets: IndexSet) {
        challenges.remove(atOffsets: offsets)
    }

    // MARK: - Review summary

    /// Multi-line summary of the rule being built.
    /// Displayed on the review screen and used as a preview in rule rows.
    var reviewSummary: String {
        guard isValid else { return "Complete all steps to preview the rule." }

        let appCount = selectedApplicationTokens.count
        let app: String
        if appCount > 1 {
            app = "\(appCount) selected apps"
        } else {
            app = appDisplayName.isEmpty ? "The selected app" : appDisplayName
        }
        let conds  = conditions.map(\.displayDescription).joined(separator: ", and ")
        let challs = challengesSortedByDifficulty.map(\.shortDescription).joined(separator: " + ")

        var lines = [
            "\(app) will be blocked during \(conds).",
            "To unlock: \(challs).",
            "After unlocking, you have \(sessionDurationMinutes) minute\(sessionDurationMinutes == 1 ? "" : "s") before it re-locks.",
        ]
        if escalationEnabled {
            lines.append(
                "Escalation is on. Each unlock within \(escalationWindowMinutes) min " +
                "makes the next challenge harder (up to 5×)."
            )
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Save

    /// Validates the builder state, constructs a `Rule`, persists it via
    /// `RuleStore`, registers `DeviceActivity` schedules, and resets the builder.
    func save() -> Bool {
        guard isValid else { return false }
        if let conflict = firstTimeWindowConflictMessage() {
            ruleConflictMessage = conflict
            return false
        }

        let tokens = selectedApplicationTokens
        guard !tokens.isEmpty else { return false }

        for token in tokens {
            var rule = Rule(
                appDisplayName: appDisplayName,
                appBundleID: appBundleID,
                conditions: conditions,
                challenges: challengesSortedByDifficulty,
                escalationEnabled: escalationEnabled,
                escalationWindowMinutes: escalationWindowMinutes,
                sessionDurationMinutes: sessionDurationMinutes
            )
            // Each created rule keeps exactly one app token so rule rows/unlock flow
            // remain one-app-per-rule throughout the app.
            rule.activitySelection = makeSingleAppSelection(for: token)

            // `ruleStore.add` calls `save()` which calls `saveSelectionMap()`,
            // which archives the FamilyActivitySelection for this rule.
            ruleStore.add(rule)

            // Register DeviceActivity schedules for time-based conditions.
            deviceActivityService.registerSchedules(for: rule)

            // For unconditional rules (no time/wake/sleep/limit conditions) the shield
            // should be active immediately.  Write the flag to App Group UserDefaults so
            // HomeViewModel.refreshShieldStates() sees the correct state right away.
            if rule.conditions.isEmpty {
                BlockingService.shared.applyShield(for: rule)
            }
        }

        reset()
        return true
    }

    // MARK: - Reset

    /// Clears all builder state, typically called after save or on sheet dismiss.
    func reset() {
        activitySelection       = FamilyActivitySelection()
        appDisplayName          = ""
        appBundleID             = nil
        conditions              = []
        challenges              = []
        escalationEnabled       = false
        escalationWindowMinutes = 120
        sessionDurationMinutes  = 20
        ruleConflictMessage     = nil
        currentStep             = .appPicker
    }

    // MARK: - Time-window conflict detection

    /// Returns the first overlap conflict message when creating new rule(s) for the
    /// same app(s) with overlapping time-window conditions.
    private func firstTimeWindowConflictMessage() -> String? {
        let proposedWindows = conditions.compactMap { condition -> (DateComponents, DateComponents, DaySet)? in
            guard case let .timeWindow(start, end, days) = condition else { return nil }
            return (start, end, days)
        }
        guard !proposedWindows.isEmpty else { return nil }

        let tokens = selectedApplicationTokens
        guard !tokens.isEmpty else { return nil }

        for selectedToken in tokens {
            for existingRule in ruleStore.rules {
                guard isSameSelectedApp(as: existingRule, selectedToken: selectedToken) else { continue }

                let existingWindows = existingRule.conditions.compactMap { condition -> (DateComponents, DateComponents, DaySet)? in
                    guard case let .timeWindow(start, end, days) = condition else { return nil }
                    return (start, end, days)
                }
                guard !existingWindows.isEmpty else { continue }

                for proposed in proposedWindows {
                    for existing in existingWindows where windowsOverlap(lhs: proposed, rhs: existing) {
                        let existingRuleName = existingRule.appDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let label = existingRuleName.isEmpty
                            ? "Rule \(existingRule.id.uuidString.prefix(6))"
                            : existingRuleName
                        let existingSummary = BlockCondition
                            .timeWindow(start: existing.0, end: existing.1, days: existing.2)
                            .displayDescription

                        return "Cannot continue: one of the selected apps already has rule '\(label)' with an overlapping time window (\(existingSummary)). Adjust the time/days to proceed."
                    }
                }
            }
        }
        return nil
    }

    private func isSameSelectedApp(as existingRule: Rule, selectedToken: ApplicationToken) -> Bool {
        if let existingToken = existingRule.appToken,
           selectedToken == existingToken {
            return true
        }
        let selectedBundle = appBundleID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let existingBundle = existingRule.appBundleID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let selectedBundle, !selectedBundle.isEmpty,
           let existingBundle, !existingBundle.isEmpty,
           selectedBundle == existingBundle {
            return true
        }
        return false
    }

    private func makeSingleAppSelection(for token: ApplicationToken) -> FamilyActivitySelection {
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [token]
        return selection
    }

    private func windowsOverlap(
        lhs: (DateComponents, DateComponents, DaySet),
        rhs: (DateComponents, DateComponents, DaySet)
    ) -> Bool {
        let lhsIntervals = weeklyIntervals(start: lhs.0, end: lhs.1, days: lhs.2)
        let rhsIntervals = weeklyIntervals(start: rhs.0, end: rhs.1, days: rhs.2)
        for a in lhsIntervals {
            for b in rhsIntervals where max(a.start, b.start) < min(a.end, b.end) {
                return true
            }
        }
        return false
    }

    private func weeklyIntervals(
        start: DateComponents,
        end: DateComponents,
        days: DaySet
    ) -> [(start: Int, end: Int)] {
        let startMinute = minuteOfDay(from: start)
        let endMinute = minuteOfDay(from: end)
        let dayMinutes = 24 * 60
        var result: [(Int, Int)] = []

        for dayIndex in dayIndexes(days) {
            let dayStart = dayIndex * dayMinutes
            if startMinute == endMinute {
                // Interpret equal start/end as full-day block for that day.
                result.append((dayStart, dayStart + dayMinutes))
            } else if startMinute < endMinute {
                result.append((dayStart + startMinute, dayStart + endMinute))
            } else {
                // Overnight window (e.g. 10pm → 6am): split into two intervals.
                result.append((dayStart + startMinute, dayStart + dayMinutes))
                let nextDay = ((dayIndex + 1) % 7) * dayMinutes
                result.append((nextDay, nextDay + endMinute))
            }
        }
        return result
    }

    private func dayIndexes(_ days: DaySet) -> [Int] {
        var result: [Int] = []
        if days.contains(.monday)    { result.append(0) }
        if days.contains(.tuesday)   { result.append(1) }
        if days.contains(.wednesday) { result.append(2) }
        if days.contains(.thursday)  { result.append(3) }
        if days.contains(.friday)    { result.append(4) }
        if days.contains(.saturday)  { result.append(5) }
        if days.contains(.sunday)    { result.append(6) }
        return result
    }

    private func minuteOfDay(from components: DateComponents) -> Int {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return max(0, min(23, hour)) * 60 + max(0, min(59, minute))
    }
}
