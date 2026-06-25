import SwiftUI

struct ChallengePickerView: View {

    @ObservedObject var vm: RuleBuilderViewModel

    @State private var stepsEnabled  = false
    @State private var stepsRequired = 200

    @State private var mathsEnabled = false
    @State private var mathsCount   = 5

    @State private var typeEnabled  = false
    @State private var typeSentence = "I am choosing to use this time intentionally."

    @State private var waitEnabled = false
    @State private var waitMinutes = 5

    @State private var reasonEnabled = false

    private enum ChallengeKind: CaseIterable, Hashable {
        case wait
        case writeReason
        case typeSentence
        case maths
        case steps
    }

    var body: some View {
        List {
            orderingNoteSection
            ForEach(orderedChallengeKinds, id: \.self) { kind in
                challengeSection(for: kind)
            }
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

    private var orderingNoteSection: some View {
        Section {
            Text("Top is easiest. Difficulty increases as you go down.")
                .font(.footnote)
                .foregroundStyle(Color.appTertiary)
                .padding(.vertical, 2)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    private var stepsSection: some View {
        Section {
            Toggle("Require steps", isOn: $stepsEnabled)
            if stepsEnabled {
                Stepper("Steps: \(stepsRequired)", value: $stepsRequired, in: 100...10_000, step: 100)
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            sectionHeader("Steps Challenge", icon: "figure.walk", challenge: .steps(required: stepsRequired))
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
            sectionHeader("Maths Challenge", icon: "function", challenge: .maths(count: mathsCount))
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
            sectionHeader("Type Sentence", icon: "keyboard", challenge: .typeSentence(sentence: effectiveTypeSentence))
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
            sectionHeader("Wait Challenge", icon: "timer", challenge: .wait(minutes: waitMinutes))
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
            sectionHeader("Write a Reason", icon: "pencil.and.list.clipboard", challenge: .writeReason)
        } footer: {
            Text("Ask for a short reason why you want to unlock. Adds friction through self-reflection.")
                .foregroundStyle(Color.appTertiary)
        }
        .surfaceRow()
        .listRowSeparatorTint(Color.appBorder)
    }

    // MARK: - Sync

    private var orderedChallengeKinds: [ChallengeKind] {
        ChallengeKind.allCases.sorted { lhs, rhs in
            let left = previewChallenge(for: lhs)
            let right = previewChallenge(for: rhs)
            if left.difficultyScore == right.difficultyScore {
                return left.displayName < right.displayName
            }
            return left.difficultyScore < right.difficultyScore
        }
    }

    @ViewBuilder
    private func challengeSection(for kind: ChallengeKind) -> some View {
        switch kind {
        case .steps:
            stepsSection
        case .maths:
            mathsSection
        case .typeSentence:
            typeSentenceSection
        case .wait:
            waitSection
        case .writeReason:
            writeReasonSection
        }
    }

    private func previewChallenge(for kind: ChallengeKind) -> UnlockChallenge {
        switch kind {
        case .steps:
            return .steps(required: stepsRequired)
        case .maths:
            return .maths(count: mathsCount)
        case .typeSentence:
            return .typeSentence(sentence: effectiveTypeSentence)
        case .wait:
            return .wait(minutes: waitMinutes)
        case .writeReason:
            return .writeReason
        }
    }

    private func sync() {
        var challenges: [UnlockChallenge] = []
        if stepsEnabled { challenges.append(.steps(required: stepsRequired)) }
        if mathsEnabled { challenges.append(.maths(count: mathsCount)) }
        if typeEnabled && !typeSentence.trimmingCharacters(in: .whitespaces).isEmpty {
            challenges.append(.typeSentence(sentence: typeSentence))
        }
        if waitEnabled   { challenges.append(.wait(minutes: waitMinutes)) }
        if reasonEnabled { challenges.append(.writeReason) }
        vm.challenges = challenges.sorted { lhs, rhs in
            if lhs.difficultyScore == rhs.difficultyScore {
                return lhs.displayName < rhs.displayName
            }
            return lhs.difficultyScore < rhs.difficultyScore
        }
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

    private var effectiveTypeSentence: String {
        let trimmed = typeSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Type a sentence" : typeSentence
    }

    private func sectionHeader(_ title: String, icon: String, challenge: UnlockChallenge) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: icon)
                .foregroundStyle(Color.appSecondary)
            Spacer(minLength: 8)
            ThemeBadge(text: challenge.difficultyTier.compactLabel,
                       color: color(for: challenge.difficultyTier))
        }
    }

    private func color(for tier: ChallengeDifficultyTier) -> Color {
        switch tier {
        case .easy: return Color.appSuccess
        case .medium: return Color.appAccent
        case .hard: return Color.appWarning
        case .extreme: return Color.appDestructive
        }
    }
}
