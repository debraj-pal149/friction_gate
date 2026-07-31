import SwiftUI
import FamilyControls
import ManagedSettings

/// A sheet that opens from a rule row.
struct RuleOptionsView: View {

    let rule: Rule
    var isCurrentlyBlocked: Bool = true
    let onUnblock: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var typedText = ""
    @State private var now = Date()
    @State private var deleteCooldownEndsAt: Date? = nil

    private let deleteCooldownSeconds: TimeInterval = 60
    private let deletePhrase = "I understand deleting this rule means future me loses a hard-earned guardrail and distractions get a free buffet. I am deleting this intentionally, not impulsively, and I accept that rebuilding this discipline later will take real effort, patience, and a little humility."

    private var canDelete: Bool {
        let typed  = typedText.trimmingCharacters(in: .whitespaces).lowercased()
        let target = deletePhrase.trimmingCharacters(in: .whitespaces).lowercased()
        return !typed.isEmpty && typed == target
    }

    private var cooldownRemainingSeconds: Int {
        guard let endsAt = deleteCooldownEndsAt else { return 0 }
        return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    private var isDeleteCooldownActive: Bool {
        cooldownRemainingSeconds > 0
    }

    private var cooldownTimeLabel: String {
        let total = cooldownRemainingSeconds
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var cooldownProgress: Double {
        let elapsed = deleteCooldownSeconds - Double(cooldownRemainingSeconds)
        return min(1, max(0, elapsed / deleteCooldownSeconds))
    }

    private var ruleSummaryLine: String {
        let condition = rule.conditions.first?.displayDescription ?? ""
        let challenge = rule.challengesByDifficulty.first?.displayName.lowercased() ?? ""
        if condition.isEmpty { return challenge }
        if challenge.isEmpty { return condition }
        return "\(condition) · \(challenge)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    optionsHeader
                    sectionDivider
                    conditionsSection
                    sectionDivider
                    challengesSection
                    sectionDivider
                    sessionSection
                    sectionDivider
                    historySection
                    sectionDivider
                    deleteSection
                    Spacer(minLength: 100)
                }
            }
            .background(AppColors.inkBase)

            stickyUnblockFooter
        }
        .background(AppColors.inkBase)
        .preferredColorScheme(.dark)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppColors.inkDeep)
            .frame(height: 1)
    }

    // MARK: - Header

    private var optionsHeader: some View {
        HStack(spacing: 16) {
            AppIconView(token: rule.appToken, appName: rule.appDisplayName, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                if let token = rule.appToken {
                    Label(token)
                        .labelStyle(.titleOnly)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                } else {
                    Text(rule.appDisplayName.isEmpty ? "Unnamed App" : rule.appDisplayName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                }
                Text(ruleSummaryLine)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textMuted)
                    .lineLimit(2)
            }
            Spacer()
            Button("done") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.accentMint)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Sections

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "when it blocks")
            if rule.conditions.isEmpty {
                Text("no conditions")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textDim)
            } else {
                ForEach(rule.conditions.indices, id: \.self) { i in
                    Text(rule.conditions[i].displayDescription)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "#c8d8e4"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "unlock challenges")
            ForEach(rule.challengesByDifficulty.indices, id: \.self) { i in
                let challenge = rule.challengesByDifficulty[i]
                Text(challenge.longDescription)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#c8d8e4"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "session & escalation")
            Text("\(rule.sessionDurationMinutes) min session after each unlock")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#c8d8e4"))
            Text(rule.escalationEnabled
                  ? "escalation on · \(rule.escalationWindowMinutes) min window"
                  : "escalation off")
                .font(.system(size: 15))
                .foregroundColor(rule.escalationEnabled ? AppColors.escalationText : AppColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "history")
            historyRow("total unlocks", "\(rule.unlockCount)")
            if let last = rule.lastUnlockedAt {
                historyRow("last unlocked", last.formatted(.relative(presentation: .named)))
            } else {
                historyRow("last unlocked", "never")
            }
            historyRow("created", rule.createdAt.formatted(date: .abbreviated, time: .omitted))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    private func historyRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "danger zone")
                .padding(.top, 4)

            if showDeleteConfirmation {
                deleteConfirmationContent
            } else {
                Button {
                    typedText = ""
                    now = Date()
                    deleteCooldownEndsAt = Date().addingTimeInterval(deleteCooldownSeconds)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDeleteConfirmation = true
                    }
                } label: {
                    Text("delete rule")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.blockedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.blockedBg)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.blockedBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var deleteConfirmationContent: some View {
        if isDeleteCooldownActive {
            VStack(alignment: .leading, spacing: 12) {
                Text("cooldown for reconsideration")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Text("Take a breath. Typing unlocks when the timer ends.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textMuted)
                Text(cooldownTimeLabel)
                    .font(.system(size: 22, weight: .light, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                ProgressView(value: cooldownProgress)
                    .tint(AppColors.escalationText)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("type the following to confirm")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textMuted)

                Text(deletePhrase)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.inkDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.inkBorder, lineWidth: 1)
                    )

                PasteBlockingTextView(
                    text: $typedText,
                    font: .systemFont(ofSize: 14),
                    autocapitalizationType: .none
                )
                .frame(minHeight: 120)
                .padding(10)
                .background(AppColors.inkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(canDelete ? AppColors.accentMint : AppColors.inkBorder, lineWidth: 1)
                )

                Button {
                    onDelete()
                    dismiss()
                } label: {
                    Text("confirm delete")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(canDelete ? AppColors.onAccent : AppColors.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canDelete ? AppColors.blockedText : AppColors.inkSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canDelete)
                .buttonStyle(.plain)
            }
        }

        Button("cancel") {
            typedText = ""
            deleteCooldownEndsAt = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                showDeleteConfirmation = false
            }
        }
        .font(.system(size: 12))
        .foregroundColor(AppColors.textGhost)
        .padding(.top, 4)
    }

    // MARK: - Sticky footer

    private var stickyUnblockFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.inkDeep)
                .frame(height: 1)
            Button {
                guard isCurrentlyBlocked else { return }
                // Signal parent, then dismiss. Parent presents unlock in sheet onDismiss
                // so it never races another presentation.
                onUnblock()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open")
                        .font(.system(size: 14))
                    Text(isCurrentlyBlocked ? "unblock now" : "not blocked right now")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(isCurrentlyBlocked ? AppColors.onAccent : AppColors.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isCurrentlyBlocked ? AppColors.accentMint : AppColors.inkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentlyBlocked ? Color.clear : AppColors.inkBorder, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(!isCurrentlyBlocked)
            .background(AppColors.inkBase)
            .padding(.bottom, 8)
        }
    }
}
