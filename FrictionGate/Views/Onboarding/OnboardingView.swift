import SwiftUI

/// Full-screen intro shown exactly once on the very first app launch.
struct OnboardingView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            AppColors.inkBase.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 52, weight: .light))
                        .foregroundColor(AppColors.accentMint)

                    HStack(spacing: 0) {
                        Text("fric")
                            .font(.system(size: 38, weight: .light))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(-2)
                        Text("tion")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(AppColors.accentMint)
                            .tracking(-2)
                    }

                    Text("make phone use intentional")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.bottom, 48)

                VStack(spacing: 20) {
                    FrictionFeatureRow(
                        icon: "hand.raised",
                        title: "You choose what's blocked",
                        description: "Pick any app and set the times or conditions when it's off-limits."
                    )
                    FrictionFeatureRow(
                        icon: "figure.walk",
                        title: "Earn access, don't just tap past",
                        description: "Every unlock requires a challenge: maths, steps, a wait, or a written reason."
                    )
                    FrictionFeatureRow(
                        icon: "timer",
                        title: "Sessions keep it honest",
                        description: "After unlocking, the app re-locks automatically, even while you're in it."
                    )
                    FrictionFeatureRow(
                        icon: "flame",
                        title: "Escalation raises the stakes",
                        description: "Unlock too many times in a row and each challenge gets harder."
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    appState.markOnboardingShown()
                } label: {
                    Text("let's go")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.accentMint)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }
}
