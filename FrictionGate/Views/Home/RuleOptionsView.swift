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
            .lowercased()
        // If the rule has no app name (legacy rules created before auto-population),
        // fall back to a fixed phrase so there's never a trailing space.
        return name.isEmpty
            ? "I want to permanently delete this rule"
            : "I want to permanently delete \(name)"
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

    // MARK: - Rule info header

    private var ruleInfoSection: some View {
        Section {
            HStack(spacing: 14) {
                AppIconView(appName: rule.appDisplayName,
                            bundleID: rule.appBundleID, size: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.appDisplayName)
                        .font(.headline)
                    if let cond = rule.conditions.first {
                        Text(cond.displayDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if rule.challenges.isEmpty == false {
                        Text(rule.challenges.map(\.displayName).joined(separator: " · "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Rule")
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
                         ? "Phrase matched — confirm below"
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
