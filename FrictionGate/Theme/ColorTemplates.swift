import Foundation

/// Numbered palette registry.
/// Only keep explicitly saved configs here.
enum ColorTemplates {
    private static let selectedTemplateKey = "friction_selected_color_template"
    private static let defaultTemplateID = 6
    static let savedTemplateIDs: [Int] = [1, 2, 3, 4, 5, 6]

    /// Persisted selected saved config.
    /// Nil = use transient working palette.
    static var selectedTemplateID: Int? {
        get {
            let raw = UserDefaults.standard.integer(forKey: selectedTemplateKey)
            guard raw != 0, savedTemplateIDs.contains(raw) else { return defaultTemplateID }
            return raw
        }
        set {
            if let value = newValue, savedTemplateIDs.contains(value) {
                UserDefaults.standard.set(value, forKey: selectedTemplateKey)
            } else {
                UserDefaults.standard.removeObject(forKey: selectedTemplateKey)
            }
        }
    }

    /// Working palette from latest "use this now" request.
    /// This is intentionally NOT saved as a numbered config.
    static let transientPalette = Palette(
        primaryAccentLight: "#1DD3B0", primaryAccentDark: "#B2FF9E",
        secondaryAccentLight: "#086375", secondaryAccentDark: "#3C1642",
        featureAccentLight: "#AFFC41", featureAccentDark: "#1DD3B0",
        accentWashLight: "#B2FF9E", accentWashDark: "#086375",
        backgroundLight: "#F2FFF7", backgroundDark: "#111825",
        surfaceLight: "#FFFFFF", surfaceDark: "#1A2635",
        textPrimaryLight: "#1A2532", textPrimaryDark: "#EDFFF8",
        textSecondaryLight: "#456272", textSecondaryDark: "#A3C8CF",
        destructiveLight: "#A04B69", destructiveDark: "#C86A8B",
        successLight: "#1DD3B0", successDark: "#76E6CF",
        warningLight: "#AFFC41", warningDark: "#D2FF87",
        dividerLight: "#D6EEE6", dividerDark: "#2D4150",
        navBackgroundLight: "#FFFFFFD9", navBackgroundDark: "#152232D9",
        navShadowLight: "#00000012", navShadowDark: "#00000066"
    )

