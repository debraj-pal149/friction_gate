import SwiftUI

struct TypeSentenceView: View {

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
                        Image(systemName: "keyboard")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.appAccent)
                    }
                    Text("Type the sentence below exactly")
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)
                    Text("Paste is disabled. Every character must be typed.")
                        .font(.footnote)
                        .foregroundStyle(Color.appSecondary)
                        .multilineTextAlignment(.center)
                }

                Text(vm.requiredSentence)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.appPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassCard(cornerRadius: 14)
                    .padding(.horizontal)

                characterPreview

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your input")
                        .font(.caption)
                        .foregroundStyle(Color.appSecondary)
                        .padding(.horizontal, 20)

                    PasteBlockingTextField(
                        placeholder: "Start typing here…",
                        text: $vm.typedSentence,
                        font: .systemFont(ofSize: 16)
                    )
                    .frame(height: 44)
                    .padding(.horizontal)
                    .background(Color.appSurface3)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(borderColor, lineWidth: borderColor == Color.clear ? 0 : 1.5)
                    )
                    .padding(.horizontal)
                }

                Button {
                    vm.submitSentenceChallenge()
                } label: {
                    Label("Confirm", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .font(.headline)
                        .foregroundStyle(vm.sentenceMatchesRequired ? Color.appOnAccent : Color.appTertiary)
                }
                .background(vm.sentenceMatchesRequired ? Color.appAccent : Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(!vm.sentenceMatchesRequired)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .background(Color.appBackground)
    }

    // MARK: - Character preview

    private var characterPreview: some View {
        let reqChars   = Array(vm.requiredSentence)
        let typedChars = Array(vm.typedSentence)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(reqChars.indices, id: \.self) { i in
                    let reqChar   = reqChars[i]
                    let typedChar = i < typedChars.count ? typedChars[i] : nil
                    let isMatch   = typedChar == reqChar

                    Text(String(reqChar))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(
                            typedChar == nil ? Color.appTertiary
                            : isMatch ? Color.appSuccess : Color.appDestructive
                        )
                        .padding(.vertical, 2)
                        .frame(minWidth: 10)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 28)
    }

    private var borderColor: Color {
        if vm.typedSentence.isEmpty { return Color.clear }
        return vm.sentenceMatchesRequired ? Color.appSuccess : Color.appAccent
    }
}
