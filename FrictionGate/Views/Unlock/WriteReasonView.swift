import SwiftUI

struct WriteReasonView: View {

    @ObservedObject var vm: UnlockViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                VStack(spacing: 8) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                    Text("Why do you want to open this app?")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Write at least a sentence or two. No one will read it. This is just for you.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                TextEditor(text: $vm.writtenReason)
                    .frame(minHeight: 160)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(vm.reasonIsValid ? Color.green : Color(.systemFill), lineWidth: 2)
                    )
                    .padding(.horizontal)

                HStack {
                    Text(
                        vm.reasonIsValid
                            ? "Long enough ✓"
                            : "\(vm.writtenReason.trimmingCharacters(in: .whitespacesAndNewlines).count) / \(UnlockViewModel.minimumReasonLength) characters"
                    )
                    .font(.caption)
                    .foregroundColor(vm.reasonIsValid ? .green : .secondary)
                    Spacer()
                }
                .padding(.horizontal)

                Button {
                    vm.submitReason()
                } label: {
                    Label("Submit", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.reasonIsValid)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
    }
}
