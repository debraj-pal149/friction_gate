import SwiftUI
import FamilyControls

struct AppPickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel

    var body: some View {
        VStack(spacing: 0) {
            // The picker takes up most of the screen — it is a full-height list itself.
            FamilyActivityPicker(
                headerText: "Select the app you want to block",
                footerText: "Only one app per rule. Create multiple rules to block multiple apps.",
                selection: $vm.activitySelection
            )
            .onChange(of: vm.activitySelection) { selection in
                // Auto-fill display name from the picker if possible.
                if vm.appDisplayName.isEmpty,
                   let name = selection.applications.first?.localizedDisplayName,
                   !name.isEmpty {
                    vm.appDisplayName = name
                }
            }

            Divider()

            // Small section beneath the picker for the display name.
            List {
                Section {
                    HStack {
                        Text("App name")
                        Spacer()
                        TextField("Type name…", text: $vm.appDisplayName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                    if !vm.activitySelection.applicationTokens.isEmpty {
                        Label(
                            vm.activitySelection.applicationTokens.count == 1
                                ? "1 app selected" : "\(vm.activitySelection.applicationTokens.count) apps selected",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundColor(.green)
                        .font(.footnote)
                    }
                } footer: {
                    Text("The name is used in rule summaries and the pause confirmation text.")
                }
            }
            .listStyle(.insetGrouped)
            .frame(maxHeight: 150)
        }
    }
}
