import SwiftUI
import FamilyControls

struct PermissionPrimerView: View {

    @EnvironmentObject private var appState: AppState
    @State private var isRequesting = false
    @State private var showDetail   = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 36) {
                    Spacer(minLength: 48)

                    appIdentity
                    headline
                    featureList
                    warningCallout
                    disclosure
                    ctaButton
                    captionNote

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 28)
            }
        }
    }

    // MARK: - App identity

    private var appIdentity: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccentBright],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.appAccent.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 16, y: 8)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.appPrimary)
            }

            Text("Friction")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.appPrimary)
        }
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: 10) {
            Text("One permission required")
                .font(.title2.bold())
                .foregroundStyle(Color.appPrimary)
                .multilineTextAlignment(.center)

            Text("Apple will ask you for Screen Time access.\nYou **must tap Allow**. This is the only way Friction can block apps.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.appSecondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(spacing: 0) {
            featureRow(icon: "lock.fill",
                       title: "App blocking",
                       detail: "Friction shows a block screen when you try to open a restricted app.")
            Divider().background(Color.appBorder)
            featureRow(icon: "figure.walk",
                       title: "Unlock challenges",
                       detail: "Walk steps, solve maths, or wait before access is granted.")
            Divider().background(Color.appBorder)
            featureRow(icon: "clock.badge.checkmark",
                       title: "Scheduled rules",
                       detail: "Blocks activate automatically on your chosen days and times.")
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appAccentFill)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .foregroundStyle(Color.appAccent)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appPrimary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.appSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }

    // MARK: - Warning callout

    private var warningCallout: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.appWarning)
                .font(.title3)

            Text("If you tap **Don't Allow**, Friction cannot block any apps and will have no functionality. You can change this later in Settings → Screen Time.")
                .font(.footnote)
                .foregroundStyle(Color.appSecondary)
        }
        .padding(16)
        .background(Color.appWarning.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.appWarning.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Why disclosure

    private var disclosure: some View {
        DisclosureGroup("Why does Friction need this?", isExpanded: $showDetail) {
            Text(
                "iOS doesn't allow apps to block other apps by default. Apple created the Screen Time framework specifically for parental controls and focus tools. Friction uses this framework under an Apple-approved developer entitlement. The permission you are granting is to iOS's own Screen Time system, not to any third-party server. Friction has no backend and stores all data on your device."
            )
            .font(.footnote)
            .foregroundStyle(Color.appSecondary)
            .padding(.top, 8)
        }
        .font(.footnote.bold())
        .foregroundStyle(Color.appSecondary)
        .tint(Color.appAccent)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            requestFamilyControls()
        } label: {
            HStack(spacing: 10) {
                if isRequesting {
                    ProgressView()
                        .tint(Color.appOnAccent)
                }
                Text(isRequesting ? "Requesting…" : "Enable Friction")
                    .font(.headline)
                    .foregroundStyle(Color.appOnAccent)
            }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.appAccent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .disabled(isRequesting)
    .buttonStyle(.plain)
}

private var captionNote: some View {
    Text("The Apple permission dialog will appear immediately after tapping.")
        .font(.caption)
        .foregroundStyle(Color.appTertiary)
        .multilineTextAlignment(.center)
}    // MARK: - Request

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
