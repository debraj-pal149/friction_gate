import SwiftUI
import FamilyControls
import UserNotifications

// MARK: - AppState

/// App-level navigation state shared between `FrictionGateApp` and `ContentView`.
@MainActor
final class AppState: ObservableObject {
    private enum ThemeKey {
        static let colorSchemeOverride = "friction_color_scheme_override"
    }

    @Published var pendingUnlockRule: Rule? = nil
    @Published var familyControlsStatus: AuthorizationStatus = .notDetermined
    @Published var familyControlsError: String? = nil
    @Published var hasShownPermissionPrimer: Bool = {
        UserDefaults.standard.bool(forKey: "friction_permission_primer_shown")
    }()

    /// Persisted in UserDefaults.standard so it survives app updates and reinstalls
    /// that preserve the data container (i.e. device upgrades, TestFlight updates).
    /// Only a full device wipe / app deletion resets this.
    @Published var hasShownOnboarding: Bool = {
        UserDefaults.standard.bool(forKey: "friction_onboarding_shown")
    }()
    /// Selected saved theme config. Nil means transient working palette.
    @Published var selectedColorTemplate: Int? = ColorTemplates.selectedTemplateID
    /// Nil = follow system. Non-nil overrides app-wide color scheme.
    @Published var colorSchemeOverride: ColorScheme? = {
        switch UserDefaults.standard.string(forKey: ThemeKey.colorSchemeOverride) {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }()

    func markPrimerShown() {
        hasShownPermissionPrimer = true
        UserDefaults.standard.set(true, forKey: "friction_permission_primer_shown")
    }

    func markOnboardingShown() {
        hasShownOnboarding = true
        UserDefaults.standard.set(true, forKey: "friction_onboarding_shown")
    }

    func toggleColorScheme(using currentSystemScheme: ColorScheme) {
        let next: ColorScheme
        switch colorSchemeOverride {
        case .light:
            next = .dark
        case .dark:
            next = .light
        case nil:
            next = currentSystemScheme == .dark ? .light : .dark
        }
        setColorSchemeOverride(next)
    }

    func cycleSavedColorTemplate() {
        let ids = ColorTemplates.savedTemplateIDs
        guard !ids.isEmpty else { return }
        let current = selectedColorTemplate ?? ids[0]
        let idx = ids.firstIndex(of: current) ?? 0
        let next = ids[(idx + 1) % ids.count]
        selectedColorTemplate = next
        ColorTemplates.selectedTemplateID = next
    }

    private func setColorSchemeOverride(_ scheme: ColorScheme?) {
        colorSchemeOverride = scheme
        let stored: String?
        switch scheme {
        case .light: stored = "light"
        case .dark:  stored = "dark"
        case nil:    stored = nil
        @unknown default: stored = nil
        }
        UserDefaults.standard.set(stored, forKey: ThemeKey.colorSchemeOverride)
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
        Self.startupLog("App init start")
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

        UNUserNotificationCenter.current().delegate = notificationDelegate
        FrictionGateApp.configureGlobalAppearance()
        Self.startupLog("App init end")
    }

    // MARK: - Global UIKit appearance
    //
    // Called once at launch. Styles all NavigationBars and List backgrounds
    // consistently across every screen without per-view boilerplate.

    private static func configureGlobalAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = AppColors.uiNavBackground
        nav.shadowColor     = AppColors.uiNavShadow
        nav.largeTitleTextAttributes = [
            .foregroundColor: AppColors.uiTextPrimary,
            .font: UIFont.systemFont(ofSize: 26, weight: .bold)
        ]
        nav.titleTextAttributes = [
            .foregroundColor: AppColors.uiTextPrimary,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance    = nav
        UINavigationBar.appearance().scrollEdgeAppearance  = nav
        UINavigationBar.appearance().compactAppearance     = nav
        UINavigationBar.appearance().tintColor             = AppColors.uiPrimaryAccent

        UITableView.appearance().backgroundColor = AppColors.uiBackground
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
                    Self.startupLog("Startup task begin")
                    await requestNotificationPermission()
                    Self.startupLog("Notification request completed")
                    wireNotificationDelegate()
                    Self.startupLog("Notification delegate wired")
                    Self.startupLog("Startup task end")
                }
                .onOpenURL { handleURL($0) }
                .onChange(of: appState.selectedColorTemplate) { _ in
                    FrictionGateApp.configureGlobalAppearance()
                }
                .onChange(of: appState.colorSchemeOverride) { _ in
                    FrictionGateApp.configureGlobalAppearance()
                }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Self.startupLog("scenePhase active begin")
            wakeUpVM.appDidBecomeActive()
            checkPendingUnlockFromExtension()
            refreshFamilyControlsStatus()
            reapplyShieldsForExpiredSessions()
            homeVM.refreshShieldStates()
            Self.startupLog("scenePhase active end")
        }
    }

    // MARK: - Notification setup

    private func requestNotificationPermission() async {
        Self.startupLog("requestNotificationPermission start")
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
        Self.startupLog("requestNotificationPermission end")
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

    private func refreshFamilyControlsStatus() {
        appState.familyControlsStatus = AuthorizationCenter.shared.authorizationStatus
        Self.startupLog("familyControlsStatus = \(appState.familyControlsStatus)")
    }

    private static func startupLog(_ message: String) {
        print("[Startup \(Date().timeIntervalSince1970)] \(message)")
    }
}
