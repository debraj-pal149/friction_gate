import SwiftUI

/// A sheet that opens from the options button (⋯) on a rule row.
/// Shows rule identity at the top, then a delete flow below.
///
/// Delete requires the user to manually type a short confirmation phrase
/// (paste is disabled) so accidental deletions are impossible.
struct RuleOptionsView: View {

    let rule: Rule
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var typedText = ""

    /// The phrase the user must type exactly to unlock the Delete button.
    private var deletePhrase: String {
        let name = rule.appDisplayName
            .trimmingCharacters(in: .whitespaces)
        let isPlaceholder = name.isEmpty || name.lowercased() == "selected app"
        return isPlaceholder
            ? "I want to permanently delete this rule"
            : "I want to permanently delete \(name.lowercased())"
    }

    /// Both sides are trimmed and lowercased so autocorrect, trailing spaces,
    /// or capitalisation never silently block the button.
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
            .listStyle(.insetGrouped)
            .navigationTitle("Rule Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Rule info (full details)

    private var ruleInfoSection: some View {
        Group {
            // App identity
            Section {
                HStack(spacing: 14) {
                    AppIconView(appName: rule.appDisplayName,
                                bundleID: rule.appBundleID, size: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.appDisplayName.isEmpty ? "Unnamed App" : rule.appDisplayName)
                            .font(.title3.bold())
                        HStack(spacing: 6) {
                            statusBadge
                        }
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("App")
            }

            // Block conditions
            if !rule.conditions.isEmpty {
                Section {
                    ForEach(rule.conditions.indices, id: \.self) { i in
                        Label(rule.conditions[i].displayDescription,
                              systemImage: conditionIcon(rule.conditions[i]))
                            .font(.subheadline)
                    }
                } header: {
                    Label("When It Blocks", systemImage: "clock.badge.xmark")
                }
            }

            // Unlock challenges
            if !rule.challenges.isEmpty {
                Section {
                    ForEach(rule.challenges.indices, id: \.self) { i in
                        Label(rule.challenges[i].longDescription,
                              systemImage: challengeIcon(rule.challenges[i]))
                            .font(.subheadline)
                    }
                } header: {
                    Label("Unlock Challenges", systemImage: "lock.open")
                }
            }

            // Session & escalation
            Section {
                Label(
                    "\(rule.sessionDurationMinutes) min session after each unlock",
                    systemImage: "hourglass"
                )
                .font(.subheadline)

                if rule.escalationEnabled {
                    Label(
                        "Escalation on · window: \(rule.escalationWindowMinutes) min",
                        systemImage: "arrow.up.right.circle.fill"
                    )
                    .font(.subheadline)
                    .foregroundColor(.orange)
                } else {
                    Label("Escalation off", systemImage: "arrow.up.right.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } header: {
                Label("Session & Escalation", systemImage: "dial.medium")
            }

            // Unlock history
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
            }
        }
    }

    // MARK: - Helpers

    private var statusBadge: some View {
        Group {
            if !rule.isActive {
                badge("Paused", color: .orange)
            } else {
                badge("Active", color: .green)
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
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

    // MARK: - Delete entry point

    private var deleteEntrySection: some View {
        Section {
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDeleteConfirmation = true
                }
            } label: {
                Label("Delete Rule", systemImage: "trash")
            }
        } footer: {
            Text("Permanently removes the rule and all blocking schedules for this app.")
        }
    }

    // MARK: - Delete confirmation

    private var deleteConfirmationSection: some View {
        Section {
            // Phrase to type
            VStack(alignment: .leading, spacing: 10) {
                Text("Type the following to confirm:")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text(deletePhrase)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Progress indicator
                let target  = Array(deletePhrase.trimmingCharacters(in: .whitespaces).lowercased())
                let typed   = Array(typedText.trimmingCharacters(in: .whitespaces).lowercased())
                let matched = zip(typed, target).filter { $0 == $1 }.count
                HStack(spacing: 4) {
                    Image(systemName: canDelete ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(canDelete ? .green : .secondary)
                    Text(canDelete
                         ? "Phrase matched. Confirm below"
                         : "\(matched) / \(target.count) characters")
                        .font(.caption)
                        .foregroundColor(canDelete ? .green : .secondary)
                }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

            // Paste-blocked text field — autocapitalisation off so the phrase
            // matches without the user needing to manually un-capitalise.
            PasteBlockingTextField(
                placeholder: "Type here…",
                text: $typedText,
                autocapitalizationType: .none
            )
                .frame(height: 36)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))

            // Confirm button
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
            .listRowBackground(canDelete ? Color.red : Color(.systemFill))
            .foregroundColor(canDelete ? .white : Color(.tertiaryLabel))

            // Cancel confirmation
            Button("Cancel") {
                typedText = ""
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDeleteConfirmation = false
                }
            }
            .foregroundColor(.secondary)

        } header: {
            Label("Confirm Deletion", systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
        } footer: {
            Text("This cannot be undone. The app will be unblocked immediately.")
        }
    }
}
