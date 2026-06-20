import SwiftUI

// MARK: - App theme colours (architecture doc §14)
//
// Using named tokens keeps the palette consistent and makes a future redesign
// a one-file change. Views should prefer these over raw `Color.blue` etc.

extension Color {

    // MARK: Semantic accents

    /// Primary interactive accent — buttons, rule indicators, selection highlights.
    static let appPrimary = Color.blue

    /// Destructive / blocked state — delete actions, shield-active indicators.
    static let appDestructive = Color.red

    /// Success / unlocked state — challenge completion, unlock confirmation.
    static let appSuccess = Color.green

    /// Warning / escalation state — escalation banner, high-friction alerts.
    static let appWarning = Color.orange

    // MARK: Backgrounds

    /// Outermost grouped-list background (`systemGroupedBackground`).
    static let appBackground = Color(.systemGroupedBackground)

    /// Card / cell background inside grouped lists (`secondarySystemGroupedBackground`).
    static let appCard = Color(.secondarySystemGroupedBackground)
}
