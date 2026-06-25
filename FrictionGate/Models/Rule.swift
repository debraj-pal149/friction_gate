import Foundation
import FamilyControls
import ManagedSettings

/// The central model that defines a blocking rule for a single app.
///
/// # Persistence note — ApplicationToken
/// `ApplicationToken` is an opaque Apple type that cannot safely be archived via
/// a plain `JSONEncoder` round-trip.  Instead, the entire `FamilyActivitySelection`
/// returned by `FamilyActivityPicker` is encoded with `PropertyListEncoder` and
/// stored separately in UserDefaults (App Group) keyed by `id.uuidString`.
/// `RuleStore` rehydrates `activitySelection` on load, making `appToken` available
/// at runtime without any Codable gymnastics on the token itself.
///
/// `activitySelection` is therefore intentionally excluded from `CodingKeys`.
struct Rule: Identifiable, Codable {

    // MARK: - Identity

    var id: UUID

    // MARK: - App identity (token stored externally — see RuleStore)

    /// The full selection from `FamilyActivityPicker`.  Restored at load time by
    /// `RuleStore` from its separately-archived `Data` blob.  `nil` only briefly
    /// during JSON deserialization before `RuleStore` reattaches it.
    var activitySelection: FamilyActivitySelection?

    /// The opaque `ApplicationToken` used by `ManagedSettings` to apply shields
    /// and by `Label(token)` in SwiftUI for privacy-compliant icon + name rendering.
    /// Derived from the first application in `activitySelection` — never stored directly.
    var appToken: ApplicationToken? {
        activitySelection?.applicationTokens.first
    }

    /// Human-readable app name stored in JSON so the UI can render without the token.
    var appDisplayName: String

    /// Bundle ID of the selected app, if extractable from the selection metadata.
    var appBundleID: String?

    // MARK: - Block configuration

    var conditions: [BlockCondition]
    var challenges: [UnlockChallenge]

    /// Whether escalating friction is enabled for this rule.
    var escalationEnabled: Bool

    /// Duration (minutes) of the window inside which repeated unlocks raise the
    /// challenge multiplier.  Default: 120 (2 hours).
    var escalationWindowMinutes: Int

    /// After completing the unlock challenge the user gets this many minutes to
    /// freely use the app before the shield is automatically re-applied.
    /// Default: 20 minutes.
    var sessionDurationMinutes: Int

    // MARK: - State

    var isActive: Bool
    var isPaused: Bool

    /// When the rule is paused until.  `nil` when the rule is not paused.
    var pauseUntil: Date?

    // MARK: - Audit / escalation bookkeeping

    var createdAt: Date

    /// Timestamp of the most recent successful unlock for this rule.
    var lastUnlockedAt: Date?

    /// Cumulative unlock count (used in conjunction with `UnlockAttempt` for escalation).
    var unlockCount: Int

    // MARK: - Init

    init(
        id: UUID = UUID(),
        activitySelection: FamilyActivitySelection? = nil,
        appDisplayName: String,
        appBundleID: String? = nil,
        conditions: [BlockCondition] = [],
        challenges: [UnlockChallenge] = [],
        escalationEnabled: Bool = false,
        escalationWindowMinutes: Int = 120,
        sessionDurationMinutes: Int = 20,
        isActive: Bool = true,
        isPaused: Bool = false,
        pauseUntil: Date? = nil,
        createdAt: Date = Date(),
        lastUnlockedAt: Date? = nil,
        unlockCount: Int = 0
    ) {
        self.id = id
        self.activitySelection = activitySelection
        self.appDisplayName = appDisplayName
        self.appBundleID = appBundleID
        self.conditions = conditions
        self.challenges = challenges
        self.escalationEnabled = escalationEnabled
        self.escalationWindowMinutes = escalationWindowMinutes
        self.sessionDurationMinutes = sessionDurationMinutes
        self.isActive = isActive
        self.isPaused = isPaused
        self.pauseUntil = pauseUntil
        self.createdAt = createdAt
        self.lastUnlockedAt = lastUnlockedAt
        self.unlockCount = unlockCount
    }

    // MARK: - Codable

    /// `activitySelection` is intentionally excluded — it is archived separately by
    /// `RuleStore` using `PropertyListEncoder` and keyed by `id.uuidString`.
    enum CodingKeys: String, CodingKey {
        case id
        case appDisplayName
        case appBundleID
        case conditions
        case challenges
        case escalationEnabled
        case escalationWindowMinutes
        case sessionDurationMinutes
        case isActive
        case isPaused
        case pauseUntil
        case createdAt
        case lastUnlockedAt
        case unlockCount
    }

    /// Custom decoder supplies defaults for fields added after v1, so existing
    /// stored rules decode cleanly after an app update.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                     = try c.decode(UUID.self,           forKey: .id)
        appDisplayName         = try c.decode(String.self,         forKey: .appDisplayName)
        appBundleID            = try c.decodeIfPresent(String.self, forKey: .appBundleID)
        conditions             = try c.decode([BlockCondition].self, forKey: .conditions)
        challenges             = try c.decode([UnlockChallenge].self, forKey: .challenges)
        escalationEnabled      = try c.decodeIfPresent(Bool.self,  forKey: .escalationEnabled) ?? false
        escalationWindowMinutes = try c.decodeIfPresent(Int.self,  forKey: .escalationWindowMinutes) ?? 120
        sessionDurationMinutes = try c.decodeIfPresent(Int.self,   forKey: .sessionDurationMinutes) ?? 20
        // Pause/deactivation has been removed from product behavior.
        // Keep persisted keys for backward compatibility but coerce to active.
        isActive               = true
        isPaused               = false
        pauseUntil             = nil
        createdAt              = try c.decodeIfPresent(Date.self,  forKey: .createdAt) ?? Date()
        lastUnlockedAt         = try c.decodeIfPresent(Date.self,  forKey: .lastUnlockedAt)
        unlockCount            = try c.decodeIfPresent(Int.self,   forKey: .unlockCount) ?? 0
    }

    // MARK: - State helpers

    /// Whether the pause duration has expired (the rule should re-activate).
    var pauseHasExpired: Bool {
        guard isPaused, let until = pauseUntil else { return false }
        return Date() > until
    }

    /// Rules are always enforcing unless deleted.
    var isEnforcing: Bool {
        return true
    }
}

extension Rule {
    /// Challenges ordered from easiest to hardest for predictable presentation.
    var challengesByDifficulty: [UnlockChallenge] {
        challenges.sorted { lhs, rhs in
            if lhs.difficultyScore == rhs.difficultyScore {
                return lhs.displayName < rhs.displayName
            }
            return lhs.difficultyScore < rhs.difficultyScore
        }
    }

    /// Rule difficulty is driven by its hardest challenge with small nudges
    /// for escalation and shorter session windows.
    var difficultyScore: Int {
        let base = challenges.map(\.difficultyScore).max() ?? 0
        let escalationBonus = escalationEnabled ? 8 : 0
        let sessionBonus = max(0, min(6, (20 - sessionDurationMinutes) / 4))
        return min(100, base + escalationBonus + sessionBonus)
    }

    var difficultyTier: ChallengeDifficultyTier {
        switch difficultyScore {
        case ..<30: return .easy
        case ..<55: return .medium
        case ..<80: return .hard
        default: return .extreme
        }
    }
}
