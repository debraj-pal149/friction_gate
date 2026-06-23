import SwiftUI

struct ChallengePickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel

    @State private var stepsEnabled  = false
    @State private var stepsRequired = 1_000

    @State private var mathsEnabled = false
    @State private var mathsCount   = 5

    @State private var typeEnabled  = false
    @State private var typeSentence = "I am choosing to use this time intentionally."

    @State private var waitEnabled = false
    @State private var waitMinutes = 5

    @State private var reasonEnabled = false

    var body: some View {
        List {
            stepsSection
            mathsSection
            typeSentenceSection
            waitSection
            writeReasonSection
        }
        .inkBackground()
        .listStyle(.insetGrouped)
        .onAppear { loadFromVM() }
        .onChange(of: stepsEnabled)   { _ in sync() }
        .onChange(of: stepsRequired)  { _ in sync() }
        .onChange(of: mathsEnabled)   { _ in sync() }
        .onChange(of: mathsCount)     { _ in sync() }
        .onChange(of: typeEnabled)    { _ in sync() }
        .onChange(of: typeSentence)   { _ in sync() }
        .onChange(of: waitEnabled)    { _ in sync() }
        .onChange(of: waitMinutes)    { _ in sync() }
        .onChange(of: reasonEnabled)  { _ in sync() }
    }

    // MARK: - Sections

    private var stepsSection: some View {
        Section {
            Toggle("Require steps", isOn: $stepsEnabled)
            if stepsEnabled {
                Stepper("Steps: \(stepsRequired)", value: $stepsRequired, in: 100...10_000, step: 100)
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            Label("Steps Challenge", systemImage: "figure.walk")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text("Walk a set number of steps before the block lifts.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    private var mathsSection: some View {
        Section {
            Toggle("Require maths", isOn: $mathsEnabled)
            if mathsEnabled {
                Stepper("Problems: \(mathsCount)", value: $mathsCount, in: 1...20)
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            Label("Maths Challenge", systemImage: "function")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text("Solve arithmetic problems. Difficulty scales with escalation.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    private var typeSentenceSection: some View {
        Section {
            Toggle("Require typing a sentence", isOn: $typeEnabled)
            if typeEnabled {
                TextField("Sentence to type", text: $typeSentence, axis: .vertical)
                    .lineLimit(2...4)
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            Label("Type Sentence", systemImage: "keyboard")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text("Must be typed exactly, character by character. Paste is disabled.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    private var waitSection: some View {
        Section {
            Toggle("Require a wait", isOn: $waitEnabled)
            if waitEnabled {
                Stepper("Wait: \(waitMinutes) min", value: $waitMinutes, in: 1...60)
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            Label("Wait Challenge", systemImage: "timer")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text("Countdown timer. The app stays locked until it reaches zero.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    private var writeReasonSection: some View {
        Section {
            Toggle("Require written justification", isOn: $reasonEnabled)
        } header: {
            Label("Write a Reason", systemImage: "pencil.and.list.clipboard")
                .foregroundStyle(Color.appSecondary)
        } footer: {
            Text("Ask for a short reason why you want to unlock. Adds friction through self-reflection.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    // MARK: - Sync

    private func sync() {
        var challenges: [UnlockChallenge] = []
        if stepsEnabled { challenges.append(.steps(required: stepsRequired)) }
        if mathsEnabled { challenges.append(.maths(count: mathsCount)) }
        if typeEnabled && !typeSentence.trimmingCharacters(in: .whitespaces).isEmpty {
            challenges.append(.typeSentence(sentence: typeSentence))
        }
        if waitEnabled   { challenges.append(.wait(minutes: waitMinutes)) }
        if reasonEnabled { challenges.append(.writeReason) }
        vm.challenges = challenges
    }

    private func loadFromVM() {
        for challenge in vm.challenges {
            switch challenge {
            case .steps(let n):        stepsEnabled = true;  stepsRequired = n
            case .maths(let c):        mathsEnabled = true;  mathsCount = c
            case .typeSentence(let s): typeEnabled  = true;  typeSentence = s
            case .wait(let m):         waitEnabled  = true;  waitMinutes = m
            case .writeReason:         reasonEnabled = true
            }
        }
    }
}
