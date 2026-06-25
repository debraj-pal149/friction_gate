import SwiftUI
import FamilyControls
import ManagedSettings

struct RuleRowView: View {

    let rule: Rule
    /// Whether ManagedSettings is currently shielding the app.
    /// Drives the "Blocked" / "Unblocked" status badge.
    let isShielded: Bool
    let onOptions: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AppIconView(token: rule.appToken, appName: rule.appDisplayName, size: 47)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 0) {
                // Row 1: title
                HStack(alignment: .center, spacing: 8) {
                    appNameView
                }

                // Row 2: merged caption line
                Text(captionText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.appTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 4)
                    .padding(.bottom, 6)

                // Row 3: status + chevron
                HStack(spacing: 0) {
                    statusRow
                    Spacer(minLength: 8)
                    Button(action: onOptions) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.appTertiary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Subviews

    @ViewBuilder
    private var appNameView: some View {
        if let token = rule.appToken {
            Label(token)
                .labelStyle(.titleOnly)
                .foregroundStyle(Color.appPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .scaleEffect(0.9, anchor: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(rule.appDisplayName.isEmpty ? "App" : rule.appDisplayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.appPrimary)
                .lineLimit(1)
        }
    }

    private var statusRow: some View {
        let style = statusStyle
        return HStack(spacing: 5) {
            Circle()
                .fill(style.color)
                .frame(width: 7, height: 7)
            Text(style.text)
                .font(.caption2.weight(.semibold))
                .kerning(0.35)
                .foregroundStyle(style.color)
        }
    }

    private var statusStyle: (text: String, color: Color) {
        if isShielded {
            return ("APP BLOCKED", Color.appDestructive)
        } else {
            return ("APP UNBLOCKED", Color.appSuccess)
        }
    }

    private var captionText: String {
        let condition = rule.conditions.first?.displayDescription ?? ""
        let challenge = rule.challengesByDifficulty.first?.displayName.lowercased() ?? ""
        if condition.isEmpty { return challenge }
        if challenge.isEmpty { return condition }
        return "\(condition) · \(challenge)"
    }

}
