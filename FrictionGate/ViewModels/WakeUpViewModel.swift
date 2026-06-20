import Foundation
import Combine

/// Exposes wake-up detection state and `AppSettings` to the UI.
///
/// ## Lifecycle
/// The app creates one `WakeUpDetector` and one `WakeUpViewModel` at startup and
/// keeps them alive for the session.  `FrictionGateApp` calls
/// `viewModel.appDidBecomeActive()` every time `scenePhase` changes to `.active`.
///
/// ## Settings
/// All `AppSettings` fields are exposed as settable properties that write through
/// to `RuleStore.appSettings` and persist immediately via `RuleStore.saveSettings()`.
@MainActor
final class WakeUpViewModel: ObservableObject {

    // MARK: - Dependencies

    /// The shared detector — also used directly by `BlockingService`.
    let wakeUpDetector: WakeUpDetector
    private let ruleStore: RuleStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published state

    /// When a wake-up was last detected.  Mirrors `wakeUpDetector.wakeUpDetectedAt`.
    @Published private(set) var wakeUpDetectedAt: Date?

    // MARK: - Init

    init(wakeUpDetector: WakeUpDetector, ruleStore: RuleStore) {
        self.wakeUpDetector = wakeUpDetector
        self.ruleStore      = ruleStore
        self.wakeUpDetectedAt = wakeUpDetector.wakeUpDetectedAt

        // Keep local state in sync whenever the detector updates.
        wakeUpDetector.$wakeUpDetectedAt
            .assign(to: &$wakeUpDetectedAt)
    }

    // MARK: - AppSettings proxies (two-way, persist on write)

    var detectionEnabled: Bool {
        get { ruleStore.appSettings.wakeUpDetectionEnabled }
        set {
            objectWillChange.send()
            ruleStore.appSettings.wakeUpDetectionEnabled = newValue
            ruleStore.saveSettings()
        }
    }

    var idleHours: Int {
        get { ruleStore.appSettings.wakeUpIdleHours }
        set {
            objectWillChange.send()
            ruleStore.appSettings.wakeUpIdleHours = newValue
            ruleStore.saveSettings()
        }
    }

    var windowStart: DateComponents {
        get { ruleStore.appSettings.wakeUpWindowStart }
        set {
            objectWillChange.send()
            ruleStore.appSettings.wakeUpWindowStart = newValue
            ruleStore.saveSettings()
        }
    }

    var windowEnd: DateComponents {
        get { ruleStore.appSettings.wakeUpWindowEnd }
        set {
            objectWillChange.send()
            ruleStore.appSettings.wakeUpWindowEnd = newValue
            ruleStore.saveSettings()
        }
    }

    var sleepTime: DateComponents? {
        get { ruleStore.appSettings.sleepTime }
        set {
            objectWillChange.send()
            ruleStore.appSettings.sleepTime = newValue
            ruleStore.saveSettings()
        }
    }

    // MARK: - Forwarded calls

    /// Forward to `WakeUpDetector` on every foreground.
    /// Call this from `FrictionGateApp` when `scenePhase == .active`.
    func appDidBecomeActive() {
        wakeUpDetector.appDidBecomeActive(settings: ruleStore.appSettings)
    }

    // MARK: - Query helpers for rules

    /// Whether the `afterWakeUp` condition in `rule` is currently blocking.
    func isAfterWakeUpActive(for rule: Rule) -> Bool {
        for condition in rule.conditions {
            if case .afterWakeUp(let mins) = condition {
                return wakeUpDetector.isAfterWakeUpActive(durationMinutes: mins)
            }
        }
        return false
    }

    /// Remaining minutes of the most prominent `afterWakeUp` block window, or `nil`.
    /// Returns `nil` when no wake-up has been detected or the window has expired.
    func remainingWakeUpMinutes(for rule: Rule) -> Int? {
        guard let detected = wakeUpDetectedAt else { return nil }
        for condition in rule.conditions {
            if case .afterWakeUp(let totalMins) = condition {
                let elapsedMins = Int(Date().timeIntervalSince(detected) / 60)
                let remaining   = totalMins - elapsedMins
                return remaining > 0 ? remaining : nil
            }
        }
        return nil
    }

    // MARK: - Display helpers

    /// Human-readable status string shown in the wake-up row in GlobalSettingsView.
    var statusDescription: String {
        guard detectionEnabled else { return "Wake-up detection is off." }
        guard let detected = wakeUpDetectedAt else {
            return "No wake-up detected yet today."
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Wake-up detected \(formatter.localizedString(for: detected, relativeTo: Date()))."
    }
}
