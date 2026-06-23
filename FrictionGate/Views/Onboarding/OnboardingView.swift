import SwiftUI

/// Full-screen intro shown exactly once on the very first app launch.
///
/// Displays the same content as the "About Friction" info dialog so the user
/// understands what the app does before any permission dialogs appear.
/// Tapping "Let's Go" writes `friction_onboarding_shown` to `UserDefaults.standard`
/// (survives app updates) and hands control back to `ContentView`, which then
/// presents `PermissionPrimerView` if Screen Time permission is still needed.
struct OnboardingView: View {

    @EnvironmentObject private var appState: AppState

    private struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let features: [Feature] = [
        Feature(icon: "lock.shield.fill",
                title: "You choose what's blocked",
                body:  "Pick any app and set the times or conditions when it's off-limits."),
        Feature(icon: "brain.head.profile",
                title: "Earn access, don't just tap past",
                body:  "Every unlock requires a challenge: maths, steps, a wait, or a written reason."),
        Feature(icon: "timer",
                title: "Sessions keep it honest",
                body:  "After unlocking, the app re-locks automatically, even while you're in it."),
        Feature(icon: "arrow.up.right.circle.fill",
                title: "Escalation raises the stakes",
                body:  "Unlock too many times in a row and each challenge gets harder."),
    ]

    var body: some View {
        Color.appBackground.ignoresSafeArea()
            .overlay(
                ScrollView {
                    VStack(spacing: 36) {
                        Spacer(minLength: 56)
                        header
                        featuresBlock
                        footer
                        // CTA lives at the bottom of the scroll — user must read
                        // through everything before "Let's Go" comes into view.
                        ctaButton
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                }
            )
            .preferredColorScheme(.light)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.appAccentFill)
                    .frame(width: 88, height: 88)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                    )
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.appAccent)
            }
            .accentGlow(radius: 18)

            Text("Friction")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.appPrimary)

            Text("Make phone use intentional, not automatic.")
                .font(.body)
                .foregroundStyle(Color.appSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Features

    private var featuresBlock: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.appAccentFill)
                            .frame(width: 40, height: 40)
                        Image(systemName: feature.icon)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.appAccent)
                    }
                    .accentGlow(radius: 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.appPrimary)
                        Text(feature.body)
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 15)

                if index < features.count - 1 {
                    Divider()
                        .background(Color.appBorder)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Everything stays on your device. No accounts, no tracking.")
            .font(.caption)
            .foregroundStyle(Color.appTertiary)
            .multilineTextAlignment(.center)
            .padding(.bottom, 4)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            appState.markOnboardingShown()
        } label: {
            Text("Let's Go")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accentGlow(radius: 8)
    }
}
