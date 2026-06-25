import Foundation
import Combine
import CoreMotion

/// Publishes step counts for unlock and condition evaluation.
///
/// ## Usage — step challenge (unlock screen)
/// ```swift
/// // Start live tracking when the steps challenge appears:
/// monitor.startLiveStepTracking(from: attempt.blockAppliedAt ?? Date())
///
/// // Bind to stepsFromTrackingStart in the view.
///
/// // On dismiss (challenge passed or cancelled):
/// monitor.stopLiveStepTracking()
/// ```
///
/// ## Usage — daily step goal check
/// `stepsSinceMidnight` is refreshed on a 10-second HealthKit polling timer.
/// This is historical/summary data where some latency is acceptable.
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
    private let pedometer = CMPedometer()
    private var trackingStartDate: Date?
    private var timerCancellable: AnyCancellable?
    private var usingHealthKitFallbackForLive = false
    private var hasRequestedHealthKitAuthorization = false

    // MARK: - Init

    init(healthKit: HealthKitService = .shared) {
        self.healthKit = healthKit
    }

    // MARK: - Monitoring control (live challenge tracking)

    /// Starts live step tracking from `date` for the unlock challenge.
    ///
    /// Preferred path uses Core Motion's push-based `CMPedometer.startUpdates`
    /// for near-real-time foreground updates. If unavailable, it falls back to
    /// HealthKit polling (degraded behavior).
    func startLiveStepTracking(from date: Date) {
        trackingStartDate = date
        stepsFromTrackingStart = 0
        requestHealthKitAuthorizationIfNeeded()
        startMidnightPolling()

        if CMPedometer.isStepCountingAvailable() {
            usingHealthKitFallbackForLive = false
            pedometer.startUpdates(from: date) { [weak self] data, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.trackingStartDate != nil else { return }

                    if let steps = data?.numberOfSteps.intValue {
                        self.stepsFromTrackingStart = steps
                        return
                    }

                    // If the live stream errors, degrade gracefully to HealthKit polling.
                    if error != nil {
                        self.usingHealthKitFallbackForLive = true
                        self.refreshLiveStepsFromHealthKit()
                    }
                }
            }
        } else {
            usingHealthKitFallbackForLive = true
            refreshLiveStepsFromHealthKit()
        }
    }

    /// Stops live tracking and polling, then clears published counters.
    func stopLiveStepTracking() {
        pedometer.stopUpdates()
        usingHealthKitFallbackForLive = false
        stopMidnightPolling()
        trackingStartDate = nil
        stepsFromTrackingStart = 0
        stepsSinceMidnight = 0
    }

    /// Triggers an immediate out-of-band refresh.
    ///
    /// - `stepsSinceMidnight` is always refreshed from HealthKit.
    /// - `stepsFromTrackingStart` is refreshed only on fallback path; otherwise
    ///   CMPedometer continues feeding live updates.
    func refreshNow() {
        requestHealthKitAuthorizationIfNeeded()
        refreshMidnightSteps()
        if usingHealthKitFallbackForLive {
            refreshLiveStepsFromHealthKit()
        }
    }

    // MARK: - Private (midnight polling)

    private func startMidnightPolling() {
        refreshMidnightSteps()
        timerCancellable = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshMidnightSteps()
                if self?.usingHealthKitFallbackForLive == true {
                    self?.refreshLiveStepsFromHealthKit()
                }
            }
    }

    private func stopMidnightPolling() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func refreshMidnightSteps() {
        Task { [weak self] in
            guard let self else { return }
            self.stepsSinceMidnight = await self.healthKit.stepsSinceMidnight()
        }
    }

    private func requestHealthKitAuthorizationIfNeeded() {
        guard !hasRequestedHealthKitAuthorization else { return }
        hasRequestedHealthKitAuthorization = true
        Task { [weak self] in
            guard let self else { return }
            try? await self.healthKit.requestAuthorization()
            await MainActor.run {
                self.refreshNow()
            }
        }
    }

    // MARK: - Private (fallback live tracking)

    private func refreshLiveStepsFromHealthKit() {
        Task { [weak self] in
            guard let self else { return }
            guard let date = self.trackingStartDate else { return }
            self.stepsFromTrackingStart = await self.healthKit.stepsSince(date)
        }
    }
}
