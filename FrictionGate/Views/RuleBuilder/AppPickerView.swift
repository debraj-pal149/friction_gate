import SwiftUI
import FamilyControls

struct AppPickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel
    @EnvironmentObject private var appState: AppState

    /// True once the picker has committed a selection (tokencount > 0).
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
                footerText: "Only one app per rule.",
                selection: interceptedBinding
            )

            if hasSelection {
                Divider()
                confirmationStrip
            }
        }
    }

    // MARK: - Custom binding
    //
    // FamilyActivityPicker is a UIKit system view. Using a custom Binding setter
    // is more reliable than onChange because it intercepts the update synchronously,
    // regardless of how the UIKit layer triggers the callback.

    private var interceptedBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: { vm.activitySelection },
            set: { new in
                vm.activitySelection = new
                // Try to auto-populate the display name from the Application metadata.
                // NOTE: localizedDisplayName is nil in development environments
                // without a production-approved Family Controls entitlement.
                // In production this will be auto-populated; in dev the user types it.
                if let app = new.applications.first {
                    if let name = app.localizedDisplayName, !name.isEmpty {
                        vm.appDisplayName = name
                    }
                    // Remove the two lines below if bundleIdentifier doesn't compile.
                    if let bid = app.bundleIdentifier, !bid.isEmpty {
                        vm.appBundleID = bid
                    }
                }
            }
        )
    }

    // MARK: - Confirmation strip

    private var confirmationStrip: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                AppIconView(appName: vm.appDisplayName.isEmpty ? "?" : vm.appDisplayName,
                            bundleID: vm.appBundleID, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    if vm.appDisplayName.isEmpty {
                        // Name wasn't auto-populated — show an inline field.
                        TextField("App name (e.g. Instagram)", text: $vm.appDisplayName)
                            .font(.headline)
                            .submitLabel(.done)
                    } else {
                        Text(vm.appDisplayName)
                            .font(.headline)
                    }
                    Text(vm.appDisplayName.isEmpty
                         ? "Type the app name above, then tap Next"
                         : "Tap Next to set blocking conditions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if vm.appDisplayName.isEmpty {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.orange)
                        .font(.title3)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Auth required fallback

    private var authorizationRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Screen Time Permission Required")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
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
