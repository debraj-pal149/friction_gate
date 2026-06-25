import SwiftUI
import FamilyControls
import ManagedSettings

/// A sheet that opens from the options button (⋯) on a rule row.
struct RuleOptionsView: View {

    let rule: Rule
    let onUnblock: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var typedText = ""

    private let deletePhrase = "I want to permanently delete this rule"

    private var canDelete: Bool {
        let typed  = typedText.trimmingCharacters(in: .whitespaces).lowercased()
        let target = deletePhrase.trimmingCharacters(in: .whitespaces).lowercased()
        return !typed.isEmpty && typed == target
    }

    var body: some View {
        NavigationStack {
            List {
                ruleInfoSection

                if showDeleteConfirmation {
                    deleteConfirmationSection
                } else {
                    deleteEntrySection
                }
            }
            .inkBackground()
            .listStyle(.insetGrouped)
            .navigationTitle("Rule Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    // MARK: - Rule info

    private var ruleInfoSection: some View {
        Group {
            Section {
                HStack(spacing: 14) {
                    AppIconView(token: rule.appToken,
                                appName: rule.appDisplayName,
                                size: 52)

                    VStack(alignment: .leading, spacing: 6) {
                        if let token = rule.appToken {
                            Label(token)
                                .labelStyle(.titleOnly)
                                .font(.title3.bold())
                                .foregroundStyle(Color.appPrimary)
                        } else {
                            Text(rule.appDisplayName.isEmpty ? "Unnamed App" : rule.appDisplayName)
                                .font(.title3.bold())
                                .foregroundStyle(Color.appPrimary)
                        }
                        if !rule.appDisplayName.isEmpty {
                            Text(rule.appDisplayName)
                                .font(.caption)
                                .foregroundStyle(Color.appSecondary)
                        }
                        HStack(spacing: 8) {
                            statusBadge
                            ThemeBadge(text: rule.difficultyTier.compactLabel,
                                       color: difficultyColor(rule.difficultyTier))
                        }
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("App").foregroundStyle(Color.appSecondary)
            }
            .surfaceRow()
            .listSectionSeparatorTint(Color.appBorder)

            Section {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onUnblock()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label("Unblock App", systemImage: "lock.open.fill")
                        Spacer()
                    }
                }
                .foregroundStyle(Color.appOnAccent)
                .listRowBackground(Color.appAccent)
            } footer: {
                Text("Starts the challenge flow. Success unblocks now and auto-blocks after the session.")
                    .foregroundStyle(Color.appTertiary)
            }
            .surfaceRow()
            .listRowSeparatorTint(Color.appBorder)

            if !rule.conditions.isEmpty {
                Section {
                    ForEach(rule.conditions.indices, id: \.self) { i in
                        Label(rule.conditions[i].displayDescription,
                              systemImage: conditionIcon(rule.conditions[i]))
                            .font(.subheadline)
                            .foregroundStyle(Color.appPrimary)
                            .labelStyle(ThemedLabelStyle())
                    }
                } header: {
                    Label("When It Blocks", systemImage: "clock.badge.xmark")
                        .foregroundStyle(Color.appSecondary)
                }
                .surfaceRow()
                .listRowSeparatorTint(Color.appBorder)
            }

            if !rule.challenges.isEmpty {
                Section {
                    ForEach(rule.challengesByDifficulty.indices, id: \.self) { i in
                        let challenge = rule.challengesByDifficulty[i]
                        HStack(spacing: 10) {
                            Label(challenge.longDescription,
                                  systemImage: challengeIcon(challenge))
                                .font(.subheadline)
                                .foregroundStyle(Color.appPrimary)
                                .labelStyle(ThemedLabelStyle())
                            Spacer(minLength: 8)
                            ThemeBadge(text: challenge.difficultyTier.compactLabel,
                                       color: difficultyColor(challenge.difficultyTier))
                        }
                    }
                } header: {
                    Label("Unlock Challenges", systemImage: "lock.open")
                        .foregroundStyle(Color.appSecondary)
                }
                .surfaceRow()
                .listRowSeparatorTint(Color.appBorder)
            }

            Section {
                Label(
                    "\(rule.sessionDurationMinutes) min session after each unlock",
                    systemImage: "hourglass"
                )
                .font(.subheadline)
                .foregroundStyle(Color.appPrimary)
                .labelStyle(ThemedLabelStyle())

                if rule.escalationEnabled {
                    Label(
                        "Escalation on · window: \(rule.escalationWindowMinutes) min",
                        systemImage: "arrow.up.right.circle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color.appWarning)
                    .labelStyle(ThemedLabelStyle())
                } else {
                    Label("Escalation off", systemImage: "arrow.up.right.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondary)
                        .labelStyle(ThemedLabelStyle())
                }
            } header: {
                Label("Session & Escalation", systemImage: "dial.medium")
                    .foregroundStyle(Color.appSecondary)
            }
            .surfaceRow()
            .listRowSeparatorTint(Color.appBorder)

            Section {
                detailRow("Total unlocks", value: "\(rule.unlockCount)")
                if let last = rule.lastUnlockedAt {
                    detailRow("Last unlocked", value: last.formatted(.relative(presentation: .named)))
                } else {
                    detailRow("Last unlocked", value: "Never")
                }
                detailRow("Created", value: rule.createdAt.formatted(date: .abbreviated, time: .omitted))
            } header: {
                Label("History", systemImage: "chart.bar")
                    .foregroundStyle(Color.appSecondary)
            }
            .surfaceRow()
            .listRowSeparatorTint(Color.appBorder)
        }
    }

    // MARK: - Helpers

    private var statusBadge: some View {
        ThemeBadge(text: "Active", color: Color.appSuccess)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.appSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(Color.appPrimary)
        }
        .font(.subheadline)
    }

    private func conditionIcon(_ condition: BlockCondition) -> String {
        switch condition {
        case .timeWindow:     return "clock"
        case .afterWakeUp:    return "sunrise"
        case .beforeSleep:    return "moon"
        case .dailyOpenLimit: return "chart.bar"
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

    // MARK: - Delete entry point

    private var deleteEntrySection: some View {
        Section {
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDeleteConfirmation = true
                }
            } label: {
                HStack {
                    Spacer()
                    Label("Delete Rule", systemImage: "trash")
                    Spacer()
                }
            }
        } footer: {
            Text("Permanently removes the rule and all blocking schedules for this app.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
    }

    // MARK: - Delete confirmation

    private var deleteConfirmationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Type the following to confirm:")
                    .font(.footnote)
                    .foregroundStyle(Color.appSecondary)

                Text(deletePhrase)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundStyle(Color.appPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface3)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                let target  = Array(deletePhrase.trimmingCharacters(in: .whitespaces).lowercased())
                let typed   = Array(typedText.trimmingCharacters(in: .whitespaces).lowercased())
                let matched = zip(typed, target).filter { $0 == $1 }.count
                HStack(spacing: 6) {
                    Image(systemName: canDelete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(canDelete ? Color.appSuccess : Color.appTertiary)
                    Text(canDelete
                         ? "Phrase matched. Confirm below"
                         : "\(matched) / \(target.count) characters")
                        .font(.caption)
                        .foregroundStyle(canDelete ? Color.appSuccess : Color.appSecondary)
                }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

            PasteBlockingTextField(
                placeholder: "Type here…",
                text: $typedText,
                autocapitalizationType: .none
            )
            .frame(height: 36)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))

                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Confirm Delete", systemImage: "trash.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(!canDelete)
                    .listRowBackground(canDelete ? Color.appDestructive : Color.appSurface2)
                    .foregroundStyle(canDelete ? Color.appOnAccent : Color.appTertiary)

            Button("Cancel") {
                typedText = ""
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDeleteConfirmation = false
                }
            }
            .foregroundStyle(Color.appSecondary)

        } header: {
            Label("Confirm Deletion", systemImage: "exclamationmark.triangle")
                .foregroundStyle(Color.appDestructive)
        } footer: {
            Text("This cannot be undone. The app will be unblocked immediately.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }
}

// MARK: - Themed label style (icon in accent, text in primary)

private struct ThemedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .foregroundStyle(Color.appAccent)
            configuration.title
        }
    }
}
