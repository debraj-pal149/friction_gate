import SwiftUI

// MARK: - Friction Design System — White + Electric Blue

extension Color {

    // ── ACCENT  (Electric Blue — change this ONE value to retheme the whole app)
    //
    // ┌────────────────────────────────────────────────────────────────────┐
    // │  TO CHANGE THE ACCENT COLOR ACROSS THE ENTIRE APP,                 │
    // │  update the hex string in `appAccent` below.                        │
    // │  Every button, toggle, badge, ring, and progress bar picks it up.   │
    // └────────────────────────────────────────────────────────────────────┘
    static let appAccent       = Color(hex: "1040E8")  // Electric Blue
    static let appAccentFill   = Color(hex: "EAF0FF")  // Very light blue fill (on white)
    static let appAccentBright = Color(hex: "0A30CC")  // Slightly deeper for icons
    /// Text / icons sitting ON a solid accent-colored background — always white.
    static let appOnAccent     = Color.white

    // ── Text hierarchy

    static let appPrimary   = Color(hex: "0D0D14")  // Near-black
    static let appSecondary = Color(hex: "5E5E72")  // Medium grey
    static let appTertiary  = Color(hex: "9898A8")  // Placeholder / disabled

    // ── Surface hierarchy  (background → surface → surface2 → surface3)

    static let appBackground = Color(hex: "F4F4F8")  // Off-white page background
    static let appSurface    = Color(hex: "FFFFFF")  // Pure white cards
    static let appSurface2   = Color(hex: "EBEBF2")  // Elevated chips / disabled fills
    static let appSurface3   = Color(hex: "E4E4EC")  // Input fields
    static let appBorder     = Color(hex: "D8D8E4")  // Soft separator

    // ── Semantic

    static let appDestructive = Color(hex: "C42020")
    static let appSuccess     = Color(hex: "1A7A46")
    static let appWarning     = Color(hex: "B86A1A")

    // ── Hex initialiser

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - UIColor hex initialiser

extension UIColor {
    convenience init(themeHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8)  & 0xFF) / 255
        let b = CGFloat(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
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
                                Color.black.opacity(0.12),
                                Color.black.opacity(0.05),
                                Color.black.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 5)
    }

    /// Colored glow shadow using the app accent color.
    func accentGlow(radius: CGFloat = 12) -> some View {
        self.shadow(color: Color.appAccent.opacity(0.28), radius: radius, x: 0, y: 4)
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
