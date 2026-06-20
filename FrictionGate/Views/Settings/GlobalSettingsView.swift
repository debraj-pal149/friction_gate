import SwiftUI

struct GlobalSettingsView: View {

    @ObservedObject var vm: WakeUpViewModel
    @Environment(\.dismiss) private var dismiss

    // Local bindings backed by WakeUpViewModel computed properties
    @State private var detectionEnabled: Bool = false
    @State private var idleHours:        Int  = 6
    @State private var windowStartDate:  Date = dc(hour: 5).asDate
    @State private var windowEndDate:    Date = dc(hour: 11).asDate
    @State private var sleepTimeDate:    Date = dc(hour: 23).asDate
    @State private var hasSleepTime:     Bool = false

    var body: some View {
        NavigationStack {
            List {
                wakeUpSection
                sleepSection
                statusSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
            .onAppear { loadFromVM() }
        }
    }

    // MARK: - Sections

    private var wakeUpSection: some View {
        Section {
            Toggle("Enable wake-up detection", isOn: $detectionEnabled)
                .onChange(of: detectionEnabled) { val in
                    vm.detectionEnabled = val
                }

            if detectionEnabled {
                Stepper("Idle threshold: \(idleHours) hr\(idleHours == 1 ? "" : "s")",
                        value: $idleHours, in: 1...12)
                    .onChange(of: idleHours) { val in vm.idleHours = val }

                DatePicker("Window start",
                           selection: $windowStartDate,
                           displayedComponents: .hourAndMinute)
                    .onChange(of: windowStartDate) { date in
                        vm.windowStart = Calendar.current
                            .dateComponents([.hour, .minute], from: date)
                    }

                DatePicker("Window end",
                           selection: $windowEndDate,
                           displayedComponents: .hourAndMinute)
                    .onChange(of: windowEndDate) { date in
                        vm.windowEnd = Calendar.current
                            .dateComponents([.hour, .minute], from: date)
                    }
            }
        } header: {
            Label("Wake-Up Detection", systemImage: "sunrise")
        } footer: {
            Text("FrictionGate detects wake-up when the phone has been idle for the threshold hours and you open the app within the detection window.")
        }
    }

    private var sleepSection: some View {
        Section {
            Toggle("Set a sleep time", isOn: $hasSleepTime)
                .onChange(of: hasSleepTime) { enabled in
                    if enabled {
                        vm.sleepTime = Calendar.current
                            .dateComponents([.hour, .minute], from: sleepTimeDate)
                    } else {
                        vm.sleepTime = nil
                    }
                }

            if hasSleepTime {
                DatePicker("Sleep time",
                           selection: $sleepTimeDate,
                           displayedComponents: .hourAndMinute)
                    .onChange(of: sleepTimeDate) { date in
                        vm.sleepTime = Calendar.current
                            .dateComponents([.hour, .minute], from: date)
                    }
            }
        } header: {
            Label("Sleep Time", systemImage: "moon.zzz")
        } footer: {
            Text("Used by \"Before Sleep\" blocking conditions. Rules with that condition will apply a shield for the configured duration before this time each night.")
        }
    }

    private var statusSection: some View {
        Section {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text(vm.statusDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Status")
        }
    }

    // MARK: - Load from VM

    private func loadFromVM() {
        detectionEnabled = vm.detectionEnabled
        idleHours        = vm.idleHours
        windowStartDate  = vm.windowStart.asDate
        windowEndDate    = vm.windowEnd.asDate

        if let sleep = vm.sleepTime {
            hasSleepTime   = true
            sleepTimeDate  = sleep.asDate
        } else {
            hasSleepTime   = false
        }
    }
}

// MARK: - DateComponents convenience (file-private factory only)
// `DateComponents.asDate` is defined module-wide in Extensions/Date+Helpers.swift.

private func dc(hour: Int, minute: Int = 0) -> DateComponents {
    DateComponents(hour: hour, minute: minute)
}
