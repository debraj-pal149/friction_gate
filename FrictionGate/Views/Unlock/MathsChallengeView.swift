import SwiftUI

struct MathsChallengeView: View {

    @ObservedObject var vm: UnlockViewModel
    @FocusState private var answerFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            EyebrowLabel(text: "solve to unlock")

            VStack(spacing: 8) {
                if let problem = vm.mathsProblems[safe: vm.mathsIndex] {
                    Text(problem.question)
                        .font(.system(size: 38, weight: .light))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-1.5)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                }
                Text(vm.mathsProgress.lowercased())
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textDim)
                    .tracking(0.6)
                    .textCase(.uppercase)
            }

            TextField("", text: $vm.mathsAnswer)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .focused($answerFocused)
                .padding(.vertical, 14)
                .background(AppColors.inkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            vm.mathsAnswer.isEmpty
                                ? AppColors.inkBorder
                                : (vm.mathsAnswerWrong ? AppColors.blockedText : AppColors.accentMint),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 48)

            if vm.mathsAnswerWrong {
                Text("try again")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.blockedText)
                    .tracking(0.4)
            }

            Button {
                vm.submitMathsAnswer()
            } label: {
                Text("submit")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(
                        vm.mathsAnswer.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AppColors.textDim
                            : AppColors.onAccent
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        vm.mathsAnswer.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AppColors.inkSurface
                            : AppColors.accentMint
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                vm.mathsAnswer.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AppColors.inkBorder
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
            }
            .disabled(vm.mathsAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .onAppear { answerFocused = true }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
