import Foundation
import Combine

/// Detects when the user wakes up after an idle period and exposes whether a
/// post-wake block window is still active.
///
/// ## Algorithm (from architecture doc §7)
/// 1. Every time the app foregrounds, call `appDidBecomeActive(settings:)`.
///    The method always writes `lastActiveTimestamp = Date()` to the App Group
///    `UserDefaults` so the detector has a reliable signal of phone activity.
/// 2. On the same call, it checks whether the elapsed idle gap exceeds
///    `AppSettings.wakeUpIdleHours`.
/// 3. If yes **and** the current time is inside the configured wake-up window
///    (e.g. 05:00–11:00), `wakeUpDetectedAt` is set to `Date()` and persisted.
/// 4. `BlockingService` calls `isAfterWakeUpActive(durationMinutes:)` to decide
///    whether an `.afterWakeUp` rule condition is currently enforcing a block.
///
/// ## Edge case: middle-of-night phone use
/// The architecture doc notes that any phone use between, say, 01:00 and 05:00
/// will reset `lastActiveTimestamp`, potentially suppressing the next morning's
/// detection.  The time-of-day window guard (`wakeUpWindowStart/End`) mitigates
/// this: a wake-up is only recognised if it falls inside the window, so nocturnal
/// usage outside the window updates the timestamp without triggering a detection.
@MainActor
final class WakeUpDetector: ObservableObject {

    // MARK: - Storage

    private let defaults: UserDefaults = {
        guard let d = UserDefaults(suiteName: "group.com.debrajpal.frictiongate") else {
            fatalError("App Group 'group.com.debrajpal.frictiongate' is not configured.")
        }
        return d
    }()

    private enum Keys {
        static let lastActive   = "wake_last_active_timestamp"
        static let detectedAt   = "wake_detected_at"
    }

    // MARK: - Published state

    /// When the most recent wake-up event was detected.
    /// `nil` if no wake-up has been recorded yet.
    @Published private(set) var wakeUpDetectedAt: Date?

    // MARK: - Init

    init() {
        let stored = defaults.double(forKey: Keys.detectedAt)
        if stored > 0 {
            wakeUpDetectedAt = Date(timeIntervalSince1970: stored)
        }
    }

    // MARK: - Foreground callback

    /// Must be called every time `scenePhase` changes to `.active` in
    /// `FrictionGateApp`.
    ///
    /// Always writes the current timestamp to `lastActiveTimestamp`, then
    /// evaluates whether this foreground event qualifies as a wake-up.
    func appDidBecomeActive(settings: AppSettings) {
        let now = Date()

        // Always update the activity timestamp, even if detection is disabled,
        // so the idle gap stays accurate once detection is re-enabled.
        defer { defaults.set(now.timeIntervalSince1970, forKey: Keys.lastActive) }

        guard settings.wakeUpDetectionEnabled else { return }

        let lastActive  = storedLastActive()
        let idleSeconds = now.timeIntervalSince(lastActive)
        let threshold   = Double(settings.wakeUpIdleHours) * 3_600

        guard idleSeconds > threshold else { return }
        guard isWithinWakeUpWindow(settings: settings, at: now) else { return }

        // Qualifies as a wake-up event.
        wakeUpDetectedAt = now
        defaults.set(now.timeIntervalSince1970, forKey: Keys.detectedAt)
    }

    // MARK: - Condition check

    /// Returns `true` if the device woke up recently and the post-wake block
    /// window of `durationMinutes` has not yet expired.
    ///
    /// Called by `BlockingService.isConditionActive(_:wakeUpDetector:)`.
    func isAfterWakeUpActive(durationMinutes: Int) -> Bool {
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
