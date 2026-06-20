import SwiftUI

struct TypeSentenceView: View {

    @ObservedObject var vm: UnlockViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                VStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                    Text("Type the sentence below exactly")
                        .font(.headline)
                    Text("Paste is disabled. Every character must be typed.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Target sentence card
                Text(vm.requiredSentence)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                // Character-by-character match indicator
                characterPreview

                // Paste-blocking text field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your input")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    PasteBlockingTextField(
                        placeholder: "Start typing here…",
                        text: $vm.typedSentence,
                        font: .systemFont(ofSize: 16)
                    )
                    .frame(height: 44)
                    .padding(.horizontal)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(borderColor, lineWidth: 2)
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
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.sentenceMatchesRequired)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
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
                        .foregroundColor(
                            typedChar == nil ? .secondary
                            : isMatch ? .green : .red
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
        return vm.sentenceMatchesRequired ? .green : .blue
    }
}
