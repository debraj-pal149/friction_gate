import SwiftUI

struct WriteReasonView: View {

    @ObservedObject var vm: UnlockViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.appAccentFill)
                            .frame(width: 64, height: 64)
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.appAccent)
                    }
                    Text("Why do you want to open this app?")
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)
                        .multilineTextAlignment(.center)
                    Text("Write at least a sentence or two. No one will read it. This is just for you.")
                        .font(.footnote)
                        .foregroundStyle(Color.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                TextEditor(text: $vm.writtenReason)
                    .frame(minHeight: 160)
                    .padding(10)
                    .foregroundStyle(Color.appPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.appSurface3)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                vm.reasonIsValid ? Color.appSuccess : Color.appBorder,
                                lineWidth: vm.reasonIsValid ? 1.5 : 1
                            )
                    )
                    .padding(.horizontal)

                HStack {
                    Text(
                        vm.reasonIsValid
                            ? "Long enough ✓"
                            : "\(vm.writtenReason.trimmingCharacters(in: .whitespacesAndNewlines).count) / \(UnlockViewModel.minimumReasonLength) characters"
                    )
                    .font(.caption)
                    .foregroundStyle(vm.reasonIsValid ? Color.appSuccess : Color.appSecondary)
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
                        .foregroundStyle(vm.reasonIsValid ? Color.appOnAccent : Color.appTertiary)
                }
                .background(vm.reasonIsValid ? Color.appAccent : Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(!vm.reasonIsValid)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .background(Color.appBackground)
    }
}
