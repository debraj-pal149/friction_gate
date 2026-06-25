import SwiftUI
import UIKit

/// Single source of truth for app colors.
/// All raw hex values live only in this file.
enum AppColors {
    private static var p: Palette { ColorTemplates.current }

    // Required semantic contract
    static var primaryAccent: Color   { Color(lightHex: p.primaryAccentLight,   darkHex: p.primaryAccentDark) }
    static var secondaryAccent: Color { Color(lightHex: p.secondaryAccentLight, darkHex: p.secondaryAccentDark) }
    static var featureAccent: Color   { Color(lightHex: p.featureAccentLight,   darkHex: p.featureAccentDark) }
    static var accentWash: Color      { Color(lightHex: p.accentWashLight,      darkHex: p.accentWashDark) }
    static var background: Color      { Color(lightHex: p.backgroundLight,      darkHex: p.backgroundDark) }
    static var surface: Color         { Color(lightHex: p.surfaceLight,         darkHex: p.surfaceDark) }
    static var textPrimary: Color     { Color(lightHex: p.textPrimaryLight,     darkHex: p.textPrimaryDark) }
    static var textSecondary: Color   { Color(lightHex: p.textSecondaryLight,   darkHex: p.textSecondaryDark) }
    static var destructive: Color     { Color(lightHex: p.destructiveLight,     darkHex: p.destructiveDark) }
    static var success: Color         { Color(lightHex: p.successLight,         darkHex: p.successDark) }
    static var warning: Color         { Color(lightHex: p.warningLight,         darkHex: p.warningDark) }
    static var divider: Color         { Color(lightHex: p.dividerLight,         darkHex: p.dividerDark) }

    // UIKit helpers for global appearances.
    static var uiPrimaryAccent: UIColor { UIColor(lightHex: p.primaryAccentLight, darkHex: p.primaryAccentDark) }
    static var uiTextPrimary: UIColor   { UIColor(lightHex: p.textPrimaryLight, darkHex: p.textPrimaryDark) }
    static var uiBackground: UIColor    { UIColor(lightHex: p.backgroundLight, darkHex: p.backgroundDark) }
    static var uiNavBackground: UIColor { UIColor(lightHex: p.navBackgroundLight, darkHex: p.navBackgroundDark) }
    static var uiNavShadow: UIColor     { UIColor(lightHex: p.navShadowLight, darkHex: p.navShadowDark) }
}

private extension Color {
    init(lightHex: String, darkHex: String) {
        self.init(uiColor: UIColor(lightHex: lightHex, darkHex: darkHex))
    }
}

private extension UIColor {
    convenience init(lightHex: String, darkHex: String) {
        self.init { trait in
            let hex = trait.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor(hex: hex)
        }
    }

    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: UInt64
        switch cleaned.count {
        case 8:
            r = (value >> 24) & 0xFF
            g = (value >> 16) & 0xFF
            b = (value >> 8)  & 0xFF
            a = value & 0xFF
        case 6:
            r = (value >> 16) & 0xFF
            g = (value >> 8)  & 0xFF
            b = value & 0xFF
            a = 0xFF
        default:
            r = 0; g = 0; b = 0; a = 0xFF
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
