import SwiftUI

struct StepChallengeView: View {

    @ObservedObject var vm: UnlockViewModel
    let required: Int

    private var progress: Double {
        guard required > 0 else { return 1 }
        return min(Double(vm.stepsFromStart) / Double(required), 1.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            EyebrowLabel(text: "walk to unlock")
                .padding(.bottom, 20)

            ZStack {
                Circle()
                    .stroke(AppColors.inkSurface, lineWidth: 6)
                    .frame(width: 180, height: 180)
                Circle()
                    .stroke(AppColors.accentMintBorder, lineWidth: 6)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AppColors.accentMint,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                VStack(spacing: 4) {
                    Text("\(vm.stepsFromStart)")
                        .font(.system(size: 42, weight: .light))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(-2)
                        .monospacedDigit()
                    Text("of \(required) steps")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textDim)
                        .tracking(0.6)
                        .textCase(.uppercase)
                }
            }
            .padding(.bottom, 24)

            Text("\(max(0, required - vm.stepsFromStart)) more to go")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textMuted)
                .tracking(-0.2)
                .padding(.bottom, 4)

            HStack(spacing: 5) {
                Circle()
                    .fill(AppColors.accentMint)
                    .frame(width: 5, height: 5)
                Text("updating live")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textDim)
                    .tracking(0.4)
            }
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
}
