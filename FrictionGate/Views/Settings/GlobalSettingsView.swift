import SwiftUI

struct GlobalSettingsView: View {

    @ObservedObject var vm: WakeUpViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var detectionEnabled: Bool = false
    @State private var idleHours:        Int  = 6
    @State private var windowStartDate:  Date = dc(hour: 5).asDate
    @State private var windowEndDate:    Date = dc(hour: 11).asDate
    @State private var sleepTimeDate:    Date = dc(hour: 23).asDate
    @State private var hasSleepTime:     Bool = false
    @State private var showAbout = false

    private var isDarkModeActive: Bool {
        (appState.colorSchemeOverride ?? systemColorScheme) == .dark
    }

    var body: some View {
        NavigationStack {
            List {
                wakeUpSection
                sleepSection
                appearanceSection
                statusSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.inkBase)
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accentMint)
                }
            }
            .toolbarBackground(AppColors.inkBase, for: .navigationBar)
            .onAppear { loadFromVM() }
            .sheet(isPresented: $showAbout) {
                AboutFrictionView()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var wakeUpSection: some View {
        Section {
            Toggle("Enable wake-up detection", isOn: $detectionEnabled)
                .tint(AppColors.accentMint)
                .onChange(of: detectionEnabled) { val in vm.detectionEnabled = val }

            if detectionEnabled {
                Stepper("Idle threshold: \(idleHours) hr\(idleHours == 1 ? "" : "s")",
                        value: $idleHours, in: 1...12)
                    .onChange(of: idleHours) { val in vm.idleHours = val }
                    .foregroundColor(AppColors.textPrimary)

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
            Text("WAKE-UP DETECTION")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(AppColors.textDim)
        } footer: {
            Text("Wake detection uses your sleep data and morning app usage to detect when you've woken up. Works best with Apple Watch.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textGhost)
        }
        .listRowBackground(AppColors.inkSurface)
        .listRowSeparatorTint(AppColors.inkDeep)
    }

    private var sleepSection: some View {
        Section {
            Toggle("Set a sleep time", isOn: $hasSleepTime)
                .tint(AppColors.accentMint)
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
            Text("SLEEP TIME")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(AppColors.textDim)
        } footer: {
            Text("Used by Before Sleep blocking conditions.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textGhost)
        }
        .listRowBackground(AppColors.inkSurface)
        .listRowSeparatorTint(AppColors.inkDeep)
    }

    private var appearanceSection: some View {
        Section {
            Button {
                appState.toggleColorScheme(using: systemColorScheme)
            } label: {
                HStack {
                    Text(isDarkModeActive ? "Dark appearance" : "Light appearance")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: isDarkModeActive ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(AppColors.accentMint)
                }
            }
        } header: {
            Text("APPEARANCE")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(AppColors.textDim)
        } footer: {
            Text("Friction uses an ink palette in both modes. This toggles system chrome preference.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textGhost)
        }
        .listRowBackground(AppColors.inkSurface)
        .listRowSeparatorTint(AppColors.inkDeep)
    }

    private var statusSection: some View {
        Section {
            Text(vm.statusDescription)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        } header: {
            Text("STATUS")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(AppColors.textDim)
        }
        .listRowBackground(AppColors.inkSurface)
    }

    private var aboutSection: some View {
        Section {
            Button {
                showAbout = true
            } label: {
                HStack {
                    Text("About Friction")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.inkBorder)
                }
            }
        }
        .listRowBackground(AppColors.inkSurface)
    }

    private func loadFromVM() {
        detectionEnabled = vm.detectionEnabled
        idleHours        = vm.idleHours
        windowStartDate  = vm.windowStart.asDate
        windowEndDate    = vm.windowEnd.asDate

        if let sleep = vm.sleepTime {
            hasSleepTime  = true
            sleepTimeDate = sleep.asDate
        } else {
            hasSleepTime = false
        }
    }
}

private func dc(hour: Int, minute: Int = 0) -> DateComponents {
    DateComponents(hour: hour, minute: minute)
}