    static let templates: [Int: Palette] = [
        // Template 1: previous palette (saved)
        1: Palette(
            primaryAccentLight: "#3943B7", primaryAccentDark: "#449DD1",
            secondaryAccentLight: "#150578", secondaryAccentDark: "#78C0E0",
            featureAccentLight: "#B63A56", featureAccentDark: "#E06282",
            accentWashLight: "#78C0E0", accentWashDark: "#150578",
            backgroundLight: "#F3F5F8", backgroundDark: "#090B18",
            surfaceLight: "#FFFFFF", surfaceDark: "#121631",
            textPrimaryLight: "#121632", textPrimaryDark: "#E8EEFF",
            textSecondaryLight: "#4A5479", textSecondaryDark: "#9AA8D1",
            destructiveLight: "#B63A56", destructiveDark: "#E06282",
            successLight: "#247A57", successDark: "#52BF90",
            warningLight: "#A26B17", warningDark: "#DAA03C",
            dividerLight: "#D6DBE8", dividerDark: "#252B4A",
            navBackgroundLight: "#FFFFFFD6", navBackgroundDark: "#101428D9",
            navShadowLight: "#00000014", navShadowDark: "#00000066"
        ),

        // Template 3: ink + indigo + grape + steel + red (saved)
        2: Palette(
            primaryAccentLight: "#38405F", primaryAccentDark: "#59546C",
            secondaryAccentLight: "#59546C", secondaryAccentDark: "#8B939C",
            featureAccentLight: "#FF0035", featureAccentDark: "#FF4F73",
            accentWashLight: "#8B939C", accentWashDark: "#38405F",
            backgroundLight: "#F1F3F6", backgroundDark: "#0E131F",
            surfaceLight: "#FFFFFF", surfaceDark: "#1A2233",
            textPrimaryLight: "#0E131F", textPrimaryDark: "#E9EDF4",
            textSecondaryLight: "#4D5566", textSecondaryDark: "#AAB4C3",
            destructiveLight: "#FF0035", destructiveDark: "#FF4F73",
            successLight: "#2C7A61", successDark: "#55B89A",
            warningLight: "#8B939C", warningDark: "#B7BEC8",
            dividerLight: "#D5DBE4", dividerDark: "#2C3547",
            navBackgroundLight: "#FFFFFFD8", navBackgroundDark: "#141C2CD9",
            navShadowLight: "#00000012", navShadowDark: "#00000066"
        ),

        // Template 5: almond cream + lilac ash + dusty grape + prussian blue + ink black (saved)
        3: Palette(
            primaryAccentLight: "#161B33", primaryAccentDark: "#474973",
            secondaryAccentLight: "#474973", secondaryAccentDark: "#A69CAC",
            featureAccentLight: "#474973", featureAccentDark: "#161B33",
            accentWashLight: "#A69CAC", accentWashDark: "#474973",
            backgroundLight: "#F8F1E8", backgroundDark: "#0D0C1D",
            surfaceLight: "#FFFFFF", surfaceDark: "#161B33",
            textPrimaryLight: "#0D0C1D", textPrimaryDark: "#F3F0F9",
            textSecondaryLight: "#5F5A70", textSecondaryDark: "#C5BCD3",
            destructiveLight: "#A04563", destructiveDark: "#C66D8B",
            successLight: "#4F7A66", successDark: "#8FBFA8",
            warningLight: "#A98B65", warningDark: "#D1B28E",
            dividerLight: "#E0D8D0", dividerDark: "#32304A",
            navBackgroundLight: "#FFFFFFD9", navBackgroundDark: "#121230D9",
            navShadowLight: "#00000014", navShadowDark: "#00000066"
        ),

        // Template 8: steel blue + dusty grape + dark amethyst + midnight violet + black (saved)
        4: Palette(
            primaryAccentLight: "#6665DD", primaryAccentDark: "#473BF0",
            secondaryAccentLight: "#9B9ECE", secondaryAccentDark: "#ACADBC",
            featureAccentLight: "#473BF0", featureAccentDark: "#6665DD",
            accentWashLight: "#ACADBC", accentWashDark: "#000500",
            backgroundLight: "#F2F3FA", backgroundDark: "#000500",
            surfaceLight: "#FFFFFF", surfaceDark: "#101228",
            textPrimaryLight: "#1A1C2C", textPrimaryDark: "#EFF0FF",
            textSecondaryLight: "#5F6285", textSecondaryDark: "#B7BAD8",
            destructiveLight: "#8C4C89", destructiveDark: "#B36FAF",
            successLight: "#5C8FA7", successDark: "#8FBED2",
            warningLight: "#6665DD", warningDark: "#9B9ECE",
            dividerLight: "#DCDFF0", dividerDark: "#2D2F4B",
            navBackgroundLight: "#FFFFFFD9", navBackgroundDark: "#0F1124D9",
            navShadowLight: "#00000012", navShadowDark: "#00000066"
        ),

        // Template 9: ruby red + raspberry + plum + crimson violet + bordeaux (saved)
        5: Palette(
            primaryAccentLight: "#9E0031", primaryAccentDark: "#8E0045",
            secondaryAccentLight: "#770058", secondaryAccentDark: "#600047",
            featureAccentLight: "#D91E36", featureAccentDark: "#9E0031",
            accentWashLight: "#EC5766", accentWashDark: "#44001A",
            backgroundLight: "#FFF1F5", backgroundDark: "#140008",
            surfaceLight: "#FFFFFF", surfaceDark: "#220013",
            textPrimaryLight: "#2B0D1B", textPrimaryDark: "#FFEFF6",
            textSecondaryLight: "#7D3B5A", textSecondaryDark: "#E3A8C2",
            destructiveLight: "#C42348", destructiveDark: "#EF7674",
            successLight: "#5A8E71", successDark: "#8AC0A2",
            warningLight: "#9E0031", warningDark: "#C42348",
            dividerLight: "#F1D5E2", dividerDark: "#4B1631",
            navBackgroundLight: "#FFFFFFD9", navBackgroundDark: "#1E0010D9",
            navShadowLight: "#00000012", navShadowDark: "#00000066"
        ),

        // Template 10: turquoise + teal + amethyst + green-yellow + light green (saved, default)
        6: Palette(
            primaryAccentLight: "#1DD3B0", primaryAccentDark: "#B2FF9E",
            secondaryAccentLight: "#086375", secondaryAccentDark: "#3C1642",
            featureAccentLight: "#AFFC41", featureAccentDark: "#1DD3B0",
            accentWashLight: "#B2FF9E", accentWashDark: "#086375",
            backgroundLight: "#F2FFF7", backgroundDark: "#111825",
            surfaceLight: "#FFFFFF", surfaceDark: "#1A2635",
            textPrimaryLight: "#1A2532", textPrimaryDark: "#EDFFF8",
            textSecondaryLight: "#456272", textSecondaryDark: "#A3C8CF",
            destructiveLight: "#A04B69", destructiveDark: "#C86A8B",
            successLight: "#1DD3B0", successDark: "#76E6CF",
            warningLight: "#AFFC41", warningDark: "#D2FF87",
            dividerLight: "#D6EEE6", dividerDark: "#2D4150",
            navBackgroundLight: "#FFFFFFD9", navBackgroundDark: "#152232D9",
            navShadowLight: "#00000012", navShadowDark: "#00000066"
        )
    ]

    static var current: Palette {
        if let selected = selectedTemplateID {
            return templates[selected] ?? templates[1]!
        }
        return transientPalette
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
