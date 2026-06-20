import SwiftUI

/// Displays the real App Store icon for a given `bundleID` via the iTunes
/// Search API, falling back to a letter-initial avatar while loading or when
/// the device is offline.
///
/// Usage:
///   AppIconView(appName: rule.appDisplayName, bundleID: rule.appBundleID)
///   AppIconView(appName: rule.appDisplayName, bundleID: rule.appBundleID, size: 64)
struct AppIconView: View {

    let appName:  String
    let bundleID: String?
    var size: CGFloat = 46

    @State private var iconURL: URL? = nil

    var body: some View {
        Group {
            if let url = iconURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        letterAvatar
                    }
                }
            } else {
                letterAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        // iOS app icon corner radius formula: radius ≈ 22.37% of size
        .task(id: bundleID) {
            await fetchIconURL()
        }
    }

    // MARK: - Letter avatar fallback

    private var letterAvatar: some View {
        ZStack {
            LinearGradient(
                colors: [avatarColor, avatarColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(appName.prefix(1)).uppercased())
                .font(.system(size: size * 0.44, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    /// Consistent colour derived from the app name — same name always gets the
    /// same colour, so the home screen looks stable across launches.
    private var avatarColor: Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let hash = abs(appName.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return palette[hash % palette.count]
    }

    // MARK: - Icon fetch

    /// Queries the iTunes Search API to get the 100×100 App Store icon URL.
    /// The response is tiny JSON (~1 KB), so this is fast even on slow connections.
    private func fetchIconURL() async {
        guard let bundleID, !bundleID.isEmpty else { return }
        guard let requestURL = URL(
            string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)&limit=1"
        ) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: requestURL)
            guard
                let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let first   = results.first,
                let urlStr  = first["artworkUrl100"] as? String,
                let url     = URL(string: urlStr)
            else { return }
            await MainActor.run { self.iconURL = url }
        } catch {
            // Network failure — letter avatar remains visible.
        }
    }
}
