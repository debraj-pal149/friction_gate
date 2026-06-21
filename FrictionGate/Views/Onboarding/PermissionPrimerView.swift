import SwiftUI
import FamilyControls

/// Full-screen onboarding card shown exactly once — before the system
/// Screen Time permission dialog appears.
///
/// The primer explains clearly that tapping "Allow" on the Apple dialog
/// is REQUIRED for Friction to function at all.  Without this context,
/// users often tap "Don't Allow" reflexively on unfamiliar permission prompts.
struct PermissionPrimerView: View {

    @EnvironmentObject private var appState: AppState
    @State private var isRequesting = false
    @State private var showDetail   = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)

                    // App identity
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .indigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 88, height: 88)
                                .shadow(color: .blue.opacity(0.4), radius: 12, y: 6)

                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 42))
                                .foregroundColor(.white)
                        }

                        Text("Friction")
                            .font(.largeTitle.bold())
                    }

                    // Headline
                    VStack(spacing: 10) {
                        Text("One permission required")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("Apple will ask you for Screen Time access.\nYou **must tap Allow**. This is the only way Friction can block apps.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    }

                    // Feature list
                    VStack(spacing: 14) {
                        featureRow(
                            icon: "lock.fill",
                            color: .blue,
                            title: "App blocking",
                            detail: "Friction shows a block screen when you try to open a restricted app."
                        )
                        featureRow(
                            icon: "figure.walk",
                            color: .green,
                            title: "Unlock challenges",
                            detail: "Walk steps, solve maths, or wait before access is granted."
                        )
                        featureRow(
                            icon: "clock.badge.checkmark",
                            color: .orange,
                            title: "Scheduled rules",
                            detail: "Blocks activate automatically on your chosen days and times."
                        )
                    }
                    .padding(.horizontal, 4)

                    // Warning callout
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        Text("If you tap **Don't Allow**, Friction cannot block any apps. The app will have no functionality whatsoever. You can change this later in Settings → Screen Time, but you must come back and grant access.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 4)

                    // "Why?" expandable
                    DisclosureGroup("Why does Friction need this?", isExpanded: $showDetail) {
                        Text(
                            "iOS doesn't allow apps to block other apps by default. Apple created the Screen Time framework specifically for parental controls and focus tools. Friction uses this framework under an Apple-approved developer entitlement. The permission you are granting is to iOS's own Screen Time system, not to any third-party server. Friction has no backend and stores all data on your device."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    }
                    .font(.footnote.bold())
                    .padding(.horizontal, 4)

                    // CTA
                    Button {
                        requestFamilyControls()
                    } label: {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 6)
                            }
                            Text(isRequesting ? "Requesting…" : "Enable Friction")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isRequesting)

                    Text("The Apple permission dialog will appear immediately after tapping.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Feature row helper

    private func featureRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.footnote).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Request

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
