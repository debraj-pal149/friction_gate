import Foundation
import ManagedSettings
import FamilyControls

/// Applies and removes `ManagedSettings` shields in the main app process.
///
/// ## Cross-process shield state
/// `ManagedSettingsStore` is per-process: the main app can only read shields it
/// wrote itself.  When the monitor extension applies a shield (via DeviceActivity
/// callbacks), the main app's `managedStore` is unaware of it.
///
/// To give every process a single source of truth, `applyShield` / `removeShield`
/// also write a `shielded_<ruleID>` boolean to the shared App Group UserDefaults.
/// `isShielded(_:)` reads from UserDefaults, not from `managedStore`, so it
/// correctly reflects shields applied by either process.
///
/// The monitor extension mirrors this pattern in its own `applyShield` /
/// `removeShield` helpers.
@MainActor
final class BlockingService {

    static let shared = BlockingService()

    private let managedStore = ManagedSettingsStore()

    private let defaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate")

    // MARK: - Apply / remove by token set

    func applyShield(for tokens: Set<ApplicationToken>) {
        var current = managedStore.shield.applications ?? []
        current.formUnion(tokens)
        managedStore.shield.applications = current
    }

    func removeShield(for tokens: Set<ApplicationToken>) {
        guard var current = managedStore.shield.applications else { return }
        current.subtract(tokens)
        managedStore.shield.applications = current.isEmpty ? nil : current
    }

    func removeAllShields() {
        managedStore.shield.applications = nil
    }

    // MARK: - Apply / remove by Rule

    func applyShield(for rule: Rule) {
        guard let token = rule.appToken else { return }
        applyShield(for: [token])
        defaults?.set(true, forKey: shieldKey(rule.id))
    }

    func removeShield(for rule: Rule) {
        guard let token = rule.appToken else { return }
        removeShield(for: [token])
        defaults?.removeObject(forKey: shieldKey(rule.id))
    }

    /// Reads cross-process shield state from App Group UserDefaults.
    /// This correctly reflects shields applied by either the main app or the
    /// monitor extension, unlike reading from `managedStore` which is per-process.
    func isShielded(_ rule: Rule) -> Bool {
        defaults?.bool(forKey: shieldKey(rule.id)) ?? false
    }

    private func shieldKey(_ ruleID: UUID) -> String {
        "shielded_\(ruleID.uuidString)"
    }

    // MARK: - Full condition evaluation

    /// Evaluates all runtime-managed conditions for a rule and applies or
    /// removes the shield accordingly.
    ///
    /// Call this each time the app foregrounds so that `afterWakeUp` and
    /// `timeWindow` conditions are kept in sync with the current clock.
    ///
    /// - Parameter wakeUpDetector: The shared `WakeUpDetector` instance,
    ///   needed to evaluate `.afterWakeUp` conditions.
    func evaluateAndApplyShield(for rule: Rule, wakeUpDetector: WakeUpDetector) {
        guard rule.isEnforcing else {
            removeShield(for: rule)
            return
        }

        // No conditions → always block when the rule is active.
        guard !rule.conditions.isEmpty else {
            applyShield(for: rule)
            return
        }

        let shouldBlock = rule.conditions.contains {
            isConditionActive($0, wakeUpDetector: wakeUpDetector)
        }

        if shouldBlock {
            applyShield(for: rule)
        } else {
            removeShield(for: rule)
        }
    }

    // MARK: - Condition helpers

    private func isConditionActive(
        _ condition: BlockCondition,
        wakeUpDetector: WakeUpDetector
    ) -> Bool {
        switch condition {
        case .timeWindow(let start, let end, let days):
            return isTimeWindowActive(start: start, end: end, days: days)
        case .afterWakeUp(let minutes):
            return wakeUpDetector.isAfterWakeUpActive(durationMinutes: minutes)
        case .beforeSleep(let sleepTime, let durationMinutes):
            return isBeforeSleepActive(sleepTime: sleepTime, durationMinutes: durationMinutes)
        case .dailyOpenLimit:
            // Handled by the DeviceActivityMonitor extension's eventDidReachThreshold.
            return false
        }
    }

    private func isTimeWindowActive(
        start: DateComponents,
        end: DateComponents,
        days: DaySet
    ) -> Bool {
        let cal  = Calendar.current
        let now  = Date()

        guard days.contains(dayFlag(for: cal.component(.weekday, from: now))) else {
            return false
        }

        let h   = cal.component(.hour, from: now)
        let m   = cal.component(.minute, from: now)
        let nowMin   = h * 60 + m
        let startMin = (start.hour ?? 0) * 60 + (start.minute ?? 0)
        let endMin   = (end.hour   ?? 0) * 60 + (end.minute   ?? 0)

        if startMin <= endMin {
            return nowMin >= startMin && nowMin < endMin
        } else {
            // Window crosses midnight (e.g. 22:00 – 02:00).
            return nowMin >= startMin || nowMin < endMin
        }
    }

    private func isBeforeSleepActive(
        sleepTime: DateComponents,
        durationMinutes: Int
    ) -> Bool {
        let cal = Calendar.current
        let now = Date()
        let h   = cal.component(.hour, from: now)
        let m   = cal.component(.minute, from: now)
        let nowMin   = h * 60 + m
        let sleepMin = (sleepTime.hour ?? 23) * 60 + (sleepTime.minute ?? 0)
        let startMin = sleepMin - durationMinutes

        if startMin >= 0 {
            return nowMin >= startMin && nowMin < sleepMin
        } else {
            // Block window wraps midnight (e.g. sleep 00:30, start 23:30).
            return nowMin >= (startMin + 1440) || nowMin < sleepMin
        }
    }

    /// Maps a `Calendar.weekday` component (1 = Sunday … 7 = Saturday) to a `DaySet` flag.
    private func dayFlag(for weekday: Int) -> DaySet {
        switch weekday {
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
