import SwiftUI

/// Root view of the application.
///
/// Responsibilities:
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
            // Shield-unlock cover: presented when the extension or a deep link
            // triggers an unlock request.  Cleared when the cover is dismissed
            // or when UnlockViewModel.completeAllChallenges() succeeds.
            .fullScreenCover(item: $appState.pendingUnlockRule) { rule in
                UnlockView(rule: rule, ruleStore: ruleStore)
            }
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
