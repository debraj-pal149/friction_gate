import Foundation
import Combine

/// Polls `HealthKitService` on a 10-second timer and publishes live step counts
/// for use by the unlock screen and condition evaluation.
///
/// ## Usage — step challenge (unlock screen)
/// ```swift
/// // When the unlock screen appears, start counting from when the block fired:
/// monitor.startMonitoring(from: attempt.blockAppliedAt ?? Date())
///
/// // Bind to stepsFromTrackingStart in the view.
///
/// // On dismiss (challenge passed or cancelled):
/// monitor.stopMonitoring()
/// ```
///
/// ## Usage — daily step goal check
/// `stepsSinceMidnight` is always refreshed alongside `stepsFromTrackingStart`,
/// so ViewModels can compare it against a threshold without a separate query.
@MainActor
final class StepMonitor: ObservableObject {

    // MARK: - Published counts

    /// Steps accumulated since `trackingStartDate`.
    /// Used to drive the step-challenge progress bar on the unlock screen.
    @Published private(set) var stepsFromTrackingStart: Int = 0

    /// Steps taken since midnight today.
    /// Used to evaluate daily step-goal block conditions.
    @Published private(set) var stepsSinceMidnight: Int = 0

    // MARK: - Dependencies

    private let healthKit: HealthKitService
    private var trackingStartDate: Date?
    private var timerCancellable: AnyCancellable?

    // MARK: - Init

    init(healthKit: HealthKitService = .shared) {
        self.healthKit = healthKit
    }

    // MARK: - Monitoring control

    /// Starts the 10-second polling timer.
    ///
    /// - Parameter date: Reference start date for the step challenge count
    ///   (typically `UnlockAttempt.blockAppliedAt`).
    func startMonitoring(from date: Date) {
        trackingStartDate = date
        refresh()
        timerCancellable = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    /// Stops polling and resets all published counts to zero.
    func stopMonitoring() {
        timerCancellable?.cancel()
        timerCancellable    = nil
        trackingStartDate   = nil
        stepsFromTrackingStart = 0
        stepsSinceMidnight     = 0
    }

    /// Triggers an immediate out-of-band refresh.
    ///
    /// Use when the user taps "Check now" on the step-challenge screen so they
    /// get instant feedback without waiting for the next 10-second tick.
    func refreshNow() {
        refresh()
    }

    // MARK: - Private

    private func refresh() {
        Task { [weak self] in
            guard let self else { return }

            // Run both HealthKit queries concurrently.
            if let date = trackingStartDate {
                async let fromStart = healthKit.stepsSince(date)
                async let midnight  = healthKit.stepsSinceMidnight()
                let (s, m) = await (fromStart, midnight)
                stepsFromTrackingStart = s
                stepsSinceMidnight     = m
            } else {
                stepsFromTrackingStart = 0
                stepsSinceMidnight     = await healthKit.stepsSinceMidnight()
            }
        }
    }
}
