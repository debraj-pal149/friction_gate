import SwiftUI

/// Root view of the application.
///
/// Responsibilities:
/// - Shows `PermissionPrimerView` on first launch (before Family Controls dialog).
/// - Renders `HomeView` backed by the shared `HomeViewModel` from the environment.
/// - Presents `UnlockView` as a `.fullScreenCover` when `AppState.pendingUnlockRule`
///   is set — either from the `frictiongate://unlock` URL scheme or from the
///   `ShieldActionExtension` via the App Group `UserDefaults` handoff.
struct ContentView: View {

    @EnvironmentObject private var appState:  AppState
    @EnvironmentObject private var ruleStore: RuleStore
    @EnvironmentObject private var homeVM:    HomeViewModel

    var body: some View {
        HomeView(vm: homeVM, ruleStore: ruleStore)
            .fullScreenCover(item: $appState.pendingUnlockRule) { rule in
                UnlockView(rule: rule, ruleStore: ruleStore)
                    // Keep the home-screen toggles in sync after a shield-initiated unlock.
                    .onDisappear { homeVM.refreshShieldStates() }
            }
            // Show the permission primer exactly once, before the system dialog.
            .fullScreenCover(isPresented: shouldShowPrimer) {
                PermissionPrimerView()
            }
    }

    /// Show the primer when it hasn't been shown yet AND permission hasn't been
    /// granted yet.  If the user already approved (e.g. on a reinstall where
    /// UserDefaults was cleared but the system already granted), skip the primer.
    private var shouldShowPrimer: Binding<Bool> {
        Binding(
            get: {
                !appState.hasShownPermissionPrimer &&
                appState.familyControlsStatus != .approved
            },
            set: { _ in }   // dismiss is handled by PermissionPrimerView itself
        )
    }
}

#Preview {
    let store    = RuleStore()
    let detector = WakeUpDetector()
    return ContentView()
        .environmentObject(AppState())
        .environmentObject(store)
        .environmentObject(HomeViewModel(ruleStore: store))
        .environmentObject(WakeUpViewModel(wakeUpDetector: detector, ruleStore: store))
}
