import SwiftUI

struct RuleRowView: View {

    let rule: Rule
    let onToggleActive: () -> Void
    let onPause: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            appIcon
            info
            Spacer(minLength: 8)
            controls
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subviews

    private var appIcon: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(iconColor.gradient)
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: "app.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            )
    }

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

            // Status badges
            HStack(spacing: 6) {
                if rule.isPaused && !rule.pauseHasExpired {
                    badge("Paused", color: .orange)
                }
                if !rule.isActive {
                    badge("Off", color: .secondary)
                }
                if !rule.challenges.isEmpty {
                    badge(rule.challenges[0].displayName, color: .blue)
                }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Toggle("", isOn: Binding(
                get: { rule.isActive },
                set: { _ in onToggleActive() }
            ))
            .labelsHidden()

            if rule.isActive {
                Button { onPause() } label: {
                    Image(systemName: rule.isPaused ? "play.circle" : "pause.circle")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var iconColor: Color {
        if !rule.isActive    { return .secondary }
        if rule.isPaused && !rule.pauseHasExpired { return .orange }
        return .blue
    }
}
