import Foundation
import HealthKit

/// Wraps HealthKit interactions for FrictionGate (steps + sleep).
///
/// Authorization is requested once; subsequent calls are no-ops when permission
/// has already been granted or denied. Query methods degrade silently when
/// HealthKit is unavailable (simulator) or access is denied.
///
/// Entitlements required:
///   - HealthKit
///   - HealthKit Background Delivery
/// Privacy string:
///   - NSHealthShareUsageDescription (steps + sleep)
final class HealthKitService {

    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)

    // MARK: - Availability

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// Requests read access to step count and sleep analysis.
    func requestAuthorization() async throws {
        guard isHealthDataAvailable else { return }
        var readTypes: Set<HKObjectType> = [stepType]
        if let sleepType {
            readTypes.insert(sleepType)
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
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
    func stepsSinceMidnight() async -> Int {
        let midnight = Calendar.current.startOfDay(for: Date())
        return await stepsSince(midnight)
    }
}
