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
            footerText: "One app per rule.",
            selection: $vm.activitySelection
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Auth required fallback

    private var authorizationRequiredView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.appAccentFill)
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.shield")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }

            VStack(spacing: 10) {
                Text("Screen Time Permission Required")
                    .font(.title3.bold())
                    .foregroundStyle(Color.appPrimary)
                    .multilineTextAlignment(.center)

                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if appState.familyControlsStatus == .notDetermined {
                Button("Request Permission") {
                    Task {
                        try? await AuthorizationCenter.shared
                            .requestAuthorization(for: .individual)
                        appState.familyControlsStatus =
                            AuthorizationCenter.shared.authorizationStatus
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if let err = appState.familyControlsError {
                Text("Technical detail: \(err)")
                    .font(.caption2)
                    .foregroundStyle(Color.appTertiary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .background(Color.appBackground)
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
