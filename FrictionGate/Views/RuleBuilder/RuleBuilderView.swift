import SwiftUI

/// Root container for the 4-step rule creation flow.
/// Presented as a full-screen sheet from `HomeView`.
struct RuleBuilderView: View {

    @StateObject private var vm: RuleBuilderViewModel
    @Environment(\.dismiss) private var dismiss

    init(ruleStore: RuleStore) {
        _vm = StateObject(wrappedValue: RuleBuilderViewModel(ruleStore: ruleStore))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                Divider()

                // Step content
                Group {
                    switch vm.currentStep {
                    case .appPicker:
                        AppPickerView(vm: vm)
                    case .conditionPicker:
                        ConditionPickerView(vm: vm)
                    case .challengePicker:
                        ChallengePickerView(vm: vm)
                    case .review:
                        RuleReviewView(vm: vm, onSave: {
                            vm.save()
                            dismiss()
                        })
                    }
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if vm.currentStep == .appPicker {
                        Button("Cancel") {
                            vm.reset()
                            dismiss()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Back") { vm.previousStep() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.currentStep != .review {
                        Button("Next") { vm.nextStep() }
                            .disabled(!vm.canAdvance)
                            .bold()
                    }
                }
            }
        }
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(BuilderStep.allCases, id: \.rawValue) { step in
                stepDot(step)
                if step != .review {          // show connector between all dots except after the last
                    Rectangle()
                        .fill(step.rawValue < vm.currentStep.rawValue ? Color.blue : Color(.systemFill))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func stepDot(_ step: BuilderStep) -> some View {
        let isActive    = step == vm.currentStep
        let isCompleted = step.rawValue < vm.currentStep.rawValue

        return ZStack {
            Circle()
                .fill(isCompleted ? Color.blue : (isActive ? Color.blue : Color(.systemFill)))
                .frame(width: 28, height: 28)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            } else {
                Text("\(step.rawValue + 1)")
                    .font(.caption.bold())
                    .foregroundColor(isActive ? .white : .secondary)
            }
        }
    }

    private var stepTitle: String {
        switch vm.currentStep {
        case .appPicker:       return "Choose App"
        case .conditionPicker: return "When to Block"
        case .challengePicker: return "Unlock Challenge"
        case .review:          return "Review Rule"
        }
    }
}
