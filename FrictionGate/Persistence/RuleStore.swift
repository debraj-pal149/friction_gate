import Foundation
import Combine
import FamilyControls

/// Single source of truth for all persisted app data.
///
/// Stored in the shared App Group (`group.com.debrajpal.frictiongate`) so that
/// the main app, `FrictionGateMonitor`, and `FrictionGateShield` all read from
/// the same `UserDefaults` suite.
///
/// ## Startup performance
/// `FamilyActivitySelection` decoding via `PropertyListDecoder` is expensive
/// (it runs NSKeyedUnarchiver internally).  `init()` decodes rules on a
/// background thread and assigns to `rules` on `@MainActor` when done, so
/// the first frame renders immediately with an empty list rather than blocking
/// for several seconds.
@MainActor
final class RuleStore: ObservableObject {

    // MARK: - Storage

    private let defaults: UserDefaults = {
        guard let d = UserDefaults(suiteName: "group.com.debrajpal.frictiongate") else {
            fatalError("App Group 'group.com.debrajpal.frictiongate' is not configured.")
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

    /// True while the initial async rule decode is still running.
    /// Use in UI to show a skeleton/placeholder rather than an empty state.
    @Published var isLoadingRules: Bool = true

    // MARK: - In-memory selection map cache
    //
    // Caching avoids deserialising the entire [String: Data] map from
    // UserDefaults on every save() call, which was a major source of
    // unnecessary memory pressure and GC churn.

    private var cachedSelectionMap: [String: Data] = [:]

    // MARK: - Init

    init() {
        startupLog("RuleStore init start")
        // Fast synchronous loads — these only touch simple JSON blobs.
        loadAttempts()
        loadSettings()

        // Snapshot the raw bytes while still on the main thread.
        let rulesSnapshot      = defaults.data(forKey: Keys.rules)
        let selectionsSnapshot = defaults.data(forKey: Keys.selections)

        // Decode rules on a background thread so the first frame renders
        // without waiting for NSKeyedUnarchiver to process FamilyActivitySelection.
        Task { [weak self] in
            guard let self else { return }
            self.startupLog("RuleStore background decode start")
            let (decoded, selMap) = await Self.backgroundDecodeRules(
                rulesData:      rulesSnapshot,
                selectionsData: selectionsSnapshot
            )
            self.cachedSelectionMap = selMap
            self.rules              = decoded
            self.isLoadingRules     = false
            self.startupLog("RuleStore background decode end | rules=\(decoded.count)")
        }
        startupLog("RuleStore init end")
    }

    // MARK: - Background decode (runs off main actor)

    private static func backgroundDecodeRules(
        rulesData:      Data?,
        selectionsData: Data?
    ) async -> ([Rule], [String: Data]) {
        await Task.detached(priority: .userInitiated) {
            // Decode the selection map once.
            let selMap: [String: Data]
            if let sd = selectionsData,
               let map = try? JSONDecoder().decode([String: Data].self, from: sd) {
                selMap = map
            } else {
                selMap = [:]
            }

            guard let data = rulesData,
                  var decoded = try? JSONDecoder().decode([Rule].self, from: data)
            else { return ([], selMap) }

            // Reattach FamilyActivitySelection to each rule.
            for i in decoded.indices {
                let key = decoded[i].id.uuidString
                if let selData = selMap[key],
                   let sel = try? PropertyListDecoder()
                       .decode(FamilyActivitySelection.self, from: selData) {
                    decoded[i].activitySelection = sel
                }
            }
            return (decoded, selMap)
        }.value
    }

    // MARK: - Load (for manual refresh, e.g. foreground)

    func load() {
        startupLog("RuleStore load start")
        let rulesSnapshot      = defaults.data(forKey: Keys.rules)
        let selectionsSnapshot = defaults.data(forKey: Keys.selections)
        loadAttempts()
        loadSettings()
        Task { [weak self] in
            guard let self else { return }
            let (decoded, selMap) = await Self.backgroundDecodeRules(
                rulesData:      rulesSnapshot,
                selectionsData: selectionsSnapshot
            )
            self.cachedSelectionMap = selMap
            self.rules              = decoded
            self.startupLog("RuleStore load end | rules=\(decoded.count)")
        }
    }

    private func loadAttempts() {
        guard let data = defaults.data(forKey: Keys.attempts) else { return }
        if let decoded = try? JSONDecoder().decode([String: UnlockAttempt].self, from: data) {
            unlockAttempts = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, attempt in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, attempt)
            })
        }
    }

    private func loadSettings() {
        guard let data = defaults.data(forKey: Keys.settings) else { return }
        if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            appSettings = decoded
        }
    }

    // MARK: - Save (rules)

    func save() {
        do {
            let data = try JSONEncoder().encode(rules)
            defaults.set(data, forKey: Keys.rules)
            // Use the in-memory cache — no need to re-decode from UserDefaults.
            try persistSelectionMap(cachedSelectionMap)
        } catch {
            print("[RuleStore] Failed to save rules: \(error)")
        }
    }

    // MARK: - FamilyActivitySelection archiving

    func saveSelection(_ selection: FamilyActivitySelection, for ruleID: UUID) throws {
        let encoded = try PropertyListEncoder().encode(selection)
        cachedSelectionMap[ruleID.uuidString] = encoded
        try persistSelectionMap(cachedSelectionMap)
    }

    private func persistSelectionMap(_ map: [String: Data]) throws {
        let outer = try JSONEncoder().encode(map)
        defaults.set(outer, forKey: Keys.selections)
    }

    private func loadSelectionMap() -> [String: Data] {
        if !cachedSelectionMap.isEmpty { return cachedSelectionMap }
        guard let outer = defaults.data(forKey: Keys.selections),
              let map = try? JSONDecoder().decode([String: Data].self, from: outer)
        else { return [:] }
        cachedSelectionMap = map
        return map
    }

    private func removeSelection(for id: UUID) {
        cachedSelectionMap.removeValue(forKey: id.uuidString)
        try? persistSelectionMap(cachedSelectionMap)
    }

    // MARK: - Rules CRUD

    func add(_ rule: Rule) {
        // Archive the FamilyActivitySelection into the cache *before* calling
        // save(), so that persistSelectionMap() includes this new rule's data.
        // Without this step, load() would find no selection for the new rule
        // and appToken would be nil after any refresh.
        if let sel = rule.activitySelection,
           let encoded = try? PropertyListEncoder().encode(sel) {
            cachedSelectionMap[rule.id.uuidString] = encoded
        }
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
        // Re-encode the selection into the cache if it's present on the rule.
        if let sel = rule.activitySelection,
           let encoded = try? PropertyListEncoder().encode(sel) {
            cachedSelectionMap[rule.id.uuidString] = encoded
        }
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

    private func startupLog(_ message: String) {
        print("[Startup \(Date().timeIntervalSince1970)] \(message)")
    }
}
