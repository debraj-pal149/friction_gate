import SwiftUI

// MARK: - Sheet routing

private enum HomeSheet: Identifiable {
    case builder
    case unlock(Rule)
    case settings
    case options(Rule)

    var id: String {
        switch self {
        case .builder:            return "builder"
        case .unlock(let rule):   return "unlock-\(rule.id)"
        case .settings:           return "settings"
        case .options(let rule):  return "options-\(rule.id)"
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
            .navigationTitle("Friction")
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
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
            }
        }
        .onAppear { vm.refreshRules() }
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

        case .options(let rule):
            RuleOptionsView(rule: rule) {
                vm.deleteRule(rule)
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
                    onOptions: { activeSheet = .options(rule) }
                )
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
