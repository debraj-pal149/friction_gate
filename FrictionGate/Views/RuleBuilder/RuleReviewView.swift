import SwiftUI

struct RuleReviewView: View {

    @ObservedObject var vm: RuleBuilderViewModel
    let onSave: () -> Void

    var body: some View {
        List {
            Section {
                Text(vm.reviewSummary)
                    .font(.body)
                    .lineSpacing(5)
                    .padding(.vertical, 4)
            } header: {
                Label("Rule Summary", systemImage: "doc.text")
            }

            // Quick-view of conditions
            if !vm.conditions.isEmpty {
                Section("Conditions") {
                    ForEach(vm.conditions.indices, id: \.self) { i in
                        Label(vm.conditions[i].displayDescription,
                              systemImage: conditionIcon(vm.conditions[i]))
                            .font(.subheadline)
                    }
                }
            }

            // Quick-view of challenges
            if !vm.challenges.isEmpty {
                Section("Challenges") {
                    ForEach(vm.challenges.indices, id: \.self) { i in
                        Label(vm.challenges[i].longDescription,
                              systemImage: challengeIcon(vm.challenges[i]))
                            .font(.subheadline)
                    }
                }
            }

            Section {
                Button {
                    onSave()
                } label: {
                    HStack {
                        Spacer()
                        Label("Save Rule", systemImage: "checkmark.shield.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(vm.isValid ? Color.blue : Color(.systemFill))
                .disabled(!vm.isValid)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Icon helpers

    private func conditionIcon(_ condition: BlockCondition) -> String {
        switch condition {
        case .timeWindow:      return "clock"
        case .afterWakeUp:     return "sunrise"
        case .beforeSleep:     return "moon"
        case .dailyOpenLimit:  return "chart.bar"
        }
    }

    private func challengeIcon(_ challenge: UnlockChallenge) -> String {
        switch challenge {
        case .steps:        return "figure.walk"
        case .maths:        return "function"
        case .typeSentence: return "keyboard"
        case .wait:         return "timer"
        case .writeReason:  return "pencil.and.list.clipboard"
        }
    }
}

// MARK: - UnlockChallenge long description (used in the review screen)

extension UnlockChallenge {
    /// Full one-line description shown in the review screen's challenge list.
    var longDescription: String {
        switch self {
        case .steps(let n):        return "Walk \(n) steps"
        case .maths(let c):        return "Solve \(c) maths problem\(c == 1 ? "" : "s")"
        case .typeSentence(let s): return "Type: \u{201C}\(s)\u{201D}"
        case .wait(let m):         return "Wait \(m) minute\(m == 1 ? "" : "s")"
        case .writeReason:         return "Write a reason"
        }
    }
}
