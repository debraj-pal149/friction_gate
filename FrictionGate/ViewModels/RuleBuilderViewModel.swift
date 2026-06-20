import Foundation
import Combine
import FamilyControls

// MARK: - Builder step

/// Represents each screen in the rule-creation flow.
enum BuilderStep: Int, CaseIterable {
    case appPicker      = 0   // Screen 1 — pick the app
    case conditionPicker      // Screen 2 — choose when to block
    case challengePicker      // Screen 3 — choose unlock challenges
    case review               // Screen 4 — confirm and save
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
    // `appDisplayName` is populated by the View after the user picks an app
    // (read from `activitySelection.applications.first?.localizedDisplayName` or
    // typed manually if the display name is unavailable).

    @Published var activitySelection: FamilyActivitySelection = FamilyActivitySelection()
    @Published var appDisplayName: String = ""

    // MARK: - Block conditions

    @Published var conditions: [BlockCondition] = []

    // MARK: - Unlock challenges

    @Published var challenges: [UnlockChallenge] = []

    // MARK: - Escalation

    @Published var escalationEnabled: Bool = false
    @Published var escalationWindowMinutes: Int = 120

    // MARK: - Init

    init(
        ruleStore: RuleStore,
        deviceActivityService: DeviceActivityService = .shared
    ) {
        self.ruleStore = ruleStore
        self.deviceActivityService = deviceActivityService
    }

    // MARK: - Validation

    var isAppSelected: Bool {
        !activitySelection.applicationTokens.isEmpty || !appDisplayName.isEmpty
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
        ]
        if escalationEnabled {
            lines.append(
                "Escalation is on — each unlock within \(escalationWindowMinutes) min " +
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
            conditions: conditions,
            challenges: challenges,
            escalationEnabled: escalationEnabled,
            escalationWindowMinutes: escalationWindowMinutes
        )
        // Attach the selection so RuleStore can archive ApplicationToken correctly.
        rule.activitySelection = activitySelection

        // `ruleStore.add` calls `save()` which calls `saveSelectionMap()`,
        // which archives the FamilyActivitySelection for this rule.
        ruleStore.add(rule)

        // Register DeviceActivity schedules for time-based conditions.
        deviceActivityService.registerSchedules(for: rule)

        reset()
    }

    // MARK: - Reset

    /// Clears all builder state, typically called after save or on sheet dismiss.
    func reset() {
        activitySelection        = FamilyActivitySelection()
        appDisplayName           = ""
        conditions               = []
        challenges               = []
        escalationEnabled        = false
        escalationWindowMinutes  = 120
        currentStep              = .appPicker
    }
}
