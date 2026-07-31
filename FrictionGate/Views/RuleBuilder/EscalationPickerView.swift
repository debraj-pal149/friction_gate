import SwiftUI

struct EscalationPickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel

    var body: some View {
        List {
            sessionSection
            escalationSection
        }
        .builderListChrome()
    }

    private var sessionSection: some View {
        Section {
            Stepper(
                "Session: \(vm.sessionDurationMinutes) min",
                value: $vm.sessionDurationMinutes,
                in: 1...120, step: 5
            )
            .font(.system(size: 16))
            .foregroundStyle(Color.appPrimary)
        } header: {
            BuilderSectionHeader(title: "Session Duration", icon: "hourglass")
        } footer: {
            BuilderSectionFooter(
                text: "Once you complete the challenge, the app unlocks for \(vm.sessionDurationMinutes) " +
                "minute\(vm.sessionDurationMinutes == 1 ? "" : "s"). It locks again automatically " +
                "after that, even if you're still using it."
            )
        }
        .builderBlock()
    }

    private var escalationSection: some View {
        Section {
            Toggle("Enable escalation", isOn: $vm.escalationEnabled)
                .font(.system(size: 16))

            if vm.escalationEnabled {
                Stepper(
                    "Window: \(vm.escalationWindowMinutes) min",
                    value: $vm.escalationWindowMinutes,
                    in: 15...480, step: 15
                )
                .font(.system(size: 16))
                .foregroundStyle(Color.appPrimary)
            }
        } header: {
            BuilderSectionHeader(title: "Escalation", icon: "arrow.up.right.circle")
        } footer: {
            if vm.escalationEnabled {
                BuilderSectionFooter(
                    text: "Each time you unlock within \(vm.escalationWindowMinutes) minutes of the " +
                    "previous unlock, the challenges scale up (up to 5×). " +
                    "The multiplier resets once the window expires."
                )
            } else {
                BuilderSectionFooter(
                    text: "When enabled, rapid repeated unlocks become progressively harder. " +
                    "Maths problems grow in count, waits grow in length, steps increase."
                )
            }
        }
        .builderBlock()
    }
}
