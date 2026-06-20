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

    /// The opaque `ApplicationToken` used by `ManagedSettings` to apply shields.
    /// Derived from the first application in `activitySelection` — never stored directly.
    var appToken: ApplicationToken? {
        guard let selection = activitySelection else { return nil }
        return selection.applicationTokens.first
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
        case isActive
        case isPaused
        case pauseUntil
        case createdAt
        case lastUnlockedAt
        case unlockCount
    }

    // MARK: - State helpers

    /// Whether the pause duration has expired (the rule should re-activate).
    var pauseHasExpired: Bool {
        guard isPaused, let until = pauseUntil else { return false }
        return Date() > until
    }

    /// Whether the rule is currently enforcing a block (active and not paused, or pause expired).
    var isEnforcing: Bool {
        guard isActive else { return false }
        if isPaused { return pauseHasExpired }
        return true
    }
}
