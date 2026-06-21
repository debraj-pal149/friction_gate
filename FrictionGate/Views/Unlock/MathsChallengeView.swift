import SwiftUI

struct MathsChallengeView: View {

    @ObservedObject var vm: UnlockViewModel
    @FocusState private var answerFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 20)

                // Progress
                if vm.mathsProblems.count > 1 {
                    Text(vm.mathsProgress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Problem card
                if let problem = vm.mathsProblems[safe: vm.mathsIndex] {
                    VStack(spacing: 12) {
                        Text(problem.question)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .lineLimit(2)
                        Text("= ?")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                }

                // Answer field
                VStack(spacing: 12) {
                    TextField("Your answer", text: $vm.mathsAnswer)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title.bold())
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .focused($answerFocused)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(vm.mathsAnswerWrong ? Color.red : Color.clear, lineWidth: 2)
                        )
                        .padding(.horizontal)

                    if vm.mathsAnswerWrong {
                        Text("Incorrect, try again")
                            .font(.footnote.bold())
                            .foregroundColor(.red)
                    }

                    Button {
                        vm.submitMathsAnswer()
                    } label: {
                        Label("Submit Answer", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .disabled(vm.mathsAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .onAppear { answerFocused = true }
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
