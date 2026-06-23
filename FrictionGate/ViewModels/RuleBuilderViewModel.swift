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

    // MARK: - Block conditions

    @Published var conditions: [BlockCondition] = []

    // MARK: - Unlock challenges

    @Published var challenges: [UnlockChallenge] = []

    // MARK: - Escalation & session

    @Published var escalationEnabled: Bool = false
    @Published var escalationWindowMinutes: Int = 120
    @Published var sessionDurationMinutes: Int = 20

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

        let app    = appDisplayName.isEmpty ? "the selected app" : appDisplayName
        let conds  = conditions.map(\.displayDescription).joined(separator: ", and ")
        let challs = challenges.map(\.shortDescription).joined(separator: " + ")

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
    func save() {
        guard isValid else { return }

        var rule = Rule(
            appDisplayName: appDisplayName,
            appBundleID: appBundleID,
            conditions: conditions,
            challenges: challenges,
            escalationEnabled: escalationEnabled,
            escalationWindowMinutes: escalationWindowMinutes,
            sessionDurationMinutes: sessionDurationMinutes
        )
        // Attach the selection so RuleStore can archive ApplicationToken correctly.
        rule.activitySelection = activitySelection

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

        reset()
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
        currentStep             = .appPicker
    }
}
