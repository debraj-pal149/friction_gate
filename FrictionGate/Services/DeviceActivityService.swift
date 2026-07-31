import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications

/// Registers and removes `DeviceActivityCenter` schedules on behalf of Rules.
///
/// ## How scheduling maps to `BlockCondition`
///
/// | Condition           | Handling                                              |
/// |---------------------|-------------------------------------------------------|
/// | `.timeWindow`       | `DeviceActivitySchedule` (daily repeat). Day-of-week  |
/// |                     | filtering is enforced by the monitor extension.        |
/// | `.beforeSleep`      | `DeviceActivitySchedule` computed from sleep time.    |
/// | `.dailyOpenLimit`   | `DeviceActivitySchedule` (midnight→23:59) with a      |
/// |                     | `DeviceActivityEvent` whose threshold ≈ maxOpens min. |
/// | `.afterWakeUp`      | Wake-window schedule + first-use event + one-shot     |
/// |                     | expiry (`fg-wakeexpiry-*`). Wake stamp itself comes   |
/// |                     | from HealthKit / wake event / foreground fallback.    |
///
/// ## Activity naming convention
/// All schedules for a rule are named `"fg-<ruleID>-<conditionIndex>"` so the
/// monitor extension can reconstruct the rule ID from the activity name.
final class DeviceActivityService {

    static let shared = DeviceActivityService()

    private let center = DeviceActivityCenter()

    // MARK: - Public interface

    /// Registers `DeviceActivityCenter` schedules for all applicable conditions
    /// in `rule`.  Any previously registered schedules for the same rule are
    /// removed first.
    ///
    /// Call this when a rule is created, updated, paused/unpaused, or toggled.
    func registerSchedules(for rule: Rule) {
        removeSchedules(for: rule)
        guard rule.isEnforcing, let token = rule.appToken else { return }

        let hasAfterWakeUp = rule.conditions.contains { condition in
            if case .afterWakeUp = condition { return true }
            return false
        }
        if hasAfterWakeUp {
            scheduleWakeWindowMonitoring(for: rule, settings: loadAppSettings())
            ensureMidnightWakeResetSchedule()
        }

        for (index, condition) in rule.conditions.enumerated() {
            let name = activityName(for: rule.id, index: index)
            switch condition {

            case .timeWindow(let start, let end, _):
                // Day-of-week guard lives in the monitor extension.
                startSchedule(name: name, start: start, end: end)

            case .beforeSleep(let sleepTime, let durationMinutes):
                let windowStart = startComponents(before: sleepTime, by: durationMinutes)
                startSchedule(name: name, start: windowStart, end: sleepTime)

            case .dailyOpenLimit(let maxOpens):
                // DeviceActivityEvent threshold is expressed as screen-time minutes.
                // Using maxOpens as the minute threshold is an approximation: if the
                // user opens the app `maxOpens` times for ~1 min each, the threshold
                // fires.  The monitor extension applies the shield on this callback.
                let eventName = DeviceActivityEvent.Name(name.rawValue + "-limit")
                let event = DeviceActivityEvent(
                    applications: [token],
                    threshold: DateComponents(minute: maxOpens)
                )
                var midnight = DateComponents(); midnight.hour = 0; midnight.minute = 0
                var endOfDay = DateComponents(); endOfDay.hour = 23; endOfDay.minute = 59
                startSchedule(
                    name: name,
                    start: midnight,
                    end: endOfDay,
                    events: [eventName: event]
                )

            case .afterWakeUp:
                break  // Wake-window + event monitoring registered above.
            }
        }
    }

    /// Registers a daily recurring wake-window schedule so the monitor extension
    /// can arm morning detection and observe first use of this rule's app.
    ///
    /// LIMITATION: the wake-event threshold only monitors apps enrolled in an
    /// after-wake rule. Opening an unmonitored app first will not fire this path.
    func scheduleWakeWindowMonitoring(for rule: Rule, settings: AppSettings) {
        guard let token = rule.appToken else { return }

        let name = wakeWindowActivityName(for: rule.id)
        center.stopMonitoring([name])

        let schedule = DeviceActivitySchedule(
            intervalStart: settings.wakeUpWindowStart,
            intervalEnd: settings.wakeUpWindowEnd,
            repeats: true
        )

        // Secondary wake signal: ~1 minute of usage of this rule's app during
        // the morning window ≈ "phone is no longer idle" for V1.
        let eventName = wakeEventName(for: rule.id)
        let event = DeviceActivityEvent(
            applications: [token],
            threshold: DateComponents(minute: 1)
        )

        do {
            try center.startMonitoring(name, during: schedule, events: [eventName: event])
        } catch {
            print("[DeviceActivityService] scheduleWakeWindowMonitoring failed: \(error)")
        }
    }

