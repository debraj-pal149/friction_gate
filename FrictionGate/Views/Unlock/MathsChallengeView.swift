import SwiftUI

struct MathsChallengeView: View {

    @ObservedObject var vm: UnlockViewModel
    @FocusState private var answerFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 24)

                if vm.mathsProblems.count > 1 {
                    Text(vm.mathsProgress)
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondary)
                }

                if let problem = vm.mathsProblems[safe: vm.mathsIndex] {
                    VStack(spacing: 12) {
                        Text(problem.question)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .lineLimit(2)
                            .foregroundStyle(Color.appPrimary)
                        Text("= ?")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(Color.appSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .glassCard(cornerRadius: 20)
                    .padding(.horizontal)
                }

                VStack(spacing: 14) {
                    TextField("Your answer", text: $vm.mathsAnswer)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title.bold())
                        .foregroundStyle(Color.appPrimary)
                        .padding()
                        .background(Color.appSurface3)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .focused($answerFocused)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    vm.mathsAnswerWrong ? Color.appDestructive : Color.appBorder,
                                    lineWidth: vm.mathsAnswerWrong ? 2 : 1
                                )
                        )
                        .padding(.horizontal)

                    if vm.mathsAnswerWrong {
                        Text("Incorrect, try again")
                            .font(.footnote.bold())
                            .foregroundStyle(Color.appDestructive)
                    }

                    Button {
                        vm.submitMathsAnswer()
                    } label: {
                        Label("Submit Answer", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .font(.headline)
                            .foregroundStyle(Color.appOnAccent)
                    }
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .disabled(vm.mathsAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(vm.mathsAnswer.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .background(Color.appBackground)
        .onAppear { answerFocused = true }
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
