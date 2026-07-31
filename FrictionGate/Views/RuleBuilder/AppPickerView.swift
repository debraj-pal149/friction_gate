import SwiftUI
import FamilyControls
import ManagedSettings

struct AppPickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.familyControlsStatus == .approved {
            pickerContent
        } else {
            authorizationRequiredView
        }
    }

    // MARK: - Picker

    private var pickerContent: some View {
        FamilyActivityPicker(
            headerText: "Select the app you want to block",
            footerText: "You can select multiple apps. The same rule setup is applied to each app.",
            selection: $vm.activitySelection
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Auth required fallback

    private var authorizationRequiredView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(AppColors.accentMint)

            VStack(spacing: 8) {
                Text("screen time permission required")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(statusMessage)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            if appState.familyControlsStatus == .notDetermined {
                Button {
                    Task {
                        try? await AuthorizationCenter.shared
                            .requestAuthorization(for: .individual)
                        appState.familyControlsStatus =
                            AuthorizationCenter.shared.authorizationStatus
                    }
                } label: {
                    Text("request permission")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accentMint)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            } else {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("open settings")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accentMint)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }

            if let err = appState.familyControlsError {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.inkBase)
    }

    private var statusMessage: String {
        switch appState.familyControlsStatus {
        case .notDetermined:
            return "Friction needs Screen Time access to select which apps to block."
        case .denied:
            return "Permission was denied. Go to Settings → Screen Time and allow access."
        case .approved:
            return ""
        @unknown default:
            return "Screen Time permission status is unknown. Please restart the app."
        }
    }
}
