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
                Spacer(minLength: 20)

                // Goal ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progress >= 1 ? Color.green : Color.blue,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: progress)

                    VStack(spacing: 4) {
                        Text("\(vm.stepsFromStart)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("of \(required)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 200, height: 200)

                VStack(spacing: 8) {
                    Text("Walk \(required) steps to unlock")
                        .font(.headline)
                    Text("Steps are counted from when you requested the unlock.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Today's total
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Steps today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(vm.stepsSinceMidnight)")
                            .font(.title3.bold())
                            .monospacedDigit()
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
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }
}
