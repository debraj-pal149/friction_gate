import SwiftUI

struct TypeSentenceView: View {

    @ObservedObject var vm: UnlockViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            EyebrowLabel(text: "type to unlock")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(vm.requiredSentence)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textMuted)
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.inkDeep)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.inkBorder, lineWidth: 1)
                )

            PasteBlockingTextField(
                placeholder: "type exactly as above",
                text: $vm.typedSentence,
                font: .systemFont(ofSize: 13)
            )
            .frame(height: 100)
            .padding(16)
            .background(AppColors.inkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        vm.sentenceMatchesRequired ? AppColors.accentMint : AppColors.inkBorder,
                        lineWidth: 1
                    )
            )

            HStack {
                Text("\(vm.typedSentence.count) / \(vm.requiredSentence.count)")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textDim)
                    .tracking(0.4)
                Spacer()
                if vm.sentenceMatchesRequired {
                    Text("matched")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.accentMint)
                        .tracking(0.6)
                        .textCase(.uppercase)
                }
            }

            Button {
                vm.submitSentenceChallenge()
            } label: {
                Text("confirm")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(vm.sentenceMatchesRequired ? AppColors.onAccent : AppColors.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(vm.sentenceMatchesRequired ? AppColors.accentMint : AppColors.inkSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                vm.sentenceMatchesRequired ? Color.clear : AppColors.inkBorder,
                                lineWidth: 1
                            )
                    )
            }
            .disabled(!vm.sentenceMatchesRequired)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
}
