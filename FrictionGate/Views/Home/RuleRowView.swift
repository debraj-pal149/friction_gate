import SwiftUI
import FamilyControls
import ManagedSettings

struct RuleRowView: View {

    let rule: Rule
    /// Whether the rule itself is active (not paused / disabled by the user).
    /// This drives the toggle — it is true even when the app is currently
    /// unblocked due to time conditions or an active session.
    let isRuleActive: Bool
    /// Whether ManagedSettings is currently shielding the app.
    /// Drives the "Blocked" / "Unlocked" status badge only.
    let isShielded: Bool
    let onToggleTap: () -> Void
    let onOptions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                AppIconView(token: rule.appToken,
                            appName: rule.appDisplayName,
                            size: 48)
                    .opacity(isRuleActive ? 1 : 0.35)

                VStack(alignment: .leading, spacing: 3) {
                    appNameView

                    if let condition = rule.conditions.first {
                        Text(condition.displayDescription)
                            .font(.footnote)
                            .foregroundStyle(Color.appSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { isRuleActive },
                    set: { _ in onToggleTap() }
                ))
                .labelsHidden()
                .tint(Color.appAccent)
                .fixedSize()
            }

            HStack(spacing: 6) {
                statusBadge

                if !rule.challenges.isEmpty {
                    ThemeBadge(text: rule.challenges[0].displayName,
                               color: Color.appAccentBright)
                }

                Spacer(minLength: 8)

                Button { onOptions() } label: {
                    HStack(spacing: 4) {
                        Text("Options")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color.appSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appSurface2)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 5)
        .padding(.vertical, 6)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var appNameView: some View {
        if let token = rule.appToken {
            Label(token)
                .labelStyle(.titleOnly)
                .font(.headline)
                .foregroundStyle(isRuleActive ? Color.appPrimary : Color.appSecondary)
        } else {
            Text(rule.appDisplayName.isEmpty ? "App" : rule.appDisplayName)
                .font(.headline)
                .foregroundStyle(isRuleActive ? Color.appPrimary : Color.appSecondary)
        }
    }

    private var statusBadge: some View {
        Group {
            if !isRuleActive {
                ThemeBadge(text: "Paused", color: Color.appTertiary)
            } else if isShielded {
                ThemeBadge(text: "Blocked", color: Color.appAccent)
            } else {
                ThemeBadge(text: "Active", color: Color.appSuccess)
            }
        }
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)

            // Soft top highlight for a light glass feel.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.58), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Subtle depth border.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.black.opacity(0.13), Color.black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        }
    }
}
