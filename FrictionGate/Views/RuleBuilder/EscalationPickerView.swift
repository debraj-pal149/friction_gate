import SwiftUI

struct EscalationPickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel

    var body: some View {
        List {
            sessionSection
            escalationSection
        }
        .inkBackground()
        .listStyle(.insetGrouped)
    }

    private var sessionSection: some View {
        Section {
            Stepper(
                "Session: \(vm.sessionDurationMinutes) min",
                value: $vm.sessionDurationMinutes,
                in: 1...120, step: 5
            )
            .foregroundStyle(Color.appPrimary)
        } header: {
            Label("Session Duration", systemImage: "hourglass")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text(
                "Once you complete the challenge, the app unlocks for \(vm.sessionDurationMinutes) " +
                "minute\(vm.sessionDurationMinutes == 1 ? "" : "s"). It locks again automatically " +
                "after that, even if you're still using it."
            )
            .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    private var escalationSection: some View {
        Section {
            Toggle("Enable escalation", isOn: $vm.escalationEnabled)

            if vm.escalationEnabled {
                Stepper(
                    "Window: \(vm.escalationWindowMinutes) min",
                    value: $vm.escalationWindowMinutes,
                    in: 15...480, step: 15
                )
                .foregroundStyle(Color.appPrimary)
            }
        } header: {
            Label("Escalation", systemImage: "arrow.up.right.circle")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            if vm.escalationEnabled {
                Text(
                    "Each time you unlock within \(vm.escalationWindowMinutes) minutes of the " +
                    "previous unlock, the challenges scale up (up to 5×). " +
                    "The multiplier resets once the window expires."
                )
                .foregroundStyle(Color.appTertiary)
            } else {
                Text(
                    "When enabled, rapid repeated unlocks become progressively harder. " +
                    "Maths problems grow in count, waits grow in length, steps increase."
                )
                .foregroundStyle(Color.appTertiary)
            }
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }
}
