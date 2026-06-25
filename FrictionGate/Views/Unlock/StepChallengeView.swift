import SwiftUI

struct StepChallengeView: View {

    @ObservedObject var vm: UnlockViewModel
    let required: Int

    private var progress: Double {
        guard required > 0 else { return 1 }
        return min(1, Double(vm.stepsFromStart) / Double(required))
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.appSurface2, lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progress >= 1 ? Color.appSuccess : Color.appAccent,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: progress)
                        .shadow(
                            color: (progress >= 1 ? Color.appSuccess : Color.appAccent).opacity(0.5),
                            radius: 12, x: 0, y: 0
                        )

                    VStack(spacing: 4) {
                        Text("\(vm.stepsFromStart)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.appPrimary)
                        Text("of \(required)")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondary)
                    }
                }
                .frame(width: 200, height: 200)

                VStack(spacing: 8) {
                    Text("Walk \(required) steps to unlock")
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)
                    Text("Steps are counted from when you requested the unlock. Please don't close this dialog or the app while walking.")
                        .font(.footnote)
                        .foregroundStyle(Color.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, maxHeight: .infinity, alignment: .center)
            .padding()
        }
        .background(Color.appBackground)
    }
}
