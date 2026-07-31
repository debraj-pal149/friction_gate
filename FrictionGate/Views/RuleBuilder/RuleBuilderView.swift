import SwiftUI

/// Root container for the 5-step rule creation flow.
struct RuleBuilderView: View {

    @StateObject private var vm: RuleBuilderViewModel
    @Environment(\.dismiss) private var dismiss

    init(ruleStore: RuleStore, wakeUpDetector: WakeUpDetector) {
        _vm = StateObject(wrappedValue: RuleBuilderViewModel(
            ruleStore: ruleStore,
            wakeUpDetector: wakeUpDetector
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            stepHeader

            Rectangle()
                .fill(AppColors.inkDeep)
                .frame(height: 1)

            Group {
                switch vm.currentStep {
                case .appPicker:
                    AppPickerView(vm: vm)
                case .conditionPicker:
                    ConditionPickerView(vm: vm)
                case .challengePicker:
                    ChallengePickerView(vm: vm)
                case .escalation:
                    EscalationPickerView(vm: vm)
                case .review:
                    RuleReviewView(vm: vm, onSave: {
                        if vm.save() {
                            dismiss()
                        }
                    })
                }
            }

            if vm.currentStep != .review {
                bottomNav
            }
        }
        .background(AppColors.inkBase)
        .preferredColorScheme(.dark)
        .alert(
            "Overlapping Rule",
            isPresented: Binding(
                get: { vm.ruleConflictMessage != nil },
                set: { if !$0 { vm.ruleConflictMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                vm.ruleConflictMessage = nil
            }
        } message: {
            Text(vm.ruleConflictMessage ?? "")
        }
    }

    // MARK: - Step header

    private var stepHeader: some View {
        HStack {
            Text("step \(vm.currentStep.rawValue + 1) of \(BuilderStep.allCases.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(0.8)
                .textCase(.uppercase)
            Spacer()
            Button("cancel") {
                vm.reset()
                dismiss()
            }
            .font(.system(size: 14))
            .foregroundColor(AppColors.blockedText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(AppColors.inkBase)
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.inkDeep)
                .frame(height: 1)

            HStack {
                if vm.currentStep != .appPicker {
                    Button {
                        vm.previousStep()
                    } label: {
                        Text("back")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer()
                Button {
                    vm.nextStep()
                } label: {
                    Text("next")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(vm.canAdvance ? AppColors.onAccent : AppColors.textMuted)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(vm.canAdvance ? AppColors.accentMint : AppColors.inkSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(vm.canAdvance ? Color.clear : AppColors.inkBorder, lineWidth: 1)
                        )
                }
                .disabled(!vm.canAdvance)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            if !vm.canAdvance {
                Text(vm.validationMessage)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)
            }
        }
        .background(AppColors.inkBase)
    }
}
