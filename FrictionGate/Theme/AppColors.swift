import SwiftUI
import UIKit

/// Locked premium ink palette — single source of truth.
/// Do not invent colors outside this file.
enum AppColors {

    // Backgrounds
    static let inkBase    = Color(hex: "#080c10")
    static let inkSurface = Color(hex: "#0f1e2a")
    static let inkBorder  = Color(hex: "#1a3348")
    static let inkDeep    = Color(hex: "#0b1620")

    // Text — keep enough contrast on inkBase / inkSurface
    static let textPrimary   = Color(hex: "#e8edf2")
    static let textSecondary = Color(hex: "#9bb4c6")
    static let textMuted     = Color(hex: "#6b8fa3")
    static let textDim       = Color(hex: "#567890")
    static let textGhost     = Color(hex: "#2a4050")

    // Accent
    static let accentMint       = Color(hex: "#7effd4")
    static let accentMintDim    = Color(hex: "#0d3d29")
    static let accentMintBg     = Color(hex: "#071a13")
    static let accentMintBorder = Color(hex: "#0f3325")
    static let onAccent         = Color(hex: "#040a07")

    // Semantic — blocked
    static let blockedText   = Color(hex: "#ff6b6b")
    static let blockedBg     = Color(hex: "#1f0c0c")
    static let blockedBorder = Color(hex: "#3d1515")

    // Semantic — escalation
    static let escalationText   = Color(hex: "#ff9f43")
    static let escalationBg     = Color(hex: "#120b07")
    static let escalationBorder = Color(hex: "#2a1500")
    static let escalationBody   = Color(hex: "#5a3a1e")

    // Semantic — paused
    static let pausedText   = Color(hex: "#3d5a6e")
    static let pausedBg     = Color(hex: "#141414")
    static let pausedBorder = Color(hex: "#1e2e38")

    // Legacy semantic contract used by older call sites
    static var primaryAccent: Color   { accentMint }
    static var secondaryAccent: Color { textSecondary }
    static var featureAccent: Color   { accentMint }
    static var accentWash: Color      { accentMintDim }
    static var background: Color      { inkBase }
    static var surface: Color         { inkSurface }
    static var destructive: Color     { blockedText }
    static var success: Color         { accentMint }
    static var warning: Color         { escalationText }
    static var divider: Color         { inkBorder }

    // UIKit helpers for global appearances
    static var uiPrimaryAccent: UIColor { UIColor(hex: "#7effd4") }
    static var uiTextPrimary: UIColor   { UIColor(hex: "#e8edf2") }
    static var uiBackground: UIColor    { UIColor(hex: "#080c10") }
    static var uiNavBackground: UIColor { UIColor(hex: "#080c10") }
    static var uiNavShadow: UIColor     { UIColor(hex: "#00000000") }
}

// MARK: - Hex helpers

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
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
