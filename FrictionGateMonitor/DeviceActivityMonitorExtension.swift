//
//  DeviceActivityMonitorExtension.swift
//  FrictionGateMonitor
//
//  Created by Debraj Pal on 20/06/26.
//
// ⚠️  TARGET MEMBERSHIP REQUIRED — READ BEFORE BUILDING
//
// This extension decodes Rule and BlockCondition values that are written to the
// App Group UserDefaults by the main app.  For the Swift types to be visible here
// you MUST add the following files to the FrictionGateMonitor target in Xcode:
//
//   In Xcode: click each file → File Inspector (right panel) → Target Membership
//   ☑  FrictionGate/Models/Rule.swift
//   ☑  FrictionGate/Models/BlockCondition.swift
//   ☑  FrictionGate/Models/UnlockChallenge.swift
//   ☑  FrictionGate/Models/UnlockAttempt.swift
//   ☑  FrictionGate/Models/AppSettings.swift
//
// Also ensure FamilyControls and ManagedSettings are linked to FrictionGateMonitor
// (Xcode usually does this automatically when the extension target is created).

import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // MARK: - Shared storage

    private let defaults: UserDefaults = {
        guard let d = UserDefaults(suiteName: "group.com.debrajpal.frictiongate") else {
            fatalError("App Group is not configured for FrictionGateMonitor.")
        }
        return d
    }()

    private let managedStore = ManagedSettingsStore()

    // UserDefaults keys — must match the string literals in RuleStore.Keys
    private enum Keys {
        static let rules      = "stored_rules"
        static let selections = "stored_selections"
    }

    // MARK: - DeviceActivityMonitor overrides

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Session-relock activities only care about intervalDidEnd — ignore start.
        guard !activity.rawValue.hasPrefix("fg-relock-") else { return }

        guard let (ruleIDString, conditionIndex) = parseActivity(activity),
              var rule = loadRule(id: ruleIDString)
        else { return }

        // Day-of-week guard: DeviceActivityCenter fires every day regardless of DaySet.
        if conditionIndex < rule.conditions.count,
           case .timeWindow(_, _, let days) = rule.conditions[conditionIndex],
           !days.contains(todayAsDaySet()) {
            return
        }

        // Session guard: if the user just completed an unlock challenge and their
        // session hasn't expired yet, don't re-block immediately.
        if isSessionActive(for: ruleIDString) { return }

        applyShield(for: &rule)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        let raw = activity.rawValue

        // Session-relock schedule: fg-relock-<UUID>
        // This fires at the exact moment the user's unlock session expires —
        // even if the user is still actively using the blocked app.
        if raw.hasPrefix("fg-relock-") {
            let ruleIDString = String(raw.dropFirst("fg-relock-".count))
            guard var rule = loadRule(id: ruleIDString) else { return }

            // Clear the session key — it has now expired.
            defaults.removeObject(forKey: "session_expires_\(ruleIDString)")

            // Re-apply the shield. If the user is currently inside the blocked
            // app, iOS will show the shield overlay immediately.
            applyShield(for: &rule)
            return
        }

        // Regular condition schedule: fg-<UUID>-<conditionIndex>
        // The block window has ended — remove the shield.
        guard let (ruleIDString, _) = parseActivity(activity),
              var rule = loadRule(id: ruleIDString)
        else { return }

        // Remove this rule's token.  If the rule has multiple conditions,
        // BlockingService will re-evaluate and reapply on the next app foreground.
        removeShield(for: &rule)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        // The dailyOpenLimit threshold has been reached — apply the shield for the
        // remainder of the day.  DeviceActivityCenter will call intervalDidEnd at
        // 23:59 to release it.
        guard let (ruleIDString, _) = parseActivity(activity),
              var rule = loadRule(id: ruleIDString)
        else { return }

        applyShield(for: &rule)
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        // Not used in V1.
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        // Not used in V1.
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        // Not used in V1.
    }

    // MARK: - Shield application

    private func applyShield(for rule: inout Rule) {
        guard let token = rule.appToken else { return }
        var current = managedStore.shield.applications ?? []
        current.insert(token)
        managedStore.shield.applications = current
        // Mirror state into shared UserDefaults so the main app's
        // BlockingService.isShielded() returns the correct value.
        defaults.set(true, forKey: "shielded_\(rule.id.uuidString)")
    }

    private func removeShield(for rule: inout Rule) {
        guard let token = rule.appToken else { return }
        guard var current = managedStore.shield.applications else { return }
        current.remove(token)
        managedStore.shield.applications = current.isEmpty ? nil : current
        defaults.removeObject(forKey: "shielded_\(rule.id.uuidString)")
    }

    // MARK: - Rule loading from App Group UserDefaults

    /// Decodes the stored `[Rule]` array, finds the rule with the given UUID string,
    /// and reattaches its `FamilyActivitySelection` so that `rule.appToken` works.
    private func loadRule(id ruleIDString: String) -> Rule? {
        guard let uuid = UUID(uuidString: ruleIDString) else { return nil }

        guard let rulesData = defaults.data(forKey: Keys.rules),
              var rules = try? JSONDecoder().decode([Rule].self, from: rulesData),
              let idx = rules.firstIndex(where: { $0.id == uuid })
        else { return nil }

        // Reattach the FamilyActivitySelection so appToken is non-nil.
        if let outerData  = defaults.data(forKey: Keys.selections),
           let map        = try? JSONDecoder().decode([String: Data].self, from: outerData),
           let selData    = map[ruleIDString],
           let selection  = try? PropertyListDecoder()
               .decode(FamilyActivitySelection.self, from: selData) {
            rules[idx].activitySelection = selection
        }

        return rules[idx]
    }

    // MARK: - Activity name helpers

    /// Parses `"fg-<UUID>-<conditionIndex>"` into its components.
    /// Returns `nil` for any name that doesn't follow the convention.
    private func parseActivity(
        _ name: DeviceActivityName
    ) -> (ruleID: String, conditionIndex: Int)? {
        let raw = name.rawValue
        guard raw.hasPrefix("fg-") else { return nil }

        // body = "<UUID>-<conditionIndex>"
        let body = String(raw.dropFirst(3))

        // A UUID string is always exactly 36 characters.
        guard body.count > 37 else { return nil }
        let uuidPart  = String(body.prefix(36))
        let indexPart = String(body.dropFirst(37)) // skip UUID (36) + "-" (1)

        guard let index = Int(indexPart) else { return nil }
        return (uuidPart, index)
    }

    // MARK: - Session helper

    /// Returns `true` if an active (non-expired) unlock session exists for the
    /// given rule ID string.  The session key is written by `UnlockViewModel`
    /// and cleared by `FrictionGateApp` once it expires.
    private func isSessionActive(for ruleIDString: String) -> Bool {
        let key = "session_expires_\(ruleIDString)"
        let expiryTS = defaults.double(forKey: key)
        guard expiryTS > 0 else { return false }
        return Date().timeIntervalSince1970 < expiryTS
    }

    // MARK: - Day-of-week helper

    /// Returns the `DaySet` flag for today based on `Calendar.current.weekday`.
    private func todayAsDaySet() -> DaySet {
        switch Calendar.current.component(.weekday, from: Date()) {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .sunday
        }
    }
}
