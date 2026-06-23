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
        HStack(alignment: .center, spacing: 14) {

            // ── App icon ──────────────────────────────────────────────────
            AppIconView(token: rule.appToken,
                        appName: rule.appDisplayName,
                        size: 52)
                .opacity(isRuleActive ? 1 : 0.35)

            // ── Info column ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {

                // App name
                appNameView

                // Condition summary (if any)
                if let condition = rule.conditions.first {
                    Text(condition.displayDescription)
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondary)
                        .lineLimit(1)
                }

                // Badges + options button on same row
                HStack(spacing: 6) {
                    statusBadge

                    if !rule.challenges.isEmpty {
                        ThemeBadge(
                            text: rule.challenges[0].displayName,
                            color: Color.appAccentBright
                        )
                    }

                    Spacer(minLength: 0)

                    Button { onOptions() } label: {
                        Image(systemName: "ellipsis")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.appTertiary)
                            .padding(7)
                            .background(Color.appSurface2)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Toggle ────────────────────────────────────────────────────
            Toggle("", isOn: Binding(
                get: { isRuleActive },
                set: { _ in onToggleTap() }
            ))
            .labelsHidden()
            .tint(Color.appAccent)
            .fixedSize()
        }
        .padding(.vertical, 12)
        .padding(.trailing, 2)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var appNameView: some View {
        if let token = rule.appToken {
            Label(token)
                .labelStyle(.titleOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(isRuleActive ? Color.appPrimary : Color.appSecondary)
        } else {
            Text(rule.appDisplayName.isEmpty ? "App" : rule.appDisplayName)
                .font(.body.weight(.semibold))
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
}
