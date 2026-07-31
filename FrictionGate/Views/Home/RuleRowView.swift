import SwiftUI
import FamilyControls
import ManagedSettings

struct RuleRowView: View {

    let rule: Rule
    /// Whether ManagedSettings is currently shielding the app.
    let isShielded: Bool
    /// Rules are always enforcing after pause removal — kept for StatusPill.paused path.
    let isRuleActive: Bool
    let onToggleTap: () -> Void
    let onOptions: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(token: rule.appToken, appName: rule.appDisplayName, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    appNameView
                    Spacer(minLength: 0)
                }

                Text(captionText)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textDim)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .tracking(0.1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                StatusPill(status: currentStatus)
                // Visual state mirrors real shield, not "rule exists".
                CompactToggle(isOn: isShielded, action: onToggleTap)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.inkBorder)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(AppColors.inkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onOptions() }
    }

    @ViewBuilder
    private var appNameView: some View {
        let nameColor = isRuleActive ? Color(hex: "#c8d8e4") : AppColors.textMuted
        if let token = rule.appToken {
            Label(token)
                .labelStyle(.titleOnly)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(nameColor)
                .lineLimit(1)
                .id("title-\(rule.id.uuidString)")
        } else {
            Text(rule.appDisplayName.isEmpty ? "App" : rule.appDisplayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(nameColor)
                .lineLimit(1)
        }
    }

    private var currentStatus: StatusPill.Status {
        if !isRuleActive { return .paused }
        if isShielded { return .blocked }
        return .active
    }

    private var captionText: String {
        let condition = rule.conditions.first?.displayDescription ?? ""
        let challenge = rule.challengesByDifficulty.first?.displayName.lowercased() ?? ""
        if condition.isEmpty { return challenge }
        if challenge.isEmpty { return condition }
        return "\(condition) · \(challenge)"
    }
}
