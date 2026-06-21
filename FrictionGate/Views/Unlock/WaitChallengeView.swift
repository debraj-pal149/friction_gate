import SwiftUI

struct WaitChallengeView: View {

    @ObservedObject var vm: UnlockViewModel

    private var minutes: Int { vm.waitSecondsRemaining / 60 }
    private var seconds: Int { vm.waitSecondsRemaining % 60 }

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                // Track ring
                Circle()
                    .stroke(Color.appSurface2, lineWidth: 14)
                    .frame(width: 220, height: 220)

                // Progress ring with glow
                Circle()
                    .trim(from: 0, to: vm.waitExpired ? 1 : vm.waitProgress)
                    .stroke(
                        vm.waitExpired ? Color.appSuccess : Color.appAccent,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)
                    .animation(.linear(duration: 1), value: vm.waitProgress)
                    .shadow(
                        color: (vm.waitExpired ? Color.appSuccess : Color.appAccent).opacity(0.5),
                        radius: 12, x: 0, y: 0
                    )

                VStack(spacing: 4) {
                    if vm.waitExpired {
                        Image(systemName: "checkmark")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(Color.appSuccess)
                    } else {
                        Text(String(format: "%d:%02d", minutes, seconds))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.appPrimary)
                        Text("remaining")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondary)
                    }
                }
            }

            VStack(spacing: 8) {
                Text(vm.waitExpired ? "Time's up." : "Wait it out.")
                    .font(.title2.bold())
                    .foregroundStyle(Color.appPrimary)
                Text(vm.waitExpired
                     ? "You've waited the required time. Tap below to continue."
                     : "The app will unlock once the countdown reaches zero.")
                    .font(.footnote)
                    .foregroundStyle(Color.appSecondary)
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
                    .foregroundStyle(vm.waitExpired ? Color.appOnAccent : Color.appTertiary)
            }
            .background(vm.waitExpired ? Color.appAccent : Color.appSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(!vm.waitExpired)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .background(Color.appBackground)
    }
}
