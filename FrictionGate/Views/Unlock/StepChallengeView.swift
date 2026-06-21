import SwiftUI

struct StepChallengeView: View {

    @ObservedObject var vm: UnlockViewModel
    let required: Int

    private var progress: Double {
        guard required > 0 else { return 1 }
        return min(1, Double(vm.stepsFromStart) / Double(required))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 24)

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
                    Text("Steps are counted from when you requested the unlock.")
                        .font(.footnote)
                        .foregroundStyle(Color.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Steps today")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondary)
                        Text("\(vm.stepsSinceMidnight)")
                            .font(.title3.bold())
                            .monospacedDigit()
                            .foregroundStyle(Color.appPrimary)
                    }
                    Spacer()
                    Button {
                        vm.refreshStepsNow()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .glassCard(cornerRadius: 14)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .background(Color.appBackground)
    }
}
