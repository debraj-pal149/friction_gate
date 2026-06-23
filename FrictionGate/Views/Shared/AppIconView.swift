import SwiftUI
import FamilyControls
import ManagedSettings

/// Displays an app's real icon using FamilyControls' privacy-compliant
/// `Label(_ applicationToken:)` API.
///
/// `FamilyActivityIconView` (the icon part of the Label) renders at a fixed
/// natural size (~29 pt). We measure that size on first render via a background
/// GeometryReader and scale the icon up to exactly fill the requested square.
struct AppIconView: View {

    let token:   ApplicationToken?
    let appName: String        // letter-avatar fallback — use rule.appDisplayName
    var size: CGFloat = 46

    /// Natural render size of FamilyActivityIconView — measured on first appearance.
    @State private var naturalSize: CGSize = .zero

    var body: some View {
        if let token {
            Label(token)
                .labelStyle(.iconOnly)
                // Measure the icon's natural size on first render.
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { naturalSize = geo.size }
                    }
                )
                // Scale up to fill the desired square once measured.
                // Before measurement (naturalSize == .zero) we use size/29 as a
                // sensible starting estimate so there's no invisible flash.
                .scaleEffect(scaleFactor)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        } else {
            letterAvatar
        }
    }

    private var scaleFactor: CGFloat {
        let natural = max(naturalSize.width, naturalSize.height)
        guard natural > 0 else { return size / 29 }   // pre-measurement estimate
        return size / natural
    }

    // MARK: - Letter avatar fallback

    private var letterAvatar: some View {
        ZStack {
            LinearGradient(
                colors: [avatarColor, avatarColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String((appName.isEmpty ? "?" : appName).prefix(1)).uppercased())
                .font(.system(size: size * 0.44, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
    }

    private var avatarColor: Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let hash = abs(appName.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return palette[hash % palette.count]
    }
}
