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
        // Create concrete instances first so every object shares the SAME store.
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
                // Request FamilyControls + HealthKit on first foreground.
                .task { await requestAuthorizations() }
                // Handle frictiongate://unlock?ruleID=… deep links.
                .onOpenURL { handleURL($0) }
        }
        // Wake-up detection + extension handoff on every foreground.
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            wakeUpVM.appDidBecomeActive()
            checkPendingUnlockFromExtension()
        }
    }

    // MARK: - URL deep link

    /// Parses `frictiongate://unlock?ruleID=<UUID>` and sets the pending unlock rule.
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

    /// Checks whether the `ShieldActionExtension` wrote a `pending_unlock_rule_id`
    /// into the shared App Group `UserDefaults` while the main app was suspended.
    ///
    /// This is the primary mechanism for surfacing the unlock screen — the extension
    /// cannot open URLs directly, so it signals through shared storage instead.
    private func checkPendingUnlockFromExtension() {
        guard appState.pendingUnlockRule == nil else { return }

        guard
            let defaults = UserDefaults(suiteName: "group.com.debrajpal.frictiongate"),
            let idString = defaults.string(forKey: "pending_unlock_rule_id"),
            let ruleID   = UUID(uuidString: idString),
            let rule     = ruleStore.rules.first(where: { $0.id == ruleID })
        else { return }

        appState.pendingUnlockRule = rule
        // The key is cleared by UnlockViewModel.completeAllChallenges() after success,
        // or left in place so the unlock screen re-appears if the user cancels.
    }

    // MARK: - Authorizations

    /// Requests FamilyControls and HealthKit permissions.
    ///
    /// Both frameworks show their system dialogs only on the first call; subsequent
    /// calls are silent no-ops.  The `.task` modifier ensures this runs once on the
    /// first render of ContentView.
    private func requestAuthorizations() async {
        // FamilyControls — required before FamilyActivityPicker or ManagedSettings work.
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // If denied or not yet approved via developer.apple.com, the app still
            // launches; rules just won't block anything until approval is granted.
        }

        // HealthKit — required for step-count unlock challenges.
        try? await HealthKitService.shared.requestAuthorization()
    }
}
