import SwiftUI
import FamilyControls

struct AppPickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel
    @EnvironmentObject private var appState: AppState

    private var hasSelection: Bool {
        !vm.activitySelection.applicationTokens.isEmpty
    }

    var body: some View {
        if appState.familyControlsStatus == .approved {
            pickerContent
        } else {
            authorizationRequiredView
        }
    }

    // MARK: - Picker

    private var pickerContent: some View {
        VStack(spacing: 0) {
            FamilyActivityPicker(
                headerText: "Select the app you want to block",
                footerText: "One app per rule.",
                selection: interceptedBinding
            )

            if hasSelection {
                Divider().background(Color.appBorder)
                confirmationStrip
            }
        }
    }

    private var interceptedBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: { vm.activitySelection },
            set: { new in
                vm.activitySelection = new
                if let app = new.applications.first {
                    if let name = app.localizedDisplayName, !name.isEmpty {
                        vm.appDisplayName = name
                    }
                    if let bid = app.bundleIdentifier, !bid.isEmpty {
                        vm.appBundleID = bid
                    }
                }
            }
        )
    }

    // MARK: - Confirmation strip

    private var confirmationStrip: some View {
        HStack(spacing: 14) {
            AppIconView(appName: vm.appDisplayName.isEmpty ? "?" : vm.appDisplayName,
                        bundleID: vm.appBundleID, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                if vm.appDisplayName.isEmpty {
                    TextField("App name (e.g. Instagram)", text: $vm.appDisplayName)
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)
                        .submitLabel(.done)
                } else {
                    Text(vm.appDisplayName)
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)
                }
                Text(vm.appDisplayName.isEmpty
                     ? "Type the app name above, then tap Next"
                     : "Tap Next to set blocking conditions")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondary)
            }

            Spacer()

            Image(systemName: vm.appDisplayName.isEmpty ? "pencil.circle" : "checkmark.circle.fill")
                .foregroundStyle(vm.appDisplayName.isEmpty
                                 ? Color.appWarning
                                 : Color.appSuccess)
                .font(.title3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appSurface)
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
