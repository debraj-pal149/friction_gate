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
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var activeSheet: HomeSheet? = nil
    @State private var showThemeControls = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.rules.isEmpty {
                    emptyState
                } else {
                    ruleList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showThemeControls.toggle()
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(Color.appSecondary)
                            .font(.headline)
                            .frame(width: 34, height: 34)
                    }
                    .padding(.vertical, 3)

                    Button { activeSheet = .builder } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.appAccent)
                            .frame(width: 34, height: 34)
                    }
                    .padding(.vertical, 3)
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { activeSheet = .settings } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.appSecondary)
                            .font(.headline)
                            .frame(width: 34, height: 34)
                    }
                    .padding(.vertical, 3)
                    Button { activeSheet = .about } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.appSecondary)
                            .font(.headline)
                            .frame(width: 34, height: 34)
                    }
                    .padding(.vertical, 3)
                }
            }
            .sheet(item: $activeSheet, onDismiss: {
                // Refresh after the builder sheet closes so any newly-created
                // rule's shield state is reflected immediately.
                vm.refreshRules()
                vm.refreshShieldStates()
            }) { sheet in
                sheetContent(for: sheet)
            }
            .sheet(item: $vm.pendingUnlockRule) { rule in
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
            .overlay(alignment: .topTrailing) {
                if showThemeControls {
                    themeControlsPopover
                        .padding(.top, 8)
                        // Offset left so the panel sits below palette button,
                        // not below the plus button at far right.
                        .padding(.trailing, 48)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(5)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showThemeControls)
        .onTapGesture {
            if showThemeControls { showThemeControls = false }
        }
        .onAppear {
            vm.refreshRules()
            vm.refreshShieldStates()
        }
    }

    private var isDarkModeActive: Bool {
        (appState.colorSchemeOverride ?? systemColorScheme) == .dark
    }

    private var themeControlsPopover: some View {
        HStack(spacing: 12) {
            Button {
                appState.cycleSavedColorTemplate()
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.headline)
                    .foregroundStyle(Color.appOnAccent)
                    .frame(width: 38, height: 38)
                    .background(Color.appAccent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                appState.toggleColorScheme(using: systemColorScheme)
            } label: {
                Image(systemName: isDarkModeActive ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.headline)
                    .foregroundStyle(Color.appSecondary)
                    .frame(width: 38, height: 38)
                    .background(Color.appSurface2)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appBorder, lineWidth: 0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.8)
        )
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
                onUnblock: { vm.requestUnlock(for: rule) },
                onDelete: { vm.deleteRule(rule) }
            )

        case .about:
            AboutFrictionView()
        }
    }

    // MARK: - Rule list

    private var ruleList: some View {
        List {
            ForEach(vm.rulesByDifficulty) { rule in
                RuleRowView(
                    rule: rule,
                    isShielded: vm.shieldedRuleIDs.contains(rule.id),
                    onOptions: { activeSheet = .options(rule) }
                )
                .surfaceRow()
                .listRowSeparatorTint(Color.appBorder)
            }
        }
        .inkBackground()
        .listStyle(.insetGrouped)
        .padding(.top, -10)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.appAccentFill)
                    .frame(width: 96, height: 96)
                Image(systemName: "lock.shield")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }
            .accentGlow(radius: 20)

            VStack(spacing: 8) {
                Text("No Rules Yet")
                    .font(.title2.bold())
                    .foregroundStyle(Color.appPrimary)
                Text("Add your first rule to start blocking apps.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                activeSheet = .builder
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.subheadline.bold())
                    Text("Add Rule")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(Color.appOnAccent)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.appAccent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - AboutFrictionView

private struct AboutFrictionView: View {

    @Environment(\.dismiss) private var dismiss

    private struct Feature {
        let icon: String
        let title: String
        let body: String
    }

    private let features: [Feature] = [
        Feature(icon: "lock.shield.fill",
                title: "You choose what's blocked",
                body:  "Pick any app and set the times or conditions when it's off-limits."),
        Feature(icon: "brain.head.profile",
                title: "Earn access, don't just tap past",
                body:  "Every unlock requires a challenge: maths, steps, a wait, or a written reason."),
        Feature(icon: "timer",
                title: "Sessions keep it honest",
                body:  "After unlocking, the app re-locks automatically, even while you're in it."),
        Feature(icon: "arrow.up.right.circle.fill",
                title: "Escalation raises the stakes",
                body:  "Unlock too many times in a row and each challenge gets harder."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 36) {
                    header
                    featuresBlock
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .background(Color.appBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("About Friction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.appAccentFill)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                    )
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.appAccent)
            }
            .accentGlow(radius: 16)

            Text("Friction")
                .font(.title.bold())
                .foregroundStyle(Color.appPrimary)

            Text("Make phone use intentional, not automatic.")
                .font(.subheadline)
                .foregroundStyle(Color.appSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var featuresBlock: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element.title) { index, feature in
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.appAccentFill)
                            .frame(width: 38, height: 38)
                        Image(systemName: feature.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.appAccent)
                    }
                    .accentGlow(radius: 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.appPrimary)
                        Text(feature.body)
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)

                if index < features.count - 1 {
                    Divider()
                        .background(Color.appBorder)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 14)
    }

    private var footer: some View {
        Text("Everything stays on your device. No accounts, no tracking.")
            .font(.caption)
            .foregroundStyle(Color.appTertiary)
            .multilineTextAlignment(.center)
            .padding(.bottom, 8)
    }
}
