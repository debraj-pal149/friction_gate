import SwiftUI

struct UnlockView: View {

    @StateObject private var vm: UnlockViewModel
    @Environment(\.dismiss) private var dismiss

    init(rule: Rule, ruleStore: RuleStore) {
        _vm = StateObject(wrappedValue: UnlockViewModel(rule: rule, ruleStore: ruleStore))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if vm.isEscalating {
                        escalationBanner
                    }

                    if vm.totalChallenges > 1 {
                        progressSection
                    }

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
                        .foregroundStyle(Color.appDestructive)
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

    // MARK: - Escalation banner

    private var escalationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.subheadline)
            Text("Escalation active · \(vm.currentMultiplier)× harder")
                .font(.subheadline.bold())
        }
        .foregroundStyle(Color.appPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.appWarning.opacity(0.85))
    }

    // MARK: - Multi-challenge progress

    @ViewBuilder
    private var progressSection: some View {
        VStack(spacing: 6) {
            ProgressView(
                value: Double(vm.currentChallengeIndex),
                total: Double(vm.totalChallenges)
            )
            .tint(Color.appAccent)
            .padding(.horizontal)

            Text("Challenge \(vm.currentChallengeIndex + 1) of \(vm.totalChallenges)")
                .font(.caption)
                .foregroundStyle(Color.appSecondary)
        }
        .padding(.vertical, 12)
        .background(Color.appSurface)

        Divider().background(Color.appBorder)
    }

    // MARK: - Success state

    private var unlockSuccessView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.appSuccess.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(Color.appSuccess)
            }
            .shadow(color: Color.appSuccess.opacity(0.4), radius: 20, x: 0, y: 0)

            VStack(spacing: 8) {
                Text("Unlocked")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.appPrimary)
                Text("\(vm.rule.appDisplayName) is now unblocked.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondary)
            }

            Spacer()
        }
        .padding()
    }
}
