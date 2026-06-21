import SwiftUI

// MARK: - Sheet routing

private enum HomeSheet: Identifiable {
    case builder
    case settings
    case options(Rule)
    case about

    var id: String {
        switch self {
        case .builder:           return "builder"
        case .settings:          return "settings"
        case .options(let rule): return "options-\(rule.id)"
        case .about:             return "about"
        }
    }
}

// MARK: - HomeView

struct HomeView: View {

    @ObservedObject var vm: HomeViewModel
    let ruleStore: RuleStore

    @EnvironmentObject private var wakeUpVM: WakeUpViewModel

    @State private var activeSheet: HomeSheet? = nil

    var body: some View {
        NavigationStack {
            Group {
                if vm.rules.isEmpty {
                    emptyState
                } else {
                    ruleList
                }
            }
            .navigationTitle("My Rules")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .builder } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { activeSheet = .settings } label: {
                        Image(systemName: "gearshape")
                    }
                    Button { activeSheet = .about } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
            }
            .sheet(item: $vm.pendingUnlockFromToggle) { rule in
                UnlockView(rule: rule, ruleStore: ruleStore)
                    .onDisappear { vm.didDismissUnlock() }
            }
            .alert(
                "Lock \(vm.pendingRelockRule?.appDisplayName ?? "app") now?",
                isPresented: Binding(
                    get: { vm.pendingRelockRule != nil },
                    set: { if !$0 { vm.cancelRelock() } }
                )
            ) {
                Button("Lock it now", role: .destructive) { vm.confirmRelock() }
                Button("Keep it unlocked", role: .cancel) { vm.cancelRelock() }
            } message: {
                Text(vm.relockMessage)
            }
        }
        .onAppear {
            vm.refreshRules()
            vm.refreshShieldStates()
            // Slightly reduce the large title font from the default 34pt.
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.largeTitleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold)
            ]
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().standardAppearance  = appearance
        }
    }

    // MARK: - Sheet content

    @ViewBuilder
    private func sheetContent(for sheet: HomeSheet) -> some View {
        switch sheet {
        case .builder:
            RuleBuilderView(ruleStore: ruleStore)

        case .settings:
            GlobalSettingsView(vm: wakeUpVM)

        case .options(let rule):
            RuleOptionsView(rule: rule) {
                vm.deleteRule(rule)
            }

        case .about:
            AboutFrictionView()
        }
    }

    // MARK: - Rule list

    private var ruleList: some View {
        List {
            ForEach(vm.rules) { rule in
                RuleRowView(
                    rule: rule,
                    isShielded: vm.shieldedRuleIDs.contains(rule.id),
                    onToggleTap: { vm.handleToggleTap(for: rule) },
                    onOptions: { activeSheet = .options(rule) }
                )
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 6) }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            Text("No Rules Yet")
                .font(.title2.bold())
            Text("Tap + to add your first blocking rule.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Rule") { activeSheet = .builder }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - AboutFrictionView

private struct AboutFrictionView: View {

    @Environment(\.dismiss) private var dismiss

    private struct Feature {
        let icon: String
        let color: Color
        let title: String
        let body: String
    }

    private let features: [Feature] = [
        Feature(icon: "lock.shield.fill",     color: .blue,
                title: "You choose what's blocked",
                body:  "Pick any app and set the times or conditions when it's off-limits."),
        Feature(icon: "brain.head.profile",   color: .purple,
                title: "Earn access, don't just tap past",
                body:  "Every unlock requires a challenge: maths, steps, a wait, or a written reason."),
        Feature(icon: "timer",                color: .orange,
                title: "Sessions keep it honest",
                body:  "After unlocking, the app re-locks automatically, even while you're in it."),
        Feature(icon: "arrow.up.right.circle.fill", color: .red,
                title: "Escalation raises the stakes",
                body:  "Unlock too many times in a row and each challenge gets harder."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    header
                    featuresBlock
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .navigationTitle("About Friction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
            Text("Friction")
                .font(.largeTitle.bold())
            Text("Make phone use intentional, not automatic.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var featuresBlock: some View {
        VStack(spacing: 16) {
            ForEach(features, id: \.title) { f in
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: f.icon)
                        .font(.title2)
                        .foregroundColor(f.color)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(f.title)
                            .font(.subheadline.bold())
                        Text(f.body)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var footer: some View {
        Text("Everything stays on your device. No accounts, no tracking.")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.bottom, 8)
    }
}
