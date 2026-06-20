import SwiftUI

/// Dispatcher that creates an `UnlockViewModel` for the given rule and shows
/// the appropriate challenge sub-view.  Presented as a `.sheet`.
struct UnlockView: View {

    @StateObject private var vm: UnlockViewModel
    @Environment(\.dismiss) private var dismiss

    init(rule: Rule, ruleStore: RuleStore) {
        _vm = StateObject(wrappedValue: UnlockViewModel(rule: rule, ruleStore: ruleStore))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Escalation banner
                if vm.isEscalating {
                    escalationBanner
                }

                // Progress bar (when more than one challenge)
                if vm.totalChallenges > 1 {
                    VStack(spacing: 4) {
                        ProgressView(
                            value: Double(vm.currentChallengeIndex),
                            total: Double(vm.totalChallenges)
                        )
                        .tint(.blue)
                        .padding(.horizontal)

                        Text("Challenge \(vm.currentChallengeIndex + 1) of \(vm.totalChallenges)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    Divider()
                }

                // Challenge content
                Group {
                    if vm.isUnlocked {
                        unlockSuccessView
                    } else {
                        switch vm.currentChallenge {
                        case .steps(let required):
                            StepChallengeView(vm: vm, required: required)
                        case .maths:
                            MathsChallengeView(vm: vm)
                        case .typeSentence:
                            TypeSentenceView(vm: vm)
                        case .wait:
                            WaitChallengeView(vm: vm)
                        case .writeReason:
                            WriteReasonView(vm: vm)
                        case nil:
                            unlockSuccessView
                        }
                    }
                }
            }
            .navigationTitle("Unlock \(vm.rule.appDisplayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !vm.isUnlocked {
                        Button("Cancel") {
                            vm.abandon()
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .onChange(of: vm.isUnlocked) { unlocked in
                if unlocked {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        dismiss()
                    }
                }
            }
        }
        .onDisappear { vm.abandon() }
    }

    // MARK: - Shared subviews

    private var escalationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
            Text("Escalation active — \(vm.currentMultiplier)× difficulty")
                .font(.subheadline.bold())
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.orange)
    }

    private var unlockSuccessView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            Text("Unlocked!")
                .font(.largeTitle.bold())
            Text("\(vm.rule.appDisplayName) is now unblocked.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}
