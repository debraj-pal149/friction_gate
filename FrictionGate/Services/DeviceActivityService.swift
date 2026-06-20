import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

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
/// | `.afterWakeUp`      | Not registered here — evaluated at runtime by         |
/// |                     | `WakeUpDetector` + `BlockingService`.                 |
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
                break  // Runtime-only; no DeviceActivityCenter schedule needed.
            }
        }
    }

    /// Stops all `DeviceActivityCenter` schedules for `rule`.
    ///
    /// Call when a rule is deleted, deactivated, or paused.
    func removeSchedules(for rule: Rule) {
        // Probe the first 20 indices — rules won't realistically have more conditions.
        let names = (0..<20).map { activityName(for: rule.id, index: $0) }
        center.stopMonitoring(names)
    }

    // MARK: - Helpers

    /// Canonical activity name for a specific condition in a rule.
    ///
    /// The monitor extension reverses this to identify the rule:
    /// ```
    /// let ruleID = UUID(uuidString: name.rawValue
    ///     .replacingOccurrences(of: "fg-", with: "")
    ///     .components(separatedBy: "-").dropLast().joined(separator: "-"))
    /// ```
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
    ///
    ///     sleepTime = 23:00, durationMinutes = 90  →  21:30
    ///     sleepTime = 00:30, durationMinutes = 60  →  23:30  (wraps midnight)
    private func startComponents(before sleepTime: DateComponents, by minutes: Int) -> DateComponents {
        let total   = (sleepTime.hour ?? 23) * 60 + (sleepTime.minute ?? 0) - minutes
        let clamped = ((total % 1440) + 1440) % 1440
        var dc = DateComponents()
        dc.hour   = clamped / 60
        dc.minute = clamped % 60
        return dc
    }
}
