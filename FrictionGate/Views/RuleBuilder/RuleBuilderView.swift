import SwiftUI

/// Root container for the 5-step rule creation flow.
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
                    .background(Color.appBorder)

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
                        .foregroundStyle(Color.appDestructive)
                    } else {
                        Button("Back") { vm.previousStep() }
                            .foregroundStyle(Color.appAccent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.currentStep != .review {
                        Button("Next") { vm.nextStep() }
                            .disabled(!vm.canAdvance)
                            .bold()
                            .foregroundStyle(vm.canAdvance ? Color.appAccent : Color.appTertiary)
                    }
                }
            }
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
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(BuilderStep.allCases, id: \.rawValue) { step in
                stepDot(step)
                if step != .review {
                    Rectangle()
                        .fill(step.rawValue < vm.currentStep.rawValue
                              ? Color.appAccent
                              : Color.appSurface2)
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.appBackground)
    }

    private func stepDot(_ step: BuilderStep) -> some View {
        let isActive    = step == vm.currentStep
        let isCompleted = step.rawValue < vm.currentStep.rawValue

        return ZStack {
            Circle()
                .fill(isCompleted
                      ? Color.appAccent
                      : (isActive ? Color.appAccent : Color.appSurface2))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(isActive && !isCompleted
                                ? Color.appAccent.opacity(0.3) : Color.clear,
                                lineWidth: 2)
                        .frame(width: 34, height: 34)
                )
                .shadow(
                    color: (isActive || isCompleted) ? Color.appAccent.opacity(0.45) : Color.clear,
                    radius: isActive ? 8 : 4, x: 0, y: 0
                )

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.appOnAccent)
            } else {
                Text("\(step.rawValue + 1)")
                    .font(.caption2.bold())
                    .foregroundStyle(isActive ? Color.appOnAccent : Color.appTertiary)
            }
        }
    }

    private var stepTitle: String {
        switch vm.currentStep {
        case .appPicker:       return "Choose App"
        case .conditionPicker: return "When to Block"
        case .challengePicker: return "Unlock Challenge"
        case .escalation:      return "Session & Escalation"
        case .review:          return "Review Rule"
        }
    }
}
