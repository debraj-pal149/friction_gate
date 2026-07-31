import Foundation
import HealthKit

/// PRIMARY after-wake signal: HealthKit sleep analysis end time via background delivery.
///
/// ## How this approximates wake
/// When Apple Watch / iPhone Sleep Tracking ends a sleep session, HealthKit
/// delivers samples. We take the latest `.asleep*` sample's `endDate` inside
/// today's configured wake window as `wake_detected_at`.
///
/// ## Limits (document honestly)
/// - Watch sync may delay the stamp 10–30 minutes after true wake.
/// - Without Watch or iPhone sleep tracking, this path never fires — DeviceActivity
///   first-use (`fg-wakevent-*`) and Friction foreground fallback take over.
/// - HKObserverQuery runs in the **main app process** woken by background delivery,
///   not in `FrictionGateMonitor`.
///
/// Separate from `WakeUpDetector` (foreground idle-gap fallback). Do not merge.
@MainActor
final class SleepWakeDetector {

    static let shared = SleepWakeDetector()

    private let store = HKHealthStore()
    private var wakeUpDetector: WakeUpDetector?
    private var observerQuery: HKObserverQuery?
    private var didStart = false

    private let defaults: UserDefaults = {
        guard let d = UserDefaults(suiteName: "group.com.debrajpal.frictiongate") else {
            fatalError("App Group 'group.com.debrajpal.frictiongate' is not configured.")
        }
        return d
    }()

    private init() {}

    // MARK: - Lifecycle

    /// Call once after app launch. Requests sleep read auth (idempotent) and
    /// registers background delivery + observer.
    func start(wakeUpDetector: WakeUpDetector) {
        self.wakeUpDetector = wakeUpDetector
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !didStart else { return }
        didStart = true

        Task {
            do {
                try await HealthKitService.shared.requestAuthorization()
            } catch {
                print("[SleepWakeDetector] authorization failed: \(error)")
            }
            registerObserver()
        }
    }

    // MARK: - Observer

    private func registerObserver() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return
        }

        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error {
                print("[SleepWakeDetector] observer error: \(error)")
                completionHandler()
                return
            }

            Task { @MainActor in
                await self?.handleSleepUpdate()
                completionHandler()
            }
        }

        observerQuery = query
        store.execute(query)

        store.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { success, error in
            if let error {
                print("[SleepWakeDetector] enableBackgroundDelivery failed: \(error)")
            } else if !success {
                print("[SleepWakeDetector] enableBackgroundDelivery returned false")
            }
        }
    }

    private func handleSleepUpdate() async {
        guard let wakeUpDetector else { return }
        wakeUpDetector.syncFromDefaults()
        guard !wakeUpDetector.isWakeDetectedToday else { return }

        guard let wakeCandidate = await latestSleepEndDate() else { return }

        let settings = loadAppSettings()
        // Sleep end must fall inside the configured morning wake window.
        guard isWithinWakeUpWindow(settings: settings, at: wakeCandidate) else { return }

        // Prefer stamping the sleep end (true-ish wake), not delivery time.
        guard wakeUpDetector.recordWakeDetection(at: wakeCandidate) else { return }
        wakeUpDetector.applyAfterWakeEffects(wakeDetectedAt: wakeCandidate)
    }

    // MARK: - Query

    private func latestSleepEndDate() async -> Date? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let start = Date().addingTimeInterval(-18 * 3600)
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: Date(),
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 40,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]

                let asleepSamples = (samples as? [HKCategorySample])?.filter {
                    asleepValues.contains($0.value)
                } ?? []

                // Most recent asleep segment end ≈ wake time.
                continuation.resume(returning: asleepSamples.first?.endDate)
            }
            store.execute(query)
        }
    }

    // MARK: - Helpers

    private func loadAppSettings() -> AppSettings {
        guard let data = defaults.data(forKey: "app_settings"),
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
}
