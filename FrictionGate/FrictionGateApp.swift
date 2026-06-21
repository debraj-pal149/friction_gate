import SwiftUI
import FamilyControls
import UserNotifications

// MARK: - AppState

/// App-level navigation state shared between `FrictionGateApp` and `ContentView`.
@MainActor
final class AppState: ObservableObject {
    @Published var pendingUnlockRule: Rule? = nil
    @Published var familyControlsStatus: AuthorizationStatus = .notDetermined
    @Published var familyControlsError: String? = nil
    @Published var hasShownPermissionPrimer: Bool = {
        UserDefaults.standard.bool(forKey: "friction_permission_primer_shown")
    }()

    func markPrimerShown() {
        hasShownPermissionPrimer = true
        UserDefaults.standard.set(true, forKey: "friction_permission_primer_shown")
    }
}

// MARK: - NotificationDelegate

/// Handles local notification taps from the shield extension.
///
/// Two notification types:
///  - FRICTION_UNLOCK  (from ShieldActionExtension) → show unlock challenge
///  - FRICTION_RELOCK  (from DeviceActivityService)  → silently re-apply shield
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    var onUnlockRequest: ((String) -> Void)?
    var onRelockRequest: ((String) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info     = response.notification.request.content.userInfo
        let category = response.notification.request.content.categoryIdentifier
        if let ruleID = info["ruleID"] as? String {
            if category == "FRICTION_RELOCK" {
                onRelockRequest?(ruleID)
            } else {
                onUnlockRequest?(ruleID)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - FrictionGateApp

@main
struct FrictionGateApp: App {

    @StateObject private var ruleStore:      RuleStore
    @StateObject private var wakeUpDetector: WakeUpDetector
    @StateObject private var homeVM:         HomeViewModel
    @StateObject private var wakeUpVM:       WakeUpViewModel
    @StateObject private var appState:       AppState

    @Environment(\.scenePhase) private var scenePhase

    // Notification delegate must be kept alive for the app lifetime.
    private let notificationDelegate = NotificationDelegate()

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

        // Register as the notification delegate immediately so we receive
        // taps even if the app was launched cold by a notification.
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(ruleStore)
                .environmentObject(homeVM)
                .environmentObject(wakeUpVM)
                .task {
                    await requestHealthKitAuthorization()
                    await requestNotificationPermission()
                    wireNotificationDelegate()
                }
                .onOpenURL { handleURL($0) }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            wakeUpVM.appDidBecomeActive()
            checkPendingUnlockFromExtension()
            refreshFamilyControlsStatus()
            reapplyShieldsForExpiredSessions()
            homeVM.refreshShieldStates()
        }
    }

    // MARK: - Notification setup

    private func requestNotificationPermission() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])

        // Register both notification categories.
        let unlockCategory = UNNotificationCategory(
            identifier: "FRICTION_UNLOCK",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let relockCategory = UNNotificationCategory(
            identifier: "FRICTION_RELOCK",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current()
            .setNotificationCategories([unlockCategory, relockCategory])
    }

    private func wireNotificationDelegate() {
        // Unlock notification: user tapped "Switch to Friction" on the shield.
        notificationDelegate.onUnlockRequest = { [self] ruleID in
            guard
                let uuid = UUID(uuidString: ruleID),
                let rule = ruleStore.rules.first(where: { $0.id == uuid })
            else { return }
            appState.pendingUnlockRule = rule
        }

        // Relock notification: session expired, user wants to re-block now.
        notificationDelegate.onRelockRequest = { [self] ruleID in
            guard
                let uuid = UUID(uuidString: ruleID),
                let rule = ruleStore.rules.first(where: { $0.id == uuid })
            else { return }
            // Clear the session and apply the shield — no challenge needed
            // since the user is voluntarily re-locking.
            UserDefaults(suiteName: "group.com.debrajpal.frictiongate")?
                .removeObject(forKey: "session_expires_\(ruleID)")
            BlockingService.shared.applyShield(for: rule)
            homeVM.refreshShieldStates()
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

    // MARK: - Shield extension handoff (foreground poll)

    private func checkPendingUnlockFromExtension() {
        guard appState.pendingUnlockRule == nil else { return }
        guard let defaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate")
        else { return }

        // Always clear the keys immediately — even if we don't act on them.
        // This prevents the unlock screen from re-appearing on every subsequent
        // foreground if the user cancelled or the request was stale.
        defer {
            defaults.removeObject(forKey: "pending_unlock_rule_id")
            defaults.removeObject(forKey: "pending_unlock_timestamp")
        }

        guard
            let idString = defaults.string(forKey: "pending_unlock_rule_id"),
            let ruleID   = UUID(uuidString: idString),
            let rule     = ruleStore.rules.first(where: { $0.id == ruleID })
        else { return }

        // Ignore requests older than 2 minutes — the user tapped the shield
        // a long time ago and the context is no longer relevant.
        let timestamp = defaults.double(forKey: "pending_unlock_timestamp")
        if timestamp > 0 {
            let age = Date().timeIntervalSince1970 - timestamp
            guard age < 120 else { return }   // 2-minute freshness window
        }

        appState.pendingUnlockRule = rule
    }

    // MARK: - Session expiry re-evaluation

    private func reapplyShieldsForExpiredSessions() {
        guard let defaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate")
        else { return }

        let now = Date()

        for rule in ruleStore.rules where rule.isEnforcing {
            let key = "session_expires_\(rule.id.uuidString)"
            let expiryTS = defaults.double(forKey: key)

            if expiryTS > 0 {
                if now.timeIntervalSince1970 > expiryTS {
                    defaults.removeObject(forKey: key)
                    BlockingService.shared.evaluateAndApplyShield(
                        for: rule, wakeUpDetector: wakeUpDetector
                    )
                }
            } else {
                BlockingService.shared.evaluateAndApplyShield(
                    for: rule, wakeUpDetector: wakeUpDetector
                )
            }
        }
    }

    // MARK: - Authorizations

    private func requestHealthKitAuthorization() async {
        try? await HealthKitService.shared.requestAuthorization()
    }

    private func refreshFamilyControlsStatus() {
        appState.familyControlsStatus = AuthorizationCenter.shared.authorizationStatus
    }
}
