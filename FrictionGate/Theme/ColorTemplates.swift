import Foundation

/// Numbered palette registry — locked to the premium ink system.
/// Template cycling is disabled in product UI; Template 1 is the only default.
enum ColorTemplates {
    private static let selectedTemplateKey = "friction_selected_color_template"
    private static let defaultTemplateID = 1
    static let savedTemplateIDs: [Int] = [1]

    static var selectedTemplateID: Int? {
        get { defaultTemplateID }
        set { UserDefaults.standard.set(defaultTemplateID, forKey: selectedTemplateKey) }
    }

    /// Locked ink palette (light keys unused — app forces ink surfaces in both modes).
    static let lockedInk = Palette(
        primaryAccentLight: "#7effd4", primaryAccentDark: "#7effd4",
        secondaryAccentLight: "#7a9ab0", secondaryAccentDark: "#7a9ab0",
        featureAccentLight: "#7effd4", featureAccentDark: "#7effd4",
        accentWashLight: "#0d3d29", accentWashDark: "#0d3d29",
        backgroundLight: "#080c10", backgroundDark: "#080c10",
        surfaceLight: "#0f1e2a", surfaceDark: "#0f1e2a",
        textPrimaryLight: "#e8edf2", textPrimaryDark: "#e8edf2",
        textSecondaryLight: "#7a9ab0", textSecondaryDark: "#7a9ab0",
        destructiveLight: "#ff6b6b", destructiveDark: "#ff6b6b",
        successLight: "#7effd4", successDark: "#7effd4",
        warningLight: "#ff9f43", warningDark: "#ff9f43",
        dividerLight: "#1a3348", dividerDark: "#1a3348",
        navBackgroundLight: "#080c10", navBackgroundDark: "#080c10",
        navShadowLight: "#00000000", navShadowDark: "#00000000"
    )

    static let transientPalette = lockedInk

    static let templates: [Int: Palette] = [
        1: lockedInk
    ]

    static var current: Palette {
        lockedInk
    }
}

struct Palette {
    let primaryAccentLight: String
    let primaryAccentDark: String
    let secondaryAccentLight: String
    let secondaryAccentDark: String
    let featureAccentLight: String
    let featureAccentDark: String
    let accentWashLight: String
    let accentWashDark: String
    let backgroundLight: String
    let backgroundDark: String
    let surfaceLight: String
    let surfaceDark: String
    let textPrimaryLight: String
    let textPrimaryDark: String
    let textSecondaryLight: String
    let textSecondaryDark: String
    let destructiveLight: String
    let destructiveDark: String
    let successLight: String
    let successDark: String
    let warningLight: String
    let warningDark: String
    let dividerLight: String
    let dividerDark: String
    let navBackgroundLight: String
    let navBackgroundDark: String
    let navShadowLight: String
    let navShadowDark: String
}
