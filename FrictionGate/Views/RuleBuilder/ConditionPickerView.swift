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
        .builderListChrome()
        .onAppear { loadFromVM() }
        .onChange(of: twEnabled)      { _ in sync() }
        .onChange(of: twStart)        { _ in sync() }
        .onChange(of: twEnd)          { _ in sync() }
        .onChange(of: twDays)         { _ in sync() }
        .onChange(of: wakeEnabled)    { _ in sync() }
        .onChange(of: wakeMins)       { _ in sync() }
        .onChange(of: sleepEnabled)   { _ in sync() }
        .onChange(of: sleepTimeDC)    { _ in sync() }
        .onChange(of: sleepDuration)  { _ in sync() }
        .onChange(of: limitEnabled)   { _ in sync() }
        .onChange(of: limitMax)       { _ in sync() }
    }

    // MARK: - Sections

    private var timeWindowSection: some View {
        Section {
            Toggle("Enable time window", isOn: $twEnabled)
                .font(.system(size: 16))
            if twEnabled {
                DatePicker("Start", selection: $twStart, displayedComponents: .hourAndMinute)
                    .font(.system(size: 16))
                DatePicker("End",   selection: $twEnd,   displayedComponents: .hourAndMinute)
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Days")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    DaySetPicker(selection: $twDays)
                }
                .padding(.vertical, 6)
            }
        } header: {
            BuilderSectionHeader(title: "Time Window", icon: "clock")
        } footer: {
            BuilderSectionFooter(text: "Block the app between two times on the selected days.")
        }
        .builderBlock()
    }

    private var afterWakeUpSection: some View {
        Section {
            Toggle("Enable after wake-up block", isOn: $wakeEnabled)
                .font(.system(size: 16))
            if wakeEnabled {
                Stepper("Duration: \(wakeMins) min", value: $wakeMins, in: 5...240, step: 5)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            BuilderSectionHeader(title: "After Wake-Up", icon: "sunrise")
        } footer: {
            BuilderSectionFooter(text: "Blocks the app for a set period after your phone detects you've woken up.")
        }
        .builderBlock()
    }

    private var beforeSleepSection: some View {
        Section {
            Toggle("Enable before-sleep block", isOn: $sleepEnabled)
                .font(.system(size: 16))
            if sleepEnabled {
                DatePicker("Sleep time", selection: $sleepTimeDC, displayedComponents: .hourAndMinute)
                    .font(.system(size: 16))
                Stepper("Duration: \(sleepDuration) min", value: $sleepDuration, in: 5...120, step: 5)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            BuilderSectionHeader(title: "Before Sleep", icon: "moon")
        } footer: {
            BuilderSectionFooter(text: "Blocks the app for a set number of minutes before your configured sleep time.")
        }
        .builderBlock()
    }

    private var dailyLimitSection: some View {
        Section {
            Toggle("Enable daily open limit", isOn: $limitEnabled)
                .font(.system(size: 16))
            if limitEnabled {
                Stepper("Max opens: \(limitMax)", value: $limitMax, in: 1...20)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            BuilderSectionHeader(title: "Daily Open Limit", icon: "chart.bar")
        } footer: {
            BuilderSectionFooter(text: "Blocks the app after it's been opened a set number of times today.")
        }
        .builderBlock()
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.label) { preset in
                    let selected = selection == preset.value
                    Button(preset.label) { selection = preset.value }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected ? AppColors.accentMint : AppColors.inkDeep)
                        .foregroundColor(selected ? AppColors.onAccent : AppColors.textSecondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                selected ? Color.clear : AppColors.inkBorder,
                                lineWidth: 1
                            )
                        )
                }
            }

            HStack(spacing: 6) {
                ForEach(days, id: \.day.rawValue) { item in
                    let selected = selection.contains(item.day)
                    Button(item.label) {
                        if selection.contains(item.day) {
                            selection.remove(item.day)
                        } else {
                            selection.insert(item.day)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selected ? AppColors.accentMint : AppColors.inkDeep)
                    .foregroundColor(selected ? AppColors.onAccent : AppColors.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? Color.clear : AppColors.inkBorder, lineWidth: 1)
                    )
                    .font(.system(size: 12, weight: .medium))
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
