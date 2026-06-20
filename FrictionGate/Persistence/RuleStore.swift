import Foundation
import Combine
import FamilyControls

/// Single source of truth for all persisted app data.
///
/// Stored in the shared App Group (`group.com.debrajpal.frictiongate`) so that
/// the main app, `FrictionGateMonitor`, and `FrictionGateShield` all read from
/// the same `UserDefaults` suite.
///
/// ## Storage layout (UserDefaults keys)
/// | Key                  | Type      | Contents                                      |
/// |----------------------|-----------|-----------------------------------------------|
/// | `stored_rules`       | `Data`    | `JSONEncoder` output of `[Rule]`              |
/// | `stored_selections`  | `Data`    | `PropertyListEncoder` output of `[String: Data]` (ruleID → plist of `FamilyActivitySelection`) |
/// | `stored_attempts`    | `Data`    | `JSONEncoder` output of `[String: UnlockAttempt]` (ruleID → attempt) |
/// | `app_settings`       | `Data`    | `JSONEncoder` output of `AppSettings`         |
///
/// ## FamilyActivitySelection archiving
/// `FamilyActivitySelection` (the result of `FamilyActivityPicker`) is a Swift
/// struct that conforms to `Codable` but whose internal `ApplicationToken` values
/// are opaque.  The safe approach is to encode the *entire selection* with
/// `PropertyListEncoder` and store it separately, then reattach it to each `Rule`
/// at load time.  This keeps `ApplicationToken` out of the JSON layer entirely.
@MainActor
final class RuleStore: ObservableObject {

    // MARK: - Storage

    private let defaults: UserDefaults = {
        guard let d = UserDefaults(suiteName: "group.com.debrajpal.frictiongate") else {
            fatalError("App Group 'group.com.debrajpal.frictiongate' is not configured. " +
                       "Add it under Signing & Capabilities in Xcode.")
        }
        return d
    }()

    private enum Keys {
        static let rules       = "stored_rules"
        static let selections  = "stored_selections"
        static let attempts    = "stored_attempts"
        static let settings    = "app_settings"
    }

    // MARK: - Published state

    @Published var rules: [Rule] = []
    @Published var unlockAttempts: [UUID: UnlockAttempt] = [:]
    @Published var appSettings: AppSettings = .default

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Load

    func load() {
        loadRules()
        loadAttempts()
        loadSettings()
    }

    private func loadRules() {
        guard let data = defaults.data(forKey: Keys.rules) else { return }
        do {
            var decoded = try JSONDecoder().decode([Rule].self, from: data)
            let selectionMap = loadSelectionMap()
            for i in decoded.indices {
                let key = decoded[i].id.uuidString
                if let selData = selectionMap[key],
                   let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selData) {
                    decoded[i].activitySelection = selection
                }
            }
            rules = decoded
        } catch {
            print("[RuleStore] Failed to load rules: \(error)")
        }
    }

    private func loadAttempts() {
        guard let data = defaults.data(forKey: Keys.attempts) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: UnlockAttempt].self, from: data)
            unlockAttempts = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, attempt in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, attempt)
            })
        } catch {
            print("[RuleStore] Failed to load unlock attempts: \(error)")
        }
    }

    private func loadSettings() {
        guard let data = defaults.data(forKey: Keys.settings) else { return }
        do {
            appSettings = try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("[RuleStore] Failed to load app settings: \(error)")
        }
    }

    // MARK: - Save (rules)

    func save() {
        do {
            let data = try JSONEncoder().encode(rules)
            defaults.set(data, forKey: Keys.rules)
            try saveSelectionMap()
        } catch {
            print("[RuleStore] Failed to save rules: \(error)")
        }
    }

    // MARK: - FamilyActivitySelection archiving

    /// Encodes and persists a `FamilyActivitySelection` keyed by its rule ID.
    ///
    /// Call this immediately after the user picks an app in `FamilyActivityPicker`
    /// and you've set `rule.activitySelection`.
    func saveSelection(_ selection: FamilyActivitySelection, for ruleID: UUID) throws {
        var map = loadSelectionMap()
        let encoded = try PropertyListEncoder().encode(selection)
        map[ruleID.uuidString] = encoded
        try persistSelectionMap(map)
    }

    private func saveSelectionMap() throws {
        var map: [String: Data] = [:]
        for rule in rules {
            guard let selection = rule.activitySelection else { continue }
            map[rule.id.uuidString] = try PropertyListEncoder().encode(selection)
        }
        try persistSelectionMap(map)
    }

    private func persistSelectionMap(_ map: [String: Data]) throws {
        // Store the inner Data values directly; the outer dict is JSON-encoded.
        // PropertyListEncoder handles the FamilyActivitySelection → Data step above;
        // JSON handles the [String: Data] → Data step here (Data encodes as base-64).
        let outer = try JSONEncoder().encode(map)
        defaults.set(outer, forKey: Keys.selections)
    }

    private func loadSelectionMap() -> [String: Data] {
        guard let outer = defaults.data(forKey: Keys.selections),
              let map = try? JSONDecoder().decode([String: Data].self, from: outer)
        else { return [:] }
        return map
    }

    private func removeSelection(for id: UUID) {
        var map = loadSelectionMap()
        map.removeValue(forKey: id.uuidString)
        try? persistSelectionMap(map)
    }

    // MARK: - Rules CRUD

    func add(_ rule: Rule) {
        rules.append(rule)
        save()
    }

    func delete(_ rule: Rule) {
        rules.removeAll { $0.id == rule.id }
        removeSelection(for: rule.id)
        unlockAttempts.removeValue(forKey: rule.id)
        save()
        saveAttempts()
    }

    func update(_ rule: Rule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
        save()
    }

    // MARK: - UnlockAttempt management

    func attempt(for ruleID: UUID) -> UnlockAttempt {
        unlockAttempts[ruleID] ?? UnlockAttempt(ruleID: ruleID)
    }

    func saveAttempt(_ attempt: UnlockAttempt) {
        unlockAttempts[attempt.ruleID] = attempt
        saveAttempts()
    }

    func resetAttempt(for ruleID: UUID) {
        var attempt = self.attempt(for: ruleID)
        attempt.reset()
        saveAttempt(attempt)
    }

    private func saveAttempts() {
        do {
            let encoded = Dictionary(uniqueKeysWithValues:
                unlockAttempts.map { ($0.key.uuidString, $0.value) }
            )
            let data = try JSONEncoder().encode(encoded)
            defaults.set(data, forKey: Keys.attempts)
        } catch {
            print("[RuleStore] Failed to save unlock attempts: \(error)")
        }
    }

    // MARK: - AppSettings

    func saveSettings() {
        do {
            let data = try JSONEncoder().encode(appSettings)
            defaults.set(data, forKey: Keys.settings)
        } catch {
            print("[RuleStore] Failed to save app settings: \(error)")
        }
    }
}
