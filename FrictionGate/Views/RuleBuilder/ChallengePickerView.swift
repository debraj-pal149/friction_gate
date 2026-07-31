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
        .builderListChrome()
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
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .padding(.vertical, 6)
        }
        .builderBlock()
    }

    private var stepsSection: some View {
        Section {
            Toggle("Require steps", isOn: $stepsEnabled)
                .font(.system(size: 16))
            if stepsEnabled {
                Stepper("Steps: \(stepsRequired)", value: $stepsRequired, in: 100...10_000, step: 100)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            BuilderSectionHeader(
                title: "Steps Challenge",
                icon: "figure.walk",
                caption: frictionCaption(for: UnlockChallenge.steps(required: stepsRequired).difficultyTier)
            )
        } footer: {
            BuilderSectionFooter(text: "Walk a set number of steps before the block lifts.")
        }
        .builderBlock()
    }

    private var mathsSection: some View {
        Section {
            Toggle("Require maths", isOn: $mathsEnabled)
                .font(.system(size: 16))
            if mathsEnabled {
                Stepper("Problems: \(mathsCount)", value: $mathsCount, in: 1...20)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            BuilderSectionHeader(
                title: "Maths Challenge",
                icon: "function",
                caption: frictionCaption(for: UnlockChallenge.maths(count: mathsCount).difficultyTier)
            )
        } footer: {
            BuilderSectionFooter(text: "Solve arithmetic problems. Difficulty scales with escalation.")
        }
        .builderBlock()
    }

    private var typeSentenceSection: some View {
        Section {
            Toggle("Require typing a sentence", isOn: $typeEnabled)
                .font(.system(size: 16))
            if typeEnabled {
                TextField("Sentence to type", text: $typeSentence, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(2...4)
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            BuilderSectionHeader(
                title: "Type Sentence",
                icon: "keyboard",
                caption: frictionCaption(for: UnlockChallenge.typeSentence(sentence: effectiveTypeSentence).difficultyTier)
            )
        } footer: {
            BuilderSectionFooter(text: "Must be typed exactly, character by character. Paste is disabled.")
        }
        .builderBlock()
    }

    private var waitSection: some View {
        Section {
            Toggle("Require a wait", isOn: $waitEnabled)
                .font(.system(size: 16))
            if waitEnabled {
                Stepper("Wait: \(waitMinutes) min", value: $waitMinutes, in: 1...60)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appPrimary)
            }
        } header: {
            BuilderSectionHeader(
                title: "Wait Challenge",
                icon: "timer",
                caption: frictionCaption(for: UnlockChallenge.wait(minutes: waitMinutes).difficultyTier)
            )
        } footer: {
            BuilderSectionFooter(text: "Countdown timer. The app stays locked until it reaches zero.")
        }
        .builderBlock()
    }

    private var writeReasonSection: some View {
        Section {
            Toggle("Require written justification", isOn: $reasonEnabled)
                .font(.system(size: 16))
        } header: {
            BuilderSectionHeader(
                title: "Write a Reason",
                icon: "pencil.and.list.clipboard",
                caption: frictionCaption(for: UnlockChallenge.writeReason.difficultyTier)
            )
        } footer: {
            BuilderSectionFooter(text: "Ask for a short reason why you want to unlock. Adds friction through self-reflection.")
        }
        .builderBlock()
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

    private func frictionCaption(for tier: ChallengeDifficultyTier) -> String {
        switch tier {
        case .easy: return "light friction"
        case .medium: return "moderate friction"
        case .hard: return "serious friction"
        case .extreme: return "extreme friction"
        }
    }
}
