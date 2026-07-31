import SwiftUI

struct WriteReasonView: View {

    @ObservedObject var vm: UnlockViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            EyebrowLabel(text: "write your reason")

            Text("why do you want to open this right now?")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textMuted)
                .lineSpacing(4)

            TextEditor(text: $vm.writtenReason)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#c8d8e4"))
                .scrollContentBackground(.hidden)
                .padding(14)
                .frame(minHeight: 120)
                .background(AppColors.inkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            vm.reasonIsValid ? AppColors.accentMint : AppColors.inkBorder,
                            lineWidth: 1
                        )
                )

            Text("minimum \(UnlockViewModel.minimumReasonLength) characters · no judgment")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textDim)
                .tracking(0.3)

            Button {
                vm.submitReason()
            } label: {
                Text("submit")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(vm.reasonIsValid ? AppColors.onAccent : AppColors.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(vm.reasonIsValid ? AppColors.accentMint : AppColors.inkSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(vm.reasonIsValid ? Color.clear : AppColors.inkBorder, lineWidth: 1)
                    )
            }
            .disabled(!vm.reasonIsValid)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
}
