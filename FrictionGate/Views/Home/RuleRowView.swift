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
                .opacity(isShielded ? 1 : 0.5)

            info
            Spacer(minLength: 8)
            controls
        }
        .padding(.vertical, 4)
    }

    // MARK: - Info column

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(rule.appDisplayName)
                .font(.headline)

            if let condition = rule.conditions.first {
                Text(condition.displayDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                if isShielded {
                    badge("Blocked", color: .red)
                } else {
                    badge("Unlocked", color: .green)
                }
                if !rule.challenges.isEmpty {
                    badge(rule.challenges[0].displayName, color: .blue)
                }
            }
        }
    }

    // MARK: - Controls column

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Toggle reflects live shield state; tapping triggers the
            // challenge/confirmation flow, not a direct boolean flip.
            Toggle("", isOn: Binding(
                get: { isShielded },
                set: { _ in onToggleTap() }
            ))
            .labelsHidden()

            Button { onOptions() } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Badge helper

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
