import SwiftUI

struct RuleRowView: View {

    let rule: Rule
    /// Whether the app is currently shielded (blocked) — drives the toggle.
    let isShielded: Bool
    let onToggleTap: () -> Void
    let onOptions: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(appName: rule.appDisplayName, bundleID: rule.appBundleID, size: 46)
                .opacity(isShielded ? 1 : 0.45)

            info
            Spacer(minLength: 8)
            controls
        }
        .padding(.vertical, 6)
    }

    // MARK: - Info column

    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rule.appDisplayName)
                .font(.headline)
                .foregroundStyle(Color.appPrimary)

            if let condition = rule.conditions.first {
                Text(condition.displayDescription)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                if isShielded {
                    ThemeBadge(text: "Blocked", color: Color.appAccent)
                } else {
                    ThemeBadge(text: "Unlocked", color: Color.appSecondary)
                }
                if !rule.challenges.isEmpty {
                    ThemeBadge(text: rule.challenges[0].displayName, color: Color.appAccentBright)
                }
            }
        }
    }

    // MARK: - Controls column

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isShielded },
                set: { _ in onToggleTap() }
            ))
            .labelsHidden()

            Button { onOptions() } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Color.appTertiary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }
}
