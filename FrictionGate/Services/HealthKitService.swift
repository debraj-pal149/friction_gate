import Foundation
import HealthKit

/// Wraps all HealthKit step-count interactions for FrictionGate.
///
/// Authorization is requested once on first launch. All query methods return `0`
/// silently when HealthKit is unavailable (simulator) or the user has denied
/// access — callers do not need to guard for availability.
///
/// Important: HealthKit and HealthKit Background Delivery entitlements must be
/// enabled in Signing & Capabilities, and the following keys must be present in
/// Info.plist:
///   - NSHealthShareUsageDescription
///   - NSHealthUpdateUsageDescription
final class HealthKitService {

    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    // MARK: - Availability

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// Requests read-only access to step count data.
    ///
    /// HealthKit shows the permission sheet only on the first call; subsequent
    /// calls are no-ops when permission has already been granted or denied.
    func requestAuthorization() async throws {
        guard isHealthDataAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: [stepType])
    }

    // MARK: - Step queries

    /// Total steps from `date` until now.
    ///
    /// Uses `HKStatisticsQuery` with `.cumulativeSum`.
    /// Returns `0` on any error.
    func stepsSince(_ date: Date) async -> Int {
        guard isHealthDataAvailable else { return 0 }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: date,
                end: Date(),
                options: .strictStartDate
            )
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            store.execute(query)
        }
    }

    /// Steps since midnight today.
    ///
    /// Used to evaluate the daily step-goal block condition and to display
    /// a motivational progress indicator on the unlock screen.
    func stepsSinceMidnight() async -> Int {
        let midnight = Calendar.current.startOfDay(for: Date())
        return await stepsSince(midnight)
    }
}
