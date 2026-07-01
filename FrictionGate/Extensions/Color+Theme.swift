import SwiftUI
import UIKit

// MARK: - Friction Design System

extension Color {

    // Legacy aliases used throughout views.
    // Backed by AppColors (single source of truth).
    static var appAccent: Color       { AppColors.primaryAccent }
    static var appAccentFill: Color   { AppColors.accentWash.opacity(0.22) }
    static var appAccentBright: Color { AppColors.featureAccent }
    static var appOnAccent: Color     {
        Color(uiColor: UIColor { trait in
            let accent = AppColors.uiPrimaryAccent.resolvedColor(with: trait)
            return accent.preferredOnColor
        })
    }

    static var appPrimary: Color   { AppColors.textPrimary }
    static var appSecondary: Color { AppColors.textSecondary }
    static var appTertiary: Color  { AppColors.textSecondary.opacity(0.72) }

    static var appBackground: Color { AppColors.background }
    static var appSurface: Color    { AppColors.surface }
    static var appSurface2: Color   { AppColors.surface.opacity(0.84) }
    static var appSurface3: Color   { AppColors.surface.opacity(0.72) }
    static var appBorder: Color     { AppColors.divider }

    static var appDestructive: Color { AppColors.destructive }
    static var appSuccess: Color     { AppColors.success }
    static var appWarning: Color     { AppColors.warning }
}

private extension UIColor {
    /// Returns either black or white based on perceived luminance of this color.
    var preferredOnColor: UIColor {
        let resolved = self.resolvedColor(with: UITraitCollection.current)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard resolved.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return .white
        }

        // Convert sRGB to linear-light for more accurate contrast estimation.
        func linearize(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        let luminance = 0.2126 * linearize(r) +
                        0.7152 * linearize(g) +
                        0.0722 * linearize(b)

        // Bright accents get dark text; dark accents keep white text.
        return luminance > 0.54 ? .black : .white
    }
}

// MARK: - List helpers

extension View {
    /// Hides the default List scroll background and applies the app page background.
    func inkBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
    }

    /// White card background for list rows.
    func surfaceRow() -> some View {
        self.listRowBackground(Color.appSurface)
    }

    // MARK: Glass card
    //
    // Applied to standalone cards only (NOT List cells).
    // Light glass: white surface + dark gradient stroke border + soft drop shadow.
    // The top inner highlight simulates diffused light falling on the card.

    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                // Glass edge — dark gradient stroke, bright top-left, fades out
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AppColors.divider.opacity(0.75),
                                AppColors.divider.opacity(0.38),
                                AppColors.divider.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: AppColors.secondaryAccent.opacity(0.18), radius: 12, x: 0, y: 4)
    }

    /// Colored glow shadow using the app accent color.
    func accentGlow(radius: CGFloat = 12) -> some View {
        self
            .shadow(color: Color.appAccent.opacity(0.22), radius: radius, x: 0, y: 4)
            .shadow(color: Color.appAccentBright.opacity(0.16), radius: radius * 1.35, x: 0, y: 6)
    }
}

// MARK: - Premium badge

struct ThemeBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.5))
    }
}
