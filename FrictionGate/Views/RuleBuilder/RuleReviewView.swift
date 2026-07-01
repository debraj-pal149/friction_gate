import SwiftUI
import FamilyControls
import ManagedSettings

struct RuleReviewView: View {

    @ObservedObject var vm: RuleBuilderViewModel
    let onSave: () -> Void

    var body: some View {
        List {
            appHeaderSection

            Section {
                Text(vm.reviewSummary)
                    .font(.body)
                    .lineSpacing(5)
                    .foregroundStyle(Color.appPrimary)
                    .padding(.vertical, 4)
            } header: {
                Label("Rule Summary", systemImage: "doc.text")
                    .foregroundStyle(Color.appSecondary)
            }
            .surfaceRow()
            .listRowSeparatorTint(Color.appBorder)

            if !vm.conditions.isEmpty {
                Section("Conditions") {
                    ForEach(vm.conditions.indices, id: \.self) { i in
                        Label(vm.conditions[i].displayDescription,
                              systemImage: conditionIcon(vm.conditions[i]))
                            .font(.subheadline)
                            .foregroundStyle(Color.appPrimary)
                            .labelStyle(AccentedIconLabelStyle())
                    }
                }
                .surfaceRow()
                .listRowSeparatorTint(Color.appBorder)
            }

            if !vm.challenges.isEmpty {
                Section("Challenges") {
                    ForEach(vm.challengesSortedByDifficulty.indices, id: \.self) { i in
                        let challenge = vm.challengesSortedByDifficulty[i]
                        HStack(spacing: 10) {
                            Label(challenge.longDescription,
                                  systemImage: challengeIcon(challenge))
                                .font(.subheadline)
                                .foregroundStyle(Color.appPrimary)
                                .labelStyle(AccentedIconLabelStyle())
                            Spacer(minLength: 8)
                            ThemeBadge(text: challenge.difficultyTier.compactLabel,
                                       color: difficultyColor(challenge.difficultyTier))
                        }
                    }
                }
                .surfaceRow()
                .listRowSeparatorTint(Color.appBorder)
            }

            Section("Session & Escalation") {
                Label(
                    "\(vm.sessionDurationMinutes) min session after each unlock",
                    systemImage: "hourglass"
                )
                .font(.subheadline)
                .foregroundStyle(Color.appPrimary)
                .labelStyle(AccentedIconLabelStyle())

                if vm.escalationEnabled {
                    Label(
                        "Escalation on, window: \(vm.escalationWindowMinutes) min",
                        systemImage: "arrow.up.right.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color.appPrimary)
                    .labelStyle(AccentedIconLabelStyle())
                } else {
                    Label("Escalation off", systemImage: "arrow.up.right.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondary)
                }
            }
            .surfaceRow()
            .listRowSeparatorTint(Color.appBorder)

            Section {
                Button {
                    onSave()
                } label: {
                    HStack {
                        Spacer()
                        Label("Save Rule", systemImage: "checkmark.shield.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .foregroundStyle(Color.appOnAccent)
                .listRowBackground(vm.isValid ? Color.appAccent : Color.appSurface2)
                .disabled(!vm.isValid)
            }
            .listRowSeparatorTint(Color.clear)
        }
        .inkBackground()
        .listStyle(.insetGrouped)
    }

    // MARK: - App header

    private var appHeaderSection: some View {
        Section {
            if vm.selectedApplicationTokens.count > 1 {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.appAccentFill)
                            .frame(width: 64, height: 64)
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(vm.selectedApplicationTokens.count) Apps Selected")
                            .font(.title3.bold())
                            .foregroundStyle(Color.appPrimary)
                        Text("The same rule settings will be created for each selected app.")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondary)
                    }
                }
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 16) {
                    AppIconView(token: vm.applicationToken,
                                appName: vm.appDisplayName,
                                size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        if let token = vm.applicationToken {
                            Label(token)
                                .labelStyle(.titleOnly)
                                .font(.title3.bold())
                                .foregroundStyle(Color.appPrimary)
                        } else {
                            Text(vm.appDisplayName.isEmpty ? "Selected App" : vm.appDisplayName)
                                .font(.title3.bold())
                                .foregroundStyle(Color.appPrimary)
                        }
                        if !vm.appDisplayName.isEmpty {
                            Text(vm.appDisplayName)
                                .font(.caption)
                                .foregroundStyle(Color.appSecondary)
                        }
                        Text("Rule applies to this app")
                            .font(.caption)
                            .foregroundStyle(Color.appTertiary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .surfaceRow()
    }

    // MARK: - Icon helpers

    private func conditionIcon(_ condition: BlockCondition) -> String {
        switch condition {
        case .timeWindow:      return "clock"
        case .afterWakeUp:     return "sunrise"
        case .beforeSleep:     return "moon"
        case .dailyOpenLimit:  return "chart.bar"
        }
    }

    private func challengeIcon(_ challenge: UnlockChallenge) -> String {
        switch challenge {
        case .steps:        return "figure.walk"
        case .maths:        return "function"
        case .typeSentence: return "keyboard"
        case .wait:         return "timer"
        case .writeReason:  return "pencil.and.list.clipboard"
        }
    }

    private func difficultyColor(_ tier: ChallengeDifficultyTier) -> Color {
        switch tier {
        case .easy: return Color.appSuccess
        case .medium: return Color.appAccent
        case .hard: return Color.appWarning
        case .extreme: return Color.appDestructive
        }
    }
}

// MARK: - Accented icon label style

private struct AccentedIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon.foregroundStyle(Color.appAccent)
            configuration.title
        }
    }
}

// MARK: - UnlockChallenge long description

extension UnlockChallenge {
    var longDescription: String {
        switch self {
        case .steps(let n):        return "Walk \(n) steps"
        case .maths(let c):        return "Solve \(c) maths problem\(c == 1 ? "" : "s")"
        case .typeSentence(let s): return "Type: \u{201C}\(s)\u{201D}"
        case .wait(let m):         return "Wait \(m) minute\(m == 1 ? "" : "s")"
        case .writeReason:         return "Write a reason"
        }
    }
}
