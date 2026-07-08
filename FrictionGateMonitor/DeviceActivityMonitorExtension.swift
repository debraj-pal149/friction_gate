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
        static let settings   = "app_settings"
        static let selections = "stored_selections"
        static let wakeDetectedAt = "wake_detected_at"
    }

    private func dailyLimitExceededKey(_ ruleID: UUID) -> String {
        "dailyLimitExceeded_\(ruleID.uuidString)"
    }

    // MARK: - DeviceActivityMonitor overrides

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Session-relock activities only care about intervalDidEnd — ignore start.
        guard !activity.rawValue.hasPrefix("fg-relock-") else { return }

        // Wake-window proxy: evaluate .afterWakeUp rules without requiring Friction
        // to foreground at wake time.
        if activity.rawValue.hasPrefix("fg-wakewindow-") {
            handleWakeWindowIntervalStart()
            return
        }

        guard let (ruleIDString, conditionIndex) = parseActivity(activity),
              var rule = loadRule(id: ruleIDString)
        else { return }

        // Reset daily open-limit state at the start of each monitoring day.
        if conditionIndex < rule.conditions.count,
           case .dailyOpenLimit = rule.conditions[conditionIndex] {
            defaults.removeObject(forKey: dailyLimitExceededKey(rule.id))
        }

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
        guard let (ruleIDString, endingConditionIndex) = parseActivity(activity),
              let rule = loadRule(id: ruleIDString),
              let token = rule.appToken
        else { return }

        // Daily open-limit resets at end-of-day; clear the threshold signal before
        // recomputing so we don't read stale exceeded state from yesterday.
        if endingConditionIndex < rule.conditions.count,
           case .dailyOpenLimit = rule.conditions[endingConditionIndex] {
            defaults.removeObject(forKey: dailyLimitExceededKey(rule.id))
        }

        // IMPORTANT: do not blindly remove the token here. Other conditions/rules
        // may still require this same app to remain blocked right now.
        recomputeShield(
            for: token,
            endingRuleID: rule.id,
            endingConditionIndex: endingConditionIndex
        )
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

        defaults.set(true, forKey: dailyLimitExceededKey(rule.id))
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

    // MARK: - Shield recompute (prevents transient unblocked gaps)

    private func recomputeShield(
        for token: ApplicationToken,
        endingRuleID: UUID? = nil,
        endingConditionIndex: Int? = nil
    ) {
        let allRules = loadAllRules()
        let relatedRules = allRules.filter { $0.appToken == token }
        guard !relatedRules.isEmpty else { return }

        let shouldKeepShield = relatedRules.contains { rule in
            shouldBlockNow(
                rule: rule,
                endingRuleID: endingRuleID,
                endingConditionIndex: endingConditionIndex
            )
        }

        var current = managedStore.shield.applications ?? []
        if shouldKeepShield {
            current.insert(token)
            managedStore.shield.applications = current
        } else {
            current.remove(token)
            managedStore.shield.applications = current.isEmpty ? nil : current
        }

        // Keep per-rule shared flags in sync with the recomputed truth.
        for rule in relatedRules {
            let active = shouldBlockNow(
                rule: rule,
                endingRuleID: endingRuleID,
                endingConditionIndex: endingConditionIndex
            )
            let key = "shielded_\(rule.id.uuidString)"
            if active {
                defaults.set(true, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private func shouldBlockNow(
        rule: Rule,
        endingRuleID: UUID? = nil,
        endingConditionIndex: Int? = nil
    ) -> Bool {
        guard rule.isEnforcing else { return false }
        guard !isSessionActive(for: rule.id.uuidString) else { return false }
        guard !rule.conditions.isEmpty else { return true }

        for (index, condition) in rule.conditions.enumerated() {
            // The specific schedule that just ended must be considered inactive
            // for this recompute pass.
            if let endingRuleID, let endingConditionIndex,
               rule.id == endingRuleID && index == endingConditionIndex {
                continue
            }
            if isConditionActiveNow(condition, for: rule.id) {
                return true
            }
        }
        return false
    }

    /// Pure evaluation of whether a condition requires blocking right now.
    /// Must not read shield output keys — only condition parameters and dedicated
    /// threshold signals (e.g. dailyLimitExceeded_).
    private func isConditionActiveNow(_ condition: BlockCondition, for ruleID: UUID) -> Bool {
        switch condition {
        case .timeWindow(let start, let end, let days):
            return isTimeWindowActive(start: start, end: end, days: days)
        case .beforeSleep(let sleepTime, let durationMinutes):
            return isBeforeSleepActive(sleepTime: sleepTime, durationMinutes: durationMinutes)
        case .afterWakeUp(let minutes):
            return isAfterWakeUpActive(durationMinutes: minutes)
        case .dailyOpenLimit:
            return defaults.bool(forKey: dailyLimitExceededKey(ruleID))
        }
    }

    // MARK: - Wake-window proxy

    private func handleWakeWindowIntervalStart() {
        let settings = loadAppSettings()
        guard isWithinWakeUpWindow(settings: settings, at: Date()) else { return }

        // Conservative proxy: entering the wake window without a same-day detection
        // timestamp means the user likely just woke up.
        if !isWakeDetectedToday() {
            defaults.set(Date().timeIntervalSince1970, forKey: Keys.wakeDetectedAt)
        }

        let afterWakeUpRules = loadAllRules().filter { rule in
            rule.isEnforcing && rule.conditions.contains { condition in
                if case .afterWakeUp = condition { return true }
                return false
            }
        }

        let tokens = Set(afterWakeUpRules.compactMap(\.appToken))
        for token in tokens {
            recomputeShield(for: token)
        }
    }

    private func loadAppSettings() -> AppSettings {
        guard let data = defaults.data(forKey: Keys.settings),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return .default }
        return settings
    }

    private func isWithinWakeUpWindow(settings: AppSettings, at date: Date) -> Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let nowMin = hour * 60 + minute

        let startMin = (settings.wakeUpWindowStart.hour ?? 5) * 60
                     + (settings.wakeUpWindowStart.minute ?? 0)
        let endMin = (settings.wakeUpWindowEnd.hour ?? 11) * 60
                   + (settings.wakeUpWindowEnd.minute ?? 0)

        return nowMin >= startMin && nowMin < endMin
    }

    private func isWakeDetectedToday() -> Bool {
        let ts = defaults.double(forKey: Keys.wakeDetectedAt)
        guard ts > 0 else { return false }
        return Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts))
    }

    // MARK: - Rule loading from App Group UserDefaults

    /// Decodes the stored `[Rule]` array, finds the rule with the given UUID string,
    /// and reattaches its `FamilyActivitySelection` so that `rule.appToken` works.
    private func loadRule(id ruleIDString: String) -> Rule? {
        guard let uuid = UUID(uuidString: ruleIDString) else { return nil }
        return loadAllRules().first(where: { $0.id == uuid })
    }

    /// Decodes all stored rules and reattaches each rule's selection map entry
    /// so appToken comparisons and shielding logic are reliable.
    private func loadAllRules() -> [Rule] {
        guard let rulesData = defaults.data(forKey: Keys.rules),
              var rules = try? JSONDecoder().decode([Rule].self, from: rulesData)
        else { return [] }

        guard let outerData = defaults.data(forKey: Keys.selections),
              let map = try? JSONDecoder().decode([String: Data].self, from: outerData)
        else { return rules }

        for i in rules.indices {
            let key = rules[i].id.uuidString
            guard let selData = map[key],
                  let selection = try? PropertyListDecoder()
                    .decode(FamilyActivitySelection.self, from: selData) else { continue }
            rules[i].activitySelection = selection
        }
        return rules
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

    private func isTimeWindowActive(
        start: DateComponents,
        end: DateComponents,
        days: DaySet
    ) -> Bool {
        let cal = Calendar.current
        let now = Date()

        guard days.contains(todayAsDaySet()) else { return false }

        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let nowMin = h * 60 + m
        let startMin = (start.hour ?? 0) * 60 + (start.minute ?? 0)
        let endMin = (end.hour ?? 0) * 60 + (end.minute ?? 0)

        if startMin <= endMin {
            return nowMin >= startMin && nowMin < endMin
        } else {
            return nowMin >= startMin || nowMin < endMin
        }
    }

    private func isBeforeSleepActive(
        sleepTime: DateComponents,
        durationMinutes: Int
    ) -> Bool {
        let cal = Calendar.current
        let now = Date()
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let nowMin = h * 60 + m
        let sleepMin = (sleepTime.hour ?? 23) * 60 + (sleepTime.minute ?? 0)
        let startMin = sleepMin - durationMinutes

        if startMin >= 0 {
            return nowMin >= startMin && nowMin < sleepMin
        } else {
            return nowMin >= (startMin + 1440) || nowMin < sleepMin
        }
    }

    private func isAfterWakeUpActive(durationMinutes: Int) -> Bool {
        let detectedTS = defaults.double(forKey: Keys.wakeDetectedAt)
        guard detectedTS > 0 else { return false }
        let detected = Date(timeIntervalSince1970: detectedTS)
        return Date() < detected.addingTimeInterval(Double(durationMinutes) * 60)
    }
}
