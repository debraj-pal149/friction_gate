//
//  ShieldActionExtension.swift
//  FrictionGateShield
//
//  Created by Debraj Pal on 20/06/26.
//
// ⚠️  NO ADDITIONAL TARGET MEMBERSHIP REQUIRED FOR THIS FILE
//
// This extension does not import any Phase 1 model types.  It finds the
// matching rule ID by decoding only the `stored_selections` map from the
// App Group UserDefaults — no Rule/BlockCondition Swift types needed.
//
// Ensure the following frameworks are linked to FrictionGateShield
// (Xcode should have done this automatically):
//   - ManagedSettings
//   - FamilyControls
//
// NOTE: UIApplication.shared is unavailable in all iOS app extensions.
// Instead of opening a URL directly, this extension writes a "pending unlock"
// record to the App Group UserDefaults and returns .defer.  The main app reads
// this key on every foreground (scenePhase == .active) and presents the unlock
// screen automatically.  No URL scheme or UIApplication access required.

import Foundation
import ManagedSettings
import FamilyControls

// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldActionExtension: ShieldActionDelegate {

    // MARK: - Shared storage

    private let defaults: UserDefaults = {
        guard let d = UserDefaults(suiteName: "group.com.debrajpal.frictiongate") else {
            fatalError("App Group is not configured for FrictionGateShield.")
        }
        return d
    }()

    // Must match the key written by RuleStore.
    private let selectionsKey = "stored_selections"

    /// Written by the extension; read by the main app on every foreground.
    /// Value: the UUID string of the rule waiting to be unlocked, or nil when cleared.
    static let pendingUnlockRuleIDKey = "pending_unlock_rule_id"

    // MARK: - Application shield handler

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {

        case .primaryButtonPressed:
            // The shield's primary button is labelled "Request Unlock"
            // (configured via ShieldConfiguration in the monitor extension).
            //
            // Write the target rule ID to the App Group so the main app can
            // read it on next foreground and present the unlock screen.
            // UIApplication.shared is unavailable in extensions — UserDefaults
            // is the only safe cross-process signalling mechanism here.
            if let ruleID = ruleID(for: application) {
                defaults.set(ruleID, forKey: ShieldActionExtension.pendingUnlockRuleIDKey)
            }
            // .defer keeps the shield active; the main app removes it after
            // the challenge is completed via BlockingService.removeShield(for:).
            completionHandler(.defer)

        case .secondaryButtonPressed:
            // "Cancel" — dismiss without unlocking.
            completionHandler(.close)

        @unknown default:
            completionHandler(.defer)
        }
    }

    // MARK: - Web domain and category handlers (no-op in V1)

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    // MARK: - Token → ruleID lookup

    /// Searches the `stored_selections` map in the App Group UserDefaults for
    /// a `FamilyActivitySelection` whose `applicationTokens` contains `token`.
    ///
    /// Returns the matching rule ID string, or `nil` if no match is found.
    ///
    /// This does NOT require the Phase 1 model files to be in this target because
    /// it only decodes `FamilyActivitySelection` (from FamilyControls) and a plain
    /// `[String: Data]` dictionary — no `Rule` or `BlockCondition` types needed.
    private func ruleID(for token: ApplicationToken) -> String? {
        guard
            let outerData = defaults.data(forKey: selectionsKey),
            let map = try? JSONDecoder().decode([String: Data].self, from: outerData)
        else { return nil }

        for (ruleID, selData) in map {
            guard let selection = try? PropertyListDecoder()
                .decode(FamilyActivitySelection.self, from: selData)
            else { continue }

            if selection.applicationTokens.contains(token) {
                return ruleID
            }
        }
        return nil
    }
}
