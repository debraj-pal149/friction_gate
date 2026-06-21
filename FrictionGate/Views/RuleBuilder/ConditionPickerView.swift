import SwiftUI

struct ConditionPickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel

    @State private var twEnabled  = false
    @State private var twStart    = dc(hour: 9,  minute: 0).asDate
    @State private var twEnd      = dc(hour: 18, minute: 0).asDate
    @State private var twDays: DaySet = .weekdays

    @State private var wakeEnabled  = false
    @State private var wakeMins     = 60

    @State private var sleepEnabled  = false
    @State private var sleepTimeDC   = dc(hour: 23, minute: 0).asDate
    @State private var sleepDuration = 30

    @State private var limitEnabled = false
    @State private var limitMax     = 3

    var body: some View {
        List {
            timeWindowSection
            afterWakeUpSection
            beforeSleepSection
            dailyLimitSection
        }
        .inkBackground()
        .listStyle(.insetGrouped)
        .onAppear { loadFromVM() }
    }

    // MARK: - Sections

    private var timeWindowSection: some View {
        Section {
            Toggle("Enable time window", isOn: $twEnabled.didSet { _ in sync() })
            if twEnabled {
                DatePicker("Start", selection: $twStart.didSet { _ in sync() },
                           displayedComponents: .hourAndMinute)
                DatePicker("End",   selection: $twEnd.didSet { _ in sync() },
                           displayedComponents: .hourAndMinute)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Days").foregroundStyle(Color.appSecondary)
                    DaySetPicker(selection: $twDays.didSet { _ in sync() })
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Time Window", systemImage: "clock")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text("Block the app between two times on the selected days.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    private var afterWakeUpSection: some View {
        Section {
            Toggle("Enable after wake-up block", isOn: $wakeEnabled.didSet { _ in sync() })
            if wakeEnabled {
                Stepper("Duration: \(wakeMins) min",
                        value: $wakeMins.didSet { _ in sync() },
                        in: 5...240, step: 5)
                .foregroundStyle(Color.appPrimary)
            }
        } header: {
            Label("After Wake-Up", systemImage: "sunrise")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text("Blocks the app for a set period after your phone detects you've woken up.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    private var beforeSleepSection: some View {
        Section {
            Toggle("Enable before-sleep block", isOn: $sleepEnabled.didSet { _ in sync() })
            if sleepEnabled {
                DatePicker("Sleep time", selection: $sleepTimeDC.didSet { _ in sync() },
                           displayedComponents: .hourAndMinute)
                Stepper("Duration: \(sleepDuration) min",
                        value: $sleepDuration.didSet { _ in sync() },
                        in: 5...120, step: 5)
                .foregroundStyle(Color.appPrimary)
            }
        } header: {
            Label("Before Sleep", systemImage: "moon")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text("Blocks the app for a set number of minutes before your configured sleep time.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    private var dailyLimitSection: some View {
        Section {
            Toggle("Enable daily open limit", isOn: $limitEnabled.didSet { _ in sync() })
            if limitEnabled {
                Stepper("Max opens: \(limitMax)",
                        value: $limitMax.didSet { _ in sync() },
                        in: 1...20)
                .foregroundStyle(Color.appPrimary)
            }
        } header: {
            Label("Daily Open Limit", systemImage: "chart.bar")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text("Blocks the app after it's been opened a set number of times today.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    // MARK: - Sync

    private func sync() {
        var conditions: [BlockCondition] = []
        if twEnabled {
            let start = Calendar.current.dateComponents([.hour, .minute], from: twStart)
            let end   = Calendar.current.dateComponents([.hour, .minute], from: twEnd)
            conditions.append(.timeWindow(start: start, end: end, days: twDays))
        }
        if wakeEnabled  { conditions.append(.afterWakeUp(durationMinutes: wakeMins)) }
        if sleepEnabled {
            let sleepDC = Calendar.current.dateComponents([.hour, .minute], from: sleepTimeDC)
            conditions.append(.beforeSleep(sleepTime: sleepDC, durationMinutes: sleepDuration))
        }
        if limitEnabled { conditions.append(.dailyOpenLimit(maxOpens: limitMax)) }
        vm.conditions = conditions
    }

    private func loadFromVM() {
        for condition in vm.conditions {
            switch condition {
            case .timeWindow(let start, let end, let days):
                twEnabled = true; twStart = start.asDate; twEnd = end.asDate; twDays = days
            case .afterWakeUp(let mins):
                wakeEnabled = true; wakeMins = mins
            case .beforeSleep(let sleepDC, let mins):
                sleepEnabled = true; sleepTimeDC = sleepDC.asDate; sleepDuration = mins
            case .dailyOpenLimit(let max):
                limitEnabled = true; limitMax = max
            }
        }
    }
}

// MARK: - Day picker

private struct DaySetPicker: View {
    @Binding var selection: DaySet

    private let days: [(label: String, day: DaySet)] = [
        ("M", .monday), ("T", .tuesday), ("W", .wednesday),
        ("Th", .thursday), ("F", .friday), ("Sa", .saturday), ("Su", .sunday)
    ]

    private let presets: [(label: String, value: DaySet)] = [
        ("Every day", .everyday),
        ("Weekdays",  .weekdays),
        ("Weekends",  [.saturday, .sunday]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.label) { preset in
                    Button(preset.label) { selection = preset.value }
                        .buttonStyle(.plain)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selection == preset.value
                                ? Color.appAccent
                                : Color.appSurface3
                        )
                        .foregroundStyle(
                            selection == preset.value
                                ? Color.appPrimary
                                : Color.appSecondary
                        )
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 4) {
                ForEach(days, id: \.day.rawValue) { item in
                    Button(item.label) {
                        if selection.contains(item.day) {
                            selection.remove(item.day)
                        } else {
                            selection.insert(item.day)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        selection.contains(item.day)
                            ? Color.appAccent
                            : Color.appSurface3
                    )
                    .foregroundStyle(
                        selection.contains(item.day)
                            ? Color.appPrimary
                            : Color.appSecondary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .font(.caption.bold())
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - DateComponents convenience

private func dc(hour: Int, minute: Int = 0) -> DateComponents {
    DateComponents(hour: hour, minute: minute)
}

// MARK: - Binding didSet helper

extension Binding {
    func didSet(_ action: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in self.wrappedValue = newValue; action(newValue) }
        )
    }
}
