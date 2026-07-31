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
    var size: CGFloat = 44

    /// Natural render size of FamilyActivityIconView — measured on first appearance.
    @State private var naturalSize: CGSize = .zero

    var body: some View {
        Group {
            if let token {
                Label(token)
                    .labelStyle(.iconOnly)
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear { naturalSize = geo.size }
                        }
                    )
                    .scaleEffect(scaleFactor)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                letterAvatar
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var scaleFactor: CGFloat {
        let natural = max(naturalSize.width, naturalSize.height)
        guard natural > 0 else { return size / 29 }
        return size / natural
    }

    // MARK: - Letter avatar fallback

    private var letterAvatar: some View {
        ZStack {
            AppColors.inkSurface
            Text(String((appName.isEmpty ? "?" : appName).prefix(1)).uppercased())
                .font(.system(size: size * 0.44, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
