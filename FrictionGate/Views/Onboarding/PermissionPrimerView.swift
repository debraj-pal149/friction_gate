import SwiftUI
import FamilyControls

struct PermissionPrimerView: View {

    @EnvironmentObject private var appState: AppState
    @State private var isRequesting = false
    @State private var showDetail   = false

    var body: some View {
        ZStack {
            AppColors.inkBase.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 40)

                        VStack(spacing: 12) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(AppColors.accentMint)

                            HStack(spacing: 0) {
                                Text("fric")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(AppColors.textPrimary)
                                    .tracking(-1.5)
                                Text("tion")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(AppColors.accentMint)
                                    .tracking(-1.5)
                            }
                        }

                        VStack(spacing: 10) {
                            Text("one permission required")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)

                            Text("Apple will ask for Screen Time access. You must tap Allow — this is the only way Friction can block apps.")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textMuted)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }

                        VStack(spacing: 20) {
                            FrictionFeatureRow(
                                icon: "lock.fill",
                                title: "App blocking",
                                description: "Friction shows a block screen when you try to open a restricted app."
                            )
                            FrictionFeatureRow(
                                icon: "figure.walk",
                                title: "Unlock challenges",
                                description: "Walk steps, solve maths, or wait before access is granted."
                            )
                            FrictionFeatureRow(
                                icon: "clock",
                                title: "Scheduled rules",
                                description: "Blocks activate automatically on your chosen days and times."
                            )
                        }

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.escalationText)
                            Text("If you tap Don't Allow, Friction cannot block any apps. You can change this later in Settings → Screen Time.")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.escalationBody)
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .background(AppColors.escalationBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.escalationBorder, lineWidth: 1)
                        )

                        DisclosureGroup("Why does Friction need this?", isExpanded: $showDetail) {
                            Text(
                                "iOS doesn't allow apps to block other apps by default. Friction uses Apple's Screen Time framework under an approved entitlement. The permission is to iOS Screen Time, not a third-party server. Friction has no backend."
                            )
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textMuted)
                            .padding(.top, 8)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .tint(AppColors.accentMint)

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 28)
                }

                Button {
                    requestFamilyControls()
                } label: {
                    HStack(spacing: 10) {
                        if isRequesting {
                            ProgressView()
                                .tint(AppColors.onAccent)
                        }
                        Text(isRequesting ? "requesting…" : "enable friction")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.onAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.accentMint)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isRequesting)
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                Text("The Apple permission dialog appears immediately after tapping.")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textGhost)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func requestFamilyControls() {
        isRequesting = true
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                appState.familyControlsError = nil
            } catch {
                appState.familyControlsError = error.localizedDescription
            }
            appState.familyControlsStatus = AuthorizationCenter.shared.authorizationStatus
            appState.markPrimerShown()
            isRequesting = false
        }
    }
}
