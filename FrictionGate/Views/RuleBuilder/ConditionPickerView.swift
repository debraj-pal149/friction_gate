import SwiftUI

struct ConditionPickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel

    // Time window state
    @State private var twEnabled  = false
    @State private var twStart    = dc(hour: 9,  minute: 0).asDate
    @State private var twEnd      = dc(hour: 18, minute: 0).asDate
    @State private var twDays: DaySet = .weekdays

    // After wake-up state
    @State private var wakeEnabled  = false
    @State private var wakeMins     = 60

    // Before sleep state
    @State private var sleepEnabled  = false
    @State private var sleepTimeDC   = dc(hour: 23, minute: 0).asDate
    @State private var sleepDuration = 30

    // Daily open limit state
    @State private var limitEnabled = false
    @State private var limitMax     = 3

    var body: some View {
        List {
            timeWindowSection
            afterWakeUpSection
            beforeSleepSection
            dailyLimitSection
        }
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days").foregroundColor(.secondary)
                    DaySetPicker(selection: $twDays.didSet { _ in sync() })
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Time Window", systemImage: "clock")
        } footer: {
            Text("Block the app between two times on the selected days. Perfect for work hours or bedtime routines.")
        }
    }

    private var afterWakeUpSection: some View {
        Section {
            Toggle("Enable after wake-up block", isOn: $wakeEnabled.didSet { _ in sync() })
            if wakeEnabled {
                Stepper("Duration: \(wakeMins) min",
                        value: $wakeMins.didSet { _ in sync() },
                        in: 5...240, step: 5)
            }
        } header: {
            Label("After Wake-Up", systemImage: "sunrise")
        } footer: {
            Text("Blocks the app for a set period after your phone detects you've woken up (based on idle time). Great for a phone-free morning.")
        }
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
            }
        } header: {
            Label("Before Sleep", systemImage: "moon")
        } footer: {
            Text("Blocks the app for a set number of minutes before your configured sleep time. Wind down without distractions.")
        }
    }

    private var dailyLimitSection: some View {
        Section {
            Toggle("Enable daily open limit", isOn: $limitEnabled.didSet { _ in sync() })
            if limitEnabled {
                Stepper("Max opens: \(limitMax)",
                        value: $limitMax.didSet { _ in sync() },
                        in: 1...20)
            }
        } header: {
            Label("Daily Open Limit", systemImage: "chart.bar")
        } footer: {
            Text("Blocks the app after it's been opened a set number of times today. Curbs habitual checking.")
        }
    }

    // MARK: - Sync

    private func sync() {
        var conditions: [BlockCondition] = []
        if twEnabled {
            let start = Calendar.current.dateComponents([.hour, .minute], from: twStart)
            let end   = Calendar.current.dateComponents([.hour, .minute], from: twEnd)
            conditions.append(.timeWindow(start: start, end: end, days: twDays))
        }
        if wakeEnabled {
            conditions.append(.afterWakeUp(durationMinutes: wakeMins))
        }
        if sleepEnabled {
            let sleepDC = Calendar.current.dateComponents([.hour, .minute], from: sleepTimeDC)
            conditions.append(.beforeSleep(sleepTime: sleepDC, durationMinutes: sleepDuration))
        }
        if limitEnabled {
            conditions.append(.dailyOpenLimit(maxOpens: limitMax))
        }
        vm.conditions = conditions
    }

    private func loadFromVM() {
        for condition in vm.conditions {
            switch condition {
            case .timeWindow(let start, let end, let days):
                twEnabled = true
                twStart   = start.asDate
                twEnd     = end.asDate
                twDays    = days
            case .afterWakeUp(let mins):
                wakeEnabled = true
                wakeMins    = mins
            case .beforeSleep(let sleepDC, let mins):
                sleepEnabled   = true
                sleepTimeDC    = sleepDC.asDate
                sleepDuration  = mins
            case .dailyOpenLimit(let max):
                limitEnabled = true
                limitMax     = max
            }
        }
    }
}

// MARK: - Day picker

private struct DaySetPicker: View {
    @Binding var selection: DaySet

    private let days: [(String, DaySet)] = [
        ("M", .monday), ("T", .tuesday), ("W", .wednesday),
        ("Th", .thursday), ("F", .friday), ("Sa", .saturday), ("Su", .sunday)
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.1.rawValue) { label, day in
                Button(label) {
                    if selection.contains(day) { selection.remove(day) }
                    else { selection.insert(day) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(selection.contains(day) ? Color.blue : Color(.tertiarySystemFill))
                .foregroundColor(selection.contains(day) ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .font(.caption.bold())
            }
        }
    }
}

// MARK: - DateComponents convenience (file-private factory only)
// `DateComponents.asDate` is defined module-wide in Extensions/Date+Helpers.swift.

private func dc(hour: Int, minute: Int = 0) -> DateComponents {
    DateComponents(hour: hour, minute: minute)
}

// MARK: - Binding didSet helper

extension Binding {
    /// Adds a side effect whenever the binding's value is set.
    func didSet(_ action: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in self.wrappedValue = newValue; action(newValue) }
        )
    }
}
