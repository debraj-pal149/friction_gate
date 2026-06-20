import Foundation

/// Global settings that apply across all rules.
///
/// Stored in `RuleStore` (UserDefaults, App Group) under the key `"app_settings"`.
struct AppSettings: Codable, Equatable {

    // MARK: - Wake-up detection

    /// Whether the wake-up detection feature is enabled at all.
    var wakeUpDetectionEnabled: Bool

    /// How many hours of phone inactivity count as a "sleep period".
    /// The `afterWakeUp` block condition triggers when the device wakes after
    /// this many idle hours.
    var wakeUpIdleHours: Int

    /// Start of the time window in which a wake-up event can be detected.
    /// Default: 05:00 (hour/minute only — date components are ignored).
    var wakeUpWindowStart: DateComponents

    /// End of the time window in which a wake-up event can be detected.
    /// Default: 11:00.
    var wakeUpWindowEnd: DateComponents

    // MARK: - Sleep target

    /// The user's self-reported target sleep time (hour/minute only).
    /// Used by the `beforeSleep` block condition.
    var sleepTime: DateComponents?

    // MARK: - Init

    init(
        wakeUpDetectionEnabled: Bool = true,
        wakeUpIdleHours: Int = 2,
        wakeUpWindowStart: DateComponents = DateComponents(calendar: .current, hour: 5, minute: 0),
        wakeUpWindowEnd: DateComponents = DateComponents(calendar: .current, hour: 11, minute: 0),
        sleepTime: DateComponents? = nil
    ) {
        self.wakeUpDetectionEnabled = wakeUpDetectionEnabled
        self.wakeUpIdleHours = wakeUpIdleHours
        self.wakeUpWindowStart = wakeUpWindowStart
        self.wakeUpWindowEnd = wakeUpWindowEnd
        self.sleepTime = sleepTime
    }

    // MARK: - Default instance

    static let `default` = AppSettings()
}
