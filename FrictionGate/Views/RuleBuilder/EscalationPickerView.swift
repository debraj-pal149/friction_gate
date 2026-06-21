import SwiftUI

/// Step 4 in the rule-creation flow — escalation and session settings.
///
/// Escalation and session duration are intentionally separated from the
/// challenge types (Step 3) because they control the *intensity* of the
/// friction system rather than *which* challenges are used.
struct EscalationPickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel

    var body: some View {
        List {
            sessionSection
            escalationSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Session section

    private var sessionSection: some View {
        Section {
            Stepper(
                "Session: \(vm.sessionDurationMinutes) min",
                value: $vm.sessionDurationMinutes,
                in: 1...120, step: 5
            )
        } header: {
            Label("Session Duration", systemImage: "hourglass")
        } footer: {
            Text(
                "Once you complete the challenge, the app unlocks for \(vm.sessionDurationMinutes) " +
                "minute\(vm.sessionDurationMinutes == 1 ? "" : "s"). It locks again automatically " +
                "after that, even if you're still using it."
            )
        }
    }

    // MARK: - Escalation section

    private var escalationSection: some View {
        Section {
            Toggle("Enable escalation", isOn: $vm.escalationEnabled)

            if vm.escalationEnabled {
                Stepper(
                    "Window: \(vm.escalationWindowMinutes) min",
                    value: $vm.escalationWindowMinutes,
                    in: 15...480, step: 15
                )
            }
        } header: {
            Label("Escalation", systemImage: "arrow.up.right.circle")
        } footer: {
            if vm.escalationEnabled {
                Text(
                    "Each time you unlock within \(vm.escalationWindowMinutes) minutes of the " +
                    "previous unlock, the challenges scale up (up to 5×). " +
                    "The multiplier resets once the window expires."
                )
            } else {
                Text(
                    "When enabled, rapid repeated unlocks become progressively harder. " +
                    "Each unlock within the window multiplies the challenge difficulty. " +
                    "maths problems grow in count, waits grow in length, steps increase. " +
                    "A powerful tool if you want maximum friction on habitual use."
                )
            }
        }
    }
}
