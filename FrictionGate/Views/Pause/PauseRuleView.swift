import SwiftUI

/// Duration options the user can choose when pausing a rule.
enum PauseDuration: String, CaseIterable, Identifiable {
    case thirtyMinutes  = "30 minutes"
    case oneHour        = "1 hour"
    case twoHours       = "2 hours"
    case untilTomorrow  = "Until tomorrow"
    case indefinitely   = "Indefinitely"

    var id: String { rawValue }

    var timeInterval: TimeInterval {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour:       return 60 * 60
        case .twoHours:      return 2 * 60 * 60
        case .untilTomorrow:
            let tomorrow = Calendar.current.startOfDay(
                for: Date().addingTimeInterval(24 * 60 * 60)
            )
            return tomorrow.timeIntervalSince(Date())
        case .indefinitely:  return 365 * 24 * 60 * 60
        }
    }
}

struct PauseRuleView: View {

    let rule: Rule
    let confirmationText: String
    let onConfirm: (TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var typedText:    String = ""
    @State private var selectedDuration: PauseDuration = .thirtyMinutes
    @Environment(\.dismiss) private var dismiss

    private var exactMatch: Bool { typedText == confirmationText }

    var body: some View {
        NavigationStack {
            List {
                // The text the user must type
                Section {
                    Text(confirmationText)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } header: {
                    Label("Type this to confirm", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                } footer: {
                    Text("Copy & paste is disabled. Type every word exactly as shown.")
                }

                // Paste-blocking input
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        PasteBlockingTextField(
                            placeholder: "Type the text above…",
                            text: $typedText,
                            font: .systemFont(ofSize: 15)
                        )
                        .frame(height: 44)

                        // Live colour bar showing match progress
                        matchProgressBar
                    }
                } header: {
                    Text("Your Input")
                } footer: {
                    if !typedText.isEmpty && !exactMatch {
                        Text("Keep typing to match exactly.")
                            .foregroundColor(.orange)
                    }
                }

                // Duration picker
                Section("Pause duration") {
                    Picker("Duration", selection: $selectedDuration) {
                        ForEach(PauseDuration.allCases) { dur in
                            Text(dur.rawValue).tag(dur)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Confirm button
                Section {
                    Button {
                        onConfirm(selectedDuration.timeInterval)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Pause Rule", systemImage: "pause.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(exactMatch ? Color.orange : Color(.systemFill))
                    .disabled(!exactMatch)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pause \(rule.appDisplayName)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Match progress bar

    private var matchProgressBar: some View {
        let required = confirmationText
        let typed    = typedText
        let ratio    = required.isEmpty ? 0.0 :
            min(1.0, Double(typed.count) / Double(required.count))

        return VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(exactMatch ? Color.green : Color.blue)
                        .frame(width: geo.size.width * ratio)
                        .animation(.easeInOut(duration: 0.2), value: ratio)
                }
            }
            .frame(height: 6)

            Text(exactMatch ? "Perfect match ✓" : "\(typed.count) / \(required.count) characters")
                .font(.caption2)
                .foregroundColor(exactMatch ? .green : .secondary)
        }
    }
}
