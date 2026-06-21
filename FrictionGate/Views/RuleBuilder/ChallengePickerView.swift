import SwiftUI

struct ChallengePickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel

    // Steps
    @State private var stepsEnabled  = false
    @State private var stepsRequired = 1_000

    // Maths
    @State private var mathsEnabled = false
    @State private var mathsCount   = 5

    // Type sentence
    @State private var typeEnabled  = false
    @State private var typeSentence = "I am choosing to use this time intentionally."

    // Wait
    @State private var waitEnabled = false
    @State private var waitMinutes = 5

    // Write reason
    @State private var reasonEnabled = false

    var body: some View {
        List {
            stepsSection
            mathsSection
            typeSentenceSection
            waitSection
            writeReasonSection
        }
        .listStyle(.insetGrouped)
        .onAppear { loadFromVM() }
    }

    // MARK: - Sections

    private var stepsSection: some View {
        Section {
            Toggle("Require steps", isOn: $stepsEnabled.didSet { _ in sync() })
            if stepsEnabled {
                Stepper("Steps: \(stepsRequired)",
                        value: $stepsRequired.didSet { _ in sync() },
                        in: 100...10_000, step: 100)
            }
        } header: {
            Label("Steps Challenge", systemImage: "figure.walk")
        } footer: {
            Text("Walk a set number of steps before the block lifts. Measured from the moment you request the unlock.")
        }
    }

    private var mathsSection: some View {
        Section {
            Toggle("Require maths", isOn: $mathsEnabled.didSet { _ in sync() })
            if mathsEnabled {
                Stepper("Problems: \(mathsCount)",
                        value: $mathsCount.didSet { _ in sync() },
                        in: 1...20)
            }
        } header: {
            Label("Maths Challenge", systemImage: "function")
        } footer: {
            Text("Solve a set of arithmetic problems (addition, subtraction, multiplication). Difficulty scales with escalation.")
        }
    }

    private var typeSentenceSection: some View {
        Section {
            Toggle("Require typing a sentence", isOn: $typeEnabled.didSet { _ in sync() })
            if typeEnabled {
                TextField("Sentence to type", text: $typeSentence.didSet { _ in sync() }, axis: .vertical)
                    .lineLimit(2...4)
            }
        } header: {
            Label("Type Sentence", systemImage: "keyboard")
        } footer: {
            Text("The user must type a pre-set sentence exactly, character-by-character, with paste disabled. Slows impulsive unlocks.")
        }
    }

    private var waitSection: some View {
        Section {
            Toggle("Require a wait", isOn: $waitEnabled.didSet { _ in sync() })
            if waitEnabled {
                Stepper("Wait: \(waitMinutes) min",
                        value: $waitMinutes.didSet { _ in sync() },
                        in: 1...60)
            }
        } header: {
            Label("Wait Challenge", systemImage: "timer")
        } footer: {
            Text("Start a countdown timer. The app stays locked until the timer reaches zero. Great for a 5-minute pause before giving in.")
        }
    }

    private var writeReasonSection: some View {
        Section {
            Toggle("Require written justification", isOn: $reasonEnabled.didSet { _ in sync() })
        } header: {
            Label("Write a Reason", systemImage: "pencil.and.list.clipboard")
        } footer: {
            Text("Ask the user to write a short reason for why they want to unlock. No verification, just adds friction and self-reflection.")
        }
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
            case .steps(let n):
                stepsEnabled  = true
                stepsRequired = n
            case .maths(let c):
                mathsEnabled = true
                mathsCount   = c
            case .typeSentence(let s):
                typeEnabled  = true
                typeSentence = s
            case .wait(let m):
                waitEnabled  = true
                waitMinutes  = m
            case .writeReason:
                reasonEnabled = true
            }
        }
    }
}
