import SwiftUI
import FamilyControls

// MARK: - AppState

/// App-level navigation state shared between `FrictionGateApp` and `ContentView`.
///
/// `pendingUnlockRule` is set from two sources:
///  1. The `frictiongate://unlock?ruleID=xyz` URL scheme (deep link).
///  2. The `pending_unlock_rule_id` key written to the App Group `UserDefaults`
///     by the `ShieldActionExtension` when the user taps "Request Unlock" on the
///     shield overlay.
///
/// `ContentView` observes this and presents `UnlockView` via `.fullScreenCover`.
/// `UnlockViewModel.completeAllChallenges()` clears the UserDefaults key once the
/// user finishes the challenge; the binding is cleared when the cover is dismissed.
@MainActor
final class AppState: ObservableObject {
    @Published var pendingUnlockRule: Rule? = nil

    /// Current Family Controls authorization status.
    /// Updated on every app foreground so UI can react without a restart.
    @Published var familyControlsStatus: AuthorizationStatus = .notDetermined

    /// Human-readable description of the last `requestAuthorization` error,
    /// if any.  Nil when authorization succeeded or has not been attempted.
    @Published var familyControlsError: String? = nil

    /// Whether the pre-permission primer has been shown to the user.
    /// Persisted so the primer is never shown more than once.
    @Published var hasShownPermissionPrimer: Bool = {
        UserDefaults.standard.bool(forKey: "friction_permission_primer_shown")
    }()

    func markPrimerShown() {
        hasShownPermissionPrimer = true
        UserDefaults.standard.set(true, forKey: "friction_permission_primer_shown")
    }
}

// MARK: - FrictionGateApp

@main
struct FrictionGateApp: App {

    // MARK: - Shared services (single instance for full app lifetime)

    @StateObject private var ruleStore:      RuleStore
    @StateObject private var wakeUpDetector: WakeUpDetector
    @StateObject private var homeVM:         HomeViewModel
    @StateObject private var wakeUpVM:       WakeUpViewModel
    @StateObject private var appState:       AppState

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Init

    init() {
        let store    = RuleStore()
        let detector = WakeUpDetector()
        let state    = AppState()

        _ruleStore      = StateObject(wrappedValue: store)
        _wakeUpDetector = StateObject(wrappedValue: detector)
        _appState       = StateObject(wrappedValue: state)
        _homeVM         = StateObject(wrappedValue: HomeViewModel(ruleStore: store))
        _wakeUpVM       = StateObject(wrappedValue: WakeUpViewModel(
            wakeUpDetector: detector,
            ruleStore: store
        ))
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(ruleStore)
                .environmentObject(homeVM)
                .environmentObject(wakeUpVM)
                // HealthKit auth runs once on first render.
                // FamilyControls auth is handled by PermissionPrimerView on first launch;
                // subsequent launches just read the current status.
                .task { await requestHealthKitAuthorization() }
                .onOpenURL { handleURL($0) }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            wakeUpVM.appDidBecomeActive()
            checkPendingUnlockFromExtension()
            refreshFamilyControlsStatus()
            reapplyShieldsForExpiredSessions()
        }
    }

    // MARK: - URL deep link

    private func handleURL(_ url: URL) {
        guard
            url.scheme == "frictiongate",
            url.host   == "unlock",
            let comps    = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let idString = comps.queryItems?.first(where: { $0.name == "ruleID" })?.value,
            let ruleID   = UUID(uuidString: idString),
            let rule     = ruleStore.rules.first(where: { $0.id == ruleID })
        else { return }

        appState.pendingUnlockRule = rule
    }

    // MARK: - Shield extension handoff

    private func checkPendingUnlockFromExtension() {
        guard appState.pendingUnlockRule == nil else { return }

        guard
            let defaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate"),
            let idString = defaults.string(forKey: "pending_unlock_rule_id"),
            let ruleID   = UUID(uuidString: idString),
            let rule     = ruleStore.rules.first(where: { $0.id == ruleID })
        else { return }

        appState.pendingUnlockRule = rule
    }

    // MARK: - Session expiry re-evaluation

    /// For each active rule, checks whether the user's unlock session has expired.
    /// If it has, re-applies the shield so the next open of the blocked app shows
    /// the unlock challenge again.
    ///
    /// Called every time the app foregrounds — this is the primary mechanism for
    /// Option C (configurable session duration) re-blocking.
    private func reapplyShieldsForExpiredSessions() {
        guard let defaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate")
        else { return }

        let now = Date()

        for rule in ruleStore.rules where rule.isEnforcing {
            let key = "session_expires_\(rule.id.uuidString)"
            let expiryTS = defaults.double(forKey: key)

            // No session key → no active session → evaluate normally.
            // Session expired → clear the key and re-apply shield if condition active.
            if expiryTS > 0 {
                if now.timeIntervalSince1970 > expiryTS {
                    defaults.removeObject(forKey: key)
                    BlockingService.shared.evaluateAndApplyShield(
                        for: rule, wakeUpDetector: wakeUpDetector
                    )
                }
                // If session is still active, do nothing — user still has access.
            } else {
                // No active session — ensure shield is in sync with condition.
                BlockingService.shared.evaluateAndApplyShield(
                    for: rule, wakeUpDetector: wakeUpDetector
                )
            }
        }
    }

    // MARK: - Authorizations

    /// Requests HealthKit permission.
    ///
    /// FamilyControls authorization is handled by `PermissionPrimerView` on first
    /// launch so the user sees a clear explanation before the system dialog appears.
    /// After the primer runs once, `refreshFamilyControlsStatus()` keeps the status
    /// current on every foreground.
    private func requestHealthKitAuthorization() async {
        try? await HealthKitService.shared.requestAuthorization()
    }

    /// Syncs `appState.familyControlsStatus` with the live system value.
    private func refreshFamilyControlsStatus() {
        appState.familyControlsStatus = AuthorizationCenter.shared.authorizationStatus
    }
}
