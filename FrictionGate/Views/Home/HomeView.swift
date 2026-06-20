import SwiftUI

// MARK: - Sheet routing

/// All sheets that `HomeView` can present.
private enum HomeSheet: Identifiable {
    case builder
    case unlock(Rule)
    case settings
    case pause(Rule)            // pause sheet driven by HomeViewModel

    var id: String {
        switch self {
        case .builder:            return "builder"
        case .unlock(let rule):   return "unlock-\(rule.id)"
        case .settings:           return "settings"
        case .pause(let rule):    return "pause-\(rule.id)"
        }
    }
}

// MARK: - HomeView

struct HomeView: View {

    @ObservedObject var vm: HomeViewModel
    let ruleStore: RuleStore

    /// Shared WakeUpViewModel injected by FrictionGateApp — used for GlobalSettingsView.
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
            .navigationTitle("FrictionGate")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .builder } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { activeSheet = .settings } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            // Single consolidated sheet — safe on iOS 16.0+
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
            }
        }
        .onAppear { vm.refreshRules() }
        // Mirror HomeViewModel's pause request into our sheet state.
        // Observe the ID (UUID?) rather than Rule? — UUID is Equatable, Rule is not.
        .onChange(of: vm.pendingPauseRule?.id) { ruleID in
            if ruleID != nil, let rule = vm.pendingPauseRule {
                activeSheet = .pause(rule)
            } else {
                if case .pause = activeSheet { activeSheet = nil }
            }
        }
    }

    // MARK: - Sheet content

    @ViewBuilder
    private func sheetContent(for sheet: HomeSheet) -> some View {
        switch sheet {
        case .builder:
            RuleBuilderView(ruleStore: ruleStore)

        case .unlock(let rule):
            UnlockView(rule: rule, ruleStore: ruleStore)

        case .settings:
            GlobalSettingsView(vm: wakeUpVM)

        case .pause(let rule):
            PauseRuleView(
                rule: rule,
                confirmationText: vm.pauseConfirmationText,
                onConfirm: { duration in
                    vm.confirmPause(for: rule, duration: duration)
                    activeSheet = nil
                },
                onCancel: {
                    vm.cancelPause()
                    activeSheet = nil
                }
            )
            .onDisappear {
                // Fired on swipe-to-dismiss as well — ensures ViewModel is cleaned up.
                vm.cancelPause()
            }
        }
    }

    // MARK: - Rule list

    private var ruleList: some View {
        List {
            ForEach(vm.rules) { rule in
                RuleRowView(
                    rule: rule,
                    onToggleActive: { vm.toggleActive(rule) },
                    onPause: {
                        vm.startPause(for: rule)
                        // activeSheet will be set by the onChange above
                    },
                    onUnlock: { activeSheet = .unlock(rule) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        vm.deleteRule(rule)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        vm.startPause(for: rule)
                    } label: {
                        Label("Pause", systemImage: "pause.circle")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
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
