import SwiftUI

/// Displays the real App Store icon for a given `bundleID` via the iTunes
/// Search API, falling back to a letter-initial avatar while loading or when
/// the device is offline.
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

    private var avatarColor: Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let hash = abs(appName.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return palette[hash % palette.count]
    }

    // MARK: - Icon fetch

    private func fetchIconURL() async {
        guard let bundleID, !bundleID.isEmpty else { return }

        // Check the in-process cache first — avoids a network round-trip every
        // time the list re-renders or the view is recreated.
        if let cached = IconURLCache.shared.url(for: bundleID) {
            iconURL = cached
            return
        }

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

            IconURLCache.shared.store(url, for: bundleID)
            iconURL = url
        } catch {
            // Network failure — letter avatar stays visible.
        }
    }
}

// MARK: - Icon URL Cache

/// Lightweight in-process cache so each bundle ID is looked up at most once
/// per app session. Keeps NSString/NSURL to leverage NSCache's automatic
/// memory-pressure eviction.
private final class IconURLCache {
    static let shared = IconURLCache()
    private let cache = NSCache<NSString, NSURL>()

    private init() {
        cache.countLimit = 100   // Evict after 100 entries if needed.
    }

    func url(for bundleID: String) -> URL? {
        cache.object(forKey: bundleID as NSString) as URL?
    }

    func store(_ url: URL, for bundleID: String) {
        cache.setObject(url as NSURL, forKey: bundleID as NSString)
    }
}