    /// One-shot schedule that fires when `wakeDetectedAt + afterWake duration` elapses,
    /// so shields can clear without opening Friction.
    func scheduleAfterWakeExpiry(for rule: Rule, wakeDetectedAt: Date) {
        guard let durationMinutes = Self.afterWakeDurationMinutes(in: rule) else { return }

        let cal = Calendar.current
        let expiryDate = wakeDetectedAt.addingTimeInterval(Double(durationMinutes) * 60)
        let now = Date()

        // Already past expiry — caller should recompute shields; nothing to schedule.
        guard expiryDate > now.addingTimeInterval(2) else { return }

        let startDate = now.addingTimeInterval(1)
        let startComps = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: startDate)
        let endComps = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: expiryDate)

        let name = afterWakeExpiryActivityName(for: rule.id)
        center.stopMonitoring([name])

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: false
        )
        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            print("[DeviceActivityService] scheduleAfterWakeExpiry failed: \(error)")
        }
    }

    /// Schedules expiry for every enforcing rule that has an `.afterWakeUp` condition.
    func scheduleAfterWakeExpiryForAllAfterWakeRules(wakeDetectedAt: Date) {
        for rule in Self.loadAfterWakeUpRules() {
            scheduleAfterWakeExpiry(for: rule, wakeDetectedAt: wakeDetectedAt)
        }
    }

    /// Daily 00:00→00:01 schedule that clears stale wake stamps without Friction open.
    func ensureMidnightWakeResetSchedule() {
        let name = midnightWakeResetActivityName()
        center.stopMonitoring([name])

        var start = DateComponents(); start.hour = 0; start.minute = 0
        var end = DateComponents(); end.hour = 0; end.minute = 1
        let schedule = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: end,
            repeats: true
        )
        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            print("[DeviceActivityService] ensureMidnightWakeResetSchedule failed: \(error)")
        }
    }

    /// Canonical name for wake-window proxy activities.
    /// Must start with `"fg-wakewindow-"` so the monitor extension can identify them.
    func wakeWindowActivityName(for ruleID: UUID) -> DeviceActivityName {
        DeviceActivityName("fg-wakewindow-\(ruleID.uuidString)")
    }

    func wakeEventName(for ruleID: UUID) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("fg-wakevent-\(ruleID.uuidString)")
    }

    func afterWakeExpiryActivityName(for ruleID: UUID) -> DeviceActivityName {
        DeviceActivityName("fg-wakeexpiry-\(ruleID.uuidString)")
    }

    func midnightWakeResetActivityName() -> DeviceActivityName {
        DeviceActivityName("fg-wakemidnight-reset")
    }

    /// Removes all `DeviceActivityCenter` schedules for `rule`.
    ///
    /// Call when a rule is deleted, deactivated, or paused.
    func removeSchedules(for rule: Rule) {
        // Probe the first 20 indices — rules won't realistically have more conditions.
        let names = (0..<20).map { activityName(for: rule.id, index: $0) }
        center.stopMonitoring(
            names + [
                wakeWindowActivityName(for: rule.id),
                afterWakeExpiryActivityName(for: rule.id)
            ]
        )
        // Also cancel any pending session-relock schedule.
        cancelSessionRelock(for: rule.id)
    }

    // MARK: - Session relock scheduling

    /// Schedules a one-shot `DeviceActivity` that fires at the exact session-expiry
    /// moment, regardless of whether the user is still inside the blocked app.
    ///
    /// When `intervalDidEnd` fires in `DeviceActivityMonitorExtension`, the
    /// extension re-applies the shield immediately — even with the blocked app
    /// in the foreground.
    ///
    /// KEY: intervalStart is set to NOW (+1s) so the monitoring window is
    /// `sessionDurationMinutes` wide.  A narrow window (e.g. 60s) is often
    /// rejected or delayed by DeviceActivityCenter.  intervalDidEnd still fires
    /// at the exact expiryDate regardless of how early we start.
    func scheduleSessionRelock(for rule: Rule) {
        guard rule.appToken != nil else { return }

        let cal        = Calendar.current
        let now        = Date()
        let expiryDate = now.addingTimeInterval(Double(rule.sessionDurationMinutes) * 60)

        // Start immediately so DeviceActivityCenter has the full session window
        // to track the schedule — narrow windows are unreliable.
        let startDate  = now.addingTimeInterval(1)
        let startComps = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: startDate)
        let endComps   = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: expiryDate)

        let name = relockActivityName(for: rule.id)
        center.stopMonitoring([name])

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd:   endComps,
            repeats:       false
        )
        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            print("[DeviceActivityService] scheduleSessionRelock failed: \(error)")
        }

        // Belt-and-suspenders: a local notification at expiry so the user
        // knows their session ended even if DeviceActivity has any delay.
        scheduleRelockNotification(for: rule, expiryDate: expiryDate)
    }

    /// Cancels a previously scheduled session-relock activity for `ruleID`.
    func cancelSessionRelock(for ruleID: UUID) {
        center.stopMonitoring([relockActivityName(for: ruleID)])
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["fg-session-end-\(ruleID.uuidString)"])
    }

    // MARK: - Shared after-wake helpers

    static func afterWakeDurationMinutes(in rule: Rule) -> Int? {
        for condition in rule.conditions {
            if case .afterWakeUp(let minutes) = condition {
                return minutes
            }
        }
        return nil
    }

    static func loadAfterWakeUpRules(
        defaults: UserDefaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate") ?? .standard
    ) -> [Rule] {
        guard let rulesData = defaults.data(forKey: "stored_rules"),
              var rules = try? JSONDecoder().decode([Rule].self, from: rulesData)
        else { return [] }

        if let outerData = defaults.data(forKey: "stored_selections"),
           let map = try? JSONDecoder().decode([String: Data].self, from: outerData) {
            for i in rules.indices {
                let key = rules[i].id.uuidString
                guard let selData = map[key],
                      let selection = try? PropertyListDecoder()
                        .decode(FamilyActivitySelection.self, from: selData)
                else { continue }
                rules[i].activitySelection = selection
            }
        }

        return rules.filter { rule in
            rule.isEnforcing && rule.conditions.contains { condition in
                if case .afterWakeUp = condition { return true }
                return false
            }
        }
    }

    // MARK: - Private relock notification

    private func scheduleRelockNotification(for rule: Rule, expiryDate: Date) {
        let app = rule.appDisplayName.isEmpty ? "your app" : rule.appDisplayName
        let content = UNMutableNotificationContent()
        content.title = "Your \(app) session just ended"
        content.body  = "Tap to re-block \(app) in Friction now."
        content.sound = .default
        content.categoryIdentifier = "FRICTION_RELOCK"
        content.userInfo = ["ruleID": rule.id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, expiryDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "fg-session-end-\(rule.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Canonical name for session-relock activities.
    /// Must start with `"fg-relock-"` so the monitor extension can identify them.
    func relockActivityName(for ruleID: UUID) -> DeviceActivityName {
        DeviceActivityName("fg-relock-\(ruleID.uuidString)")
    }

    // MARK: - Helpers

    /// Canonical activity name for a specific condition in a rule.
    func activityName(for ruleID: UUID, index: Int) -> DeviceActivityName {
        DeviceActivityName("fg-\(ruleID.uuidString)-\(index)")
    }

    private func startSchedule(
        name: DeviceActivityName,
        start: DateComponents,
        end: DateComponents,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
    ) {
        let schedule = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: end,
            repeats: true
        )
        do {
            try center.startMonitoring(name, during: schedule, events: events)
        } catch {
            print("[DeviceActivityService] Failed to start '\(name.rawValue)': \(error)")
        }
    }

    /// Computes the `DateComponents` for the start of a before-sleep block window.
    private func startComponents(before sleepTime: DateComponents, by minutes: Int) -> DateComponents {
        let total   = (sleepTime.hour ?? 23) * 60 + (sleepTime.minute ?? 0) - minutes
        let clamped = ((total % 1440) + 1440) % 1440
        var dc = DateComponents()
        dc.hour   = clamped / 60
        dc.minute = clamped % 60
        return dc
    }

    private func loadAppSettings() -> AppSettings {
        guard let defaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate"),
              let data = defaults.data(forKey: "app_settings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return .default }
        return settings
    }
}
