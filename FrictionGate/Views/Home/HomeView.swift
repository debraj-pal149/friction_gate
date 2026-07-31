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
    @EnvironmentObject private var appState: AppState

    @State private var activeSheet: HomeSheet? = nil
    /// Set while options is open; unlock presents only after that sheet fully dismisses.
    @State private var unlockAfterOptions: Rule? = nil

    private var blockedCount: Int {
        vm.rules.filter { vm.shieldedRuleIDs.contains($0.id) }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeroHeader(blockedCount: blockedCount, totalCount: vm.rules.count)

                Rectangle()
                    .fill(AppColors.inkBorder)
                    .frame(height: 1)

                if vm.rules.isEmpty {
                    emptyState
                } else {
                    ruleList
                }

                HomeBottomBar(
                    totalRules: vm.rules.count,
                    blockedCount: blockedCount,
                    onAdd: { activeSheet = .builder }
                )
            }
            .background(AppColors.inkBase)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        toolbarCircleButton(systemName: "info.circle") {
                            activeSheet = .about
                        }
                        toolbarCircleButton(systemName: "gearshape") {
                            activeSheet = .settings
                        }
                    }
                }
            }
            .toolbarBackground(AppColors.inkBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(item: $activeSheet, onDismiss: {
                vm.refreshRules()
                vm.refreshShieldStates()
                if let rule = unlockAfterOptions {
                    unlockAfterOptions = nil
                    // Defer so this sheet's teardown finishes before unlock presents.
                    DispatchQueue.main.async {
                        vm.requestUnlock(for: rule)
                    }
                }
            }) { sheet in
                sheetContent(for: sheet)
            }
            // fullScreenCover avoids fighting the options `.sheet` (two sheets flash-dismiss).
            .fullScreenCover(item: $vm.pendingUnlockRule, onDismiss: {
                vm.didDismissUnlock()
            }) { rule in
                UnlockView(rule: rule, ruleStore: ruleStore)
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
        .preferredColorScheme(.dark)
        .onAppear {
            vm.refreshRules()
            vm.refreshShieldStates()
        }
    }

    // MARK: - Sheet content

    @ViewBuilder
    private func sheetContent(for sheet: HomeSheet) -> some View {
        switch sheet {
        case .builder:
            RuleBuilderView(ruleStore: ruleStore, wakeUpDetector: wakeUpVM.wakeUpDetector)

        case .settings:
            GlobalSettingsView(vm: wakeUpVM)

        case .options(let rule):
            RuleOptionsView(
                rule: rule,
                isCurrentlyBlocked: vm.shieldedRuleIDs.contains(rule.id),
                onUnblock: { unlockAfterOptions = rule },
                onDelete: { vm.deleteRule(rule) }
            )

        case .about:
            AboutFrictionView()
        }
    }

    private func toolbarCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textMuted)
                .frame(width: 32, height: 32)
                .background(AppColors.inkSurface)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.inkBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rule list

    private var ruleList: some View {
        List {
            ForEach(vm.rulesByDifficulty) { rule in
                RuleRowView(
                    rule: rule,
                    isShielded: vm.shieldedRuleIDs.contains(rule.id),
                    isRuleActive: rule.isEnforcing,
                    onToggleTap: {
                        // Unlock only when this app is actually shielded.
                        // Opening Unlock while unblocked granted a free session and
                        // blocked evaluateAndApplyShield for the whole session window.
                        guard vm.shieldedRuleIDs.contains(rule.id) else { return }
                        vm.requestUnlock(for: rule)
                    },
                    onOptions: { activeSheet = .options(rule) }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.inkBase)
        .modifier(HomeRuleListSpacing())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(AppColors.inkBorder)
            Text("no rules yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textMuted)
            Text("add a rule to start blocking apps intentionally")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .background(AppColors.inkBase)
    }
}

// MARK: - HeroHeader

private struct HeroHeader: View {
    let blockedCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "today")
                .padding(.bottom, 6)

            HStack(spacing: 0) {
                Text("fric")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(-1.5)
                Text("tion")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(AppColors.accentMint)
                    .tracking(-1.5)
            }

            Text(summaryText)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textMuted)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .background(AppColors.inkBase)
    }

    private var summaryText: String {
        if blockedCount == 0 { return "all clear · \(totalCount) rules active" }
        return "\(blockedCount) app\(blockedCount == 1 ? "" : "s") blocked · \(totalCount) rules active"
    }
}

// MARK: - HomeBottomBar

private struct HomeBottomBar: View {
    let totalRules: Int
    let blockedCount: Int
    let onAdd: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 24) {
                StatDisplay(
                    number: "\(totalRules)",
                    label: "rules\nset",
                    color: AppColors.textPrimary
                )
                StatDisplay(
                    number: "\(blockedCount)",
                    label: "blocked\nnow",
                    color: blockedCount > 0 ? AppColors.blockedText : AppColors.textPrimary
                )
            }
            Spacer()
            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentMint)
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.onAccent)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .padding(.bottom, 8)
        .background(AppColors.inkBase)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppColors.inkDeep),
            alignment: .top
        )
    }
}

// MARK: - AboutFrictionView

struct AboutFrictionView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(AppColors.accentMint)
                            .padding(.bottom, 4)

                        HStack(spacing: 0) {
                            Text("fric")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(AppColors.textPrimary)
                                .tracking(-1.2)
                            Text("tion")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(AppColors.accentMint)
                                .tracking(-1.2)
                        }

                        Text("make phone use intentional, not automatic")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 22) {
                        FrictionFeatureRow(
                            icon: "hand.raised",
                            title: "You choose what's blocked",
                            description: "Pick any app and set the times or conditions when it's off-limits."
                        )
                        FrictionFeatureRow(
                            icon: "figure.walk",
                            title: "Earn access, don't just tap past",
                            description: "Every unlock requires a challenge: maths, steps, a wait, or a written reason."
                        )
                        FrictionFeatureRow(
                            icon: "timer",
                            title: "Sessions keep it honest",
                            description: "After unlocking, the app re-locks automatically, even while you're in it."
                        )
                        FrictionFeatureRow(
                            icon: "flame",
                            title: "Escalation raises the stakes",
                            description: "Unlock too many times in a row and each challenge gets harder."
                        )
                    }

                    Text("Everything stays on your device. No accounts, no tracking.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(AppColors.inkBase)
            .scrollContentBackground(.hidden)
            .navigationTitle("About Friction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.accentMint)
                        .textCase(.lowercase)
                }
            }
            .toolbarBackground(AppColors.inkBase, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// Extra gap between home rule cards (iOS 17+).
private struct HomeRuleListSpacing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.listRowSpacing(8)
        } else {
            content
        }
    }
}
