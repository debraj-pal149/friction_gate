import Foundation
import Combine

/// Detects wake-up via foreground idle-gap as a **fallback only**.
///
/// ## Priority of wake stamps (all write `wake_detected_at`)
/// 1. PRIMARY: `SleepWakeDetector` (HealthKit sleep analysis end) — background
/// 2. SECONDARY: DeviceActivity `fg-wakevent-*` (first monitored app use) — extension
/// 3. FALLBACK: this class, on Friction foreground after idle + wake window
///
/// Fix B: whichever path stamps first for a calendar day wins. Later Friction
/// opens must not overwrite `wake_detected_at`.
///
/// ## Approximation honesty
/// There is no public API for true physiological wake. Fallback wake time equals
/// Friction open time — accurate only if the user opened Friction before other
/// morning activity that HealthKit / DeviceActivity failed to observe.
@MainActor
final class WakeUpDetector: ObservableObject {

    // MARK: - Storage

    private let defaults: UserDefaults = {
        guard let d = UserDefaults(suiteName: "group.com.debrajpal.frictiongate") else {
            fatalError("App Group 'group.com.debrajpal.frictiongate' is not configured.")
        }
        return d
    }()

    enum Keys {
        static let lastActive      = "wake_last_active_timestamp"
        static let detectedAt      = "wake_detected_at"
        static let wakeWindowArmed = "wake_window_armed"
    }

    // MARK: - Published state

    /// When the most recent wake-up event was detected.
    /// `nil` if no wake-up has been recorded yet.
    @Published private(set) var wakeUpDetectedAt: Date?

    // MARK: - Init

    init() {
        syncFromDefaults()
    }

    // MARK: - Sync / cleanup

    /// Reloads in-memory state from App Group (extension / HK may have stamped).
    func syncFromDefaults() {
        clearStaleWakeStampIfNeeded()
        let stored = defaults.double(forKey: Keys.detectedAt)
        if stored > 0 {
            wakeUpDetectedAt = Date(timeIntervalSince1970: stored)
        } else {
            wakeUpDetectedAt = nil
        }
    }

    /// Supplementary midnight cleanup when Friction opens (primary reset is
    /// `fg-wakemidnight-reset` DeviceActivity schedule).
    func clearStaleWakeStampIfNeeded() {
        let ts = defaults.double(forKey: Keys.detectedAt)
        guard ts > 0 else { return }
        let stamped = Date(timeIntervalSince1970: ts)
        if !Calendar.current.isDateInToday(stamped) {
            defaults.removeObject(forKey: Keys.detectedAt)
            defaults.removeObject(forKey: Keys.wakeWindowArmed)
            wakeUpDetectedAt = nil
        }
    }

    var isWakeDetectedToday: Bool {
        let ts = defaults.double(forKey: Keys.detectedAt)
        guard ts > 0 else { return false }
        return Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts))
    }

    /// Records a wake stamp if none exists for today. Returns `true` if this call stamped.
    @discardableResult
    func recordWakeDetection(at date: Date) -> Bool {
        clearStaleWakeStampIfNeeded()
        guard !isWakeDetectedToday else { return false }

        wakeUpDetectedAt = date
        defaults.set(date.timeIntervalSince1970, forKey: Keys.detectedAt)
        defaults.removeObject(forKey: Keys.wakeWindowArmed)
        return true
    }

    // MARK: - Foreground callback (fallback stamp path)

    /// Must be called every time `scenePhase` changes to `.active` in
    /// `FrictionGateApp`.
    ///
    /// Always writes the current timestamp to `lastActiveTimestamp`, then
    /// evaluates whether this foreground event qualifies as a **fallback** wake.
    func appDidBecomeActive(settings: AppSettings) {
        let now = Date()

        // Always update the activity timestamp, even if detection is disabled,
        // so the idle gap stays accurate once detection is re-enabled.
        defer { defaults.set(now.timeIntervalSince1970, forKey: Keys.lastActive) }

        syncFromDefaults()

        // Fix B: once-per-day — HealthKit or DeviceActivity already stamped a better time.
        if isWakeDetectedToday { return }

        guard settings.wakeUpDetectionEnabled else { return }

        let lastActive  = storedLastActive()
        let idleSeconds = now.timeIntervalSince(lastActive)
        let threshold   = Double(settings.wakeUpIdleHours) * 3_600

        guard idleSeconds > threshold else { return }
        guard isWithinWakeUpWindow(settings: settings, at: now) else { return }

        // FALLBACK STAMP: only reached if HealthKit and DeviceActivity both failed
        // to detect wake today. Wake time = Friction open time (degraded mode).
        guard recordWakeDetection(at: now) else { return }

        // Apply shields + schedule auto-expiry without requiring another open.
        applyAfterWakeEffects(wakeDetectedAt: now)
    }

    /// Shared post-stamp work for main-app paths (fallback + HealthKit).
    func applyAfterWakeEffects(wakeDetectedAt: Date) {
        let rules = DeviceActivityService.loadAfterWakeUpRules(defaults: defaults)
        DeviceActivityService.shared.scheduleAfterWakeExpiryForAllAfterWakeRules(
            wakeDetectedAt: wakeDetectedAt
        )
        for rule in rules {
            BlockingService.shared.evaluateAndApplyShield(
                for: rule,
                wakeUpDetector: self
            )
        }
    }

    // MARK: - Condition check

    /// Returns `true` if the device woke up recently and the post-wake block
    /// window of `durationMinutes` has not yet expired.
    func isAfterWakeUpActive(durationMinutes: Int) -> Bool {
        syncFromDefaults()
        guard let detected = wakeUpDetectedAt else { return false }
        return Date() < detected.addingTimeInterval(Double(durationMinutes) * 60)
    }

    // MARK: - Private helpers

    private func storedLastActive() -> Date {
        let ts = defaults.double(forKey: Keys.lastActive)
        // If there is no prior record, returning `Date()` makes the idle gap 0,
        // which correctly suppresses a spurious wake-up detection on first launch.
        guard ts > 0 else { return Date() }
        return Date(timeIntervalSince1970: ts)
    }

    private func isWithinWakeUpWindow(settings: AppSettings, at date: Date) -> Bool {
        let cal    = Calendar.current
        let hour   = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let nowMin = hour * 60 + minute

        let startMin = (settings.wakeUpWindowStart.hour   ?? 5)  * 60
                     + (settings.wakeUpWindowStart.minute ?? 0)
        let endMin   = (settings.wakeUpWindowEnd.hour     ?? 11) * 60
                     + (settings.wakeUpWindowEnd.minute   ?? 0)

        return nowMin >= startMin && nowMin < endMin
    }
}
