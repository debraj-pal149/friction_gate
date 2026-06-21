import SwiftUI

// MARK: - Pause duration options

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

// MARK: - View

struct PauseRuleView: View {

    let rule: Rule
    let confirmationText: String
    let onConfirm: (TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var typedText:         String = ""
    @State private var selectedDuration: PauseDuration = .thirtyMinutes
    @Environment(\.dismiss) private var dismiss

    private var exactMatch: Bool { typedText == confirmationText }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(confirmationText)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundStyle(Color.appSecondary)
                        .padding(.vertical, 4)
                } header: {
                    Label("Type this to confirm", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.appWarning)
                } footer: {
                    Text("Copy & paste is disabled. Type every word exactly as shown.")
                        .foregroundStyle(Color.appTertiary)
                }
                .surfaceRow()
                .listRowSeparatorTint(Color.appBorder)

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        PasteBlockingTextField(
                            placeholder: "Type the text above…",
                            text: $typedText,
                            font: .systemFont(ofSize: 15)
                        )
                        .frame(height: 44)
                        .foregroundStyle(Color.appPrimary)

                        matchProgressBar
                    }
                } header: {
                    Text("Your Input").foregroundStyle(Color.appSecondary)
                } footer: {
                    if !typedText.isEmpty && !exactMatch {
                        Text("Keep typing to match exactly.")
                            .foregroundStyle(Color.appWarning)
                    }
                }
                .surfaceRow()
                .listRowSeparatorTint(Color.appBorder)

                Section("Pause duration") {
                    Picker("Duration", selection: $selectedDuration) {
                        ForEach(PauseDuration.allCases) { dur in
                            Text(dur.rawValue).tag(dur)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .foregroundStyle(Color.appPrimary)
                }
                .surfaceRow()
                .listRowSeparatorTint(Color.appBorder)

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
                    .foregroundStyle(exactMatch ? Color.appOnAccent : Color.appTertiary)
                    .listRowBackground(exactMatch ? Color.appAccent : Color.appSurface2)
                    .disabled(!exactMatch)
                }
                .listRowSeparatorTint(Color.clear)
            }
            .inkBackground()
            .listStyle(.insetGrouped)
            .navigationTitle("Pause \(rule.appDisplayName)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    // MARK: - Match progress bar

    private var matchProgressBar: some View {
        let ratio = confirmationText.isEmpty ? 0.0 :
            min(1.0, Double(typedText.count) / Double(confirmationText.count))

        return VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appSurface2)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(exactMatch ? Color.appSuccess : Color.appAccent)
                        .frame(width: geo.size.width * ratio)
                        .animation(.easeInOut(duration: 0.2), value: ratio)
                }
            }
            .frame(height: 6)

            Text(exactMatch ? "Perfect match ✓" : "\(typedText.count) / \(confirmationText.count) characters")
                .font(.caption2)
                .foregroundStyle(exactMatch ? Color.appSuccess : Color.appSecondary)
        }
    }
}
