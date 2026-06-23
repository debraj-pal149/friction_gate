import SwiftUI

/// Root view of the application.
///
/// First-run flow (single fullScreenCover, sequenced by AppState flags):
///   1. OnboardingView  — shown once ever; "Let's Go" sets `hasShownOnboarding`
///   2. PermissionPrimerView — shown until Screen Time permission is granted
///   3. HomeView — normal app
///
/// The unlock cover sits on top of everything and is independent of the flow.
struct ContentView: View {

    @EnvironmentObject private var appState:  AppState
    @EnvironmentObject private var ruleStore: RuleStore
    @EnvironmentObject private var homeVM:    HomeViewModel

    var body: some View {
        HomeView(vm: homeVM, ruleStore: ruleStore)
            .fullScreenCover(item: $appState.pendingUnlockRule) { rule in
                UnlockView(rule: rule, ruleStore: ruleStore)
                    .onDisappear { homeVM.refreshShieldStates() }
            }
            // Single cover handles both onboarding and primer so they chain
            // reliably without stacking multiple fullScreenCovers.
            .fullScreenCover(isPresented: shouldShowFirstRunFlow) {
                if !appState.hasShownOnboarding {
                    OnboardingView()
                } else {
                    PermissionPrimerView()
                }
            }
            .preferredColorScheme(.light)
            .tint(Color.appAccent)
    }

    /// True when either the onboarding OR the permission primer still needs to be shown.
    /// The cover content switches between the two based on `hasShownOnboarding`.
    private var shouldShowFirstRunFlow: Binding<Bool> {
        Binding(
            get: {
                // Show onboarding if never seen.
                if !appState.hasShownOnboarding { return true }
                // After onboarding, show primer until permission is granted.
                return !appState.hasShownPermissionPrimer &&
                       appState.familyControlsStatus != .approved
            },
            set: { _ in }   // dismissal is controlled by the child views themselves
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
