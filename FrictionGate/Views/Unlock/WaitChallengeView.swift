import SwiftUI

struct WaitChallengeView: View {

    @ObservedObject var vm: UnlockViewModel

    private var minutes: Int { vm.waitSecondsRemaining / 60 }
    private var seconds: Int { vm.waitSecondsRemaining % 60 }

    private var timeLabel: String {
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(seconds)"
    }

    var body: some View {
        VStack(spacing: 0) {
            EyebrowLabel(text: "wait to unlock")
                .padding(.bottom, 20)

            ZStack {
                Circle()
                    .stroke(AppColors.inkSurface, lineWidth: 6)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: vm.waitExpired ? 0 : vm.waitProgress)
                    .stroke(
                        AppColors.accentMint,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.waitProgress)

                VStack(spacing: 4) {
                    if vm.waitExpired {
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(AppColors.accentMint)
                    } else {
                        Text(timeLabel)
                            .font(.system(size: 42, weight: .light))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(-2)
                            .monospacedDigit()
                        Text("remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textDim)
                            .tracking(0.6)
                            .textCase(.uppercase)
                    }
                }
            }
            .padding(.bottom, 24)

            Text(vm.waitExpired ? "time's up" : "sit with the urge")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textMuted)
                .padding(.bottom, 20)

            Button {
                vm.confirmWaitComplete()
            } label: {
                Text("continue")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(vm.waitExpired ? AppColors.onAccent : AppColors.textDim)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(vm.waitExpired ? AppColors.accentMint : AppColors.inkSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(vm.waitExpired ? Color.clear : AppColors.inkBorder, lineWidth: 1)
                    )
            }
            .disabled(!vm.waitExpired)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
}
