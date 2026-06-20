import SwiftUI

struct WaitChallengeView: View {

    @ObservedObject var vm: UnlockViewModel

    private var minutes: Int { vm.waitSecondsRemaining / 60 }
    private var seconds: Int { vm.waitSecondsRemaining % 60 }

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            // Countdown ring
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 14)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: vm.waitExpired ? 1 : vm.waitProgress)
                    .stroke(
                        vm.waitExpired ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)
                    .animation(.linear(duration: 1), value: vm.waitProgress)

                VStack(spacing: 4) {
                    if vm.waitExpired {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.green)
                    } else {
                        Text(String(format: "%d:%02d", minutes, seconds))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            VStack(spacing: 8) {
                Text(vm.waitExpired ? "Time's up!" : "Wait it out…")
                    .font(.title2.bold())
                Text(vm.waitExpired
                     ? "You've waited the required time. Tap below to continue."
                     : "The app will unlock once the countdown reaches zero.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                vm.confirmWaitComplete()
            } label: {
                Label("Continue", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.waitExpired)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}
