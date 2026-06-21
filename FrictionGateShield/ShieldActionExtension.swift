//
//  ShieldActionExtension.swift
//  FrictionGateShield
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
//   - UserNotifications
//
// HOW THE UNLOCK FLOW WORKS:
//
//   1. User taps "Switch to Friction →" on the shield overlay.
//   2. This extension writes the ruleID to App Group UserDefaults and
//      schedules an immediate local push notification ("Tap to unlock in Friction").
//   3. .close is returned — the blocked app is dismissed, user sees home screen.
//   4. The notification banner appears; user taps it → iOS opens Friction.
//   5. FrictionGateApp reads the pending ruleID on scenePhase == .active
//      and presents the unlock challenge screen immediately.
//   6. On challenge completion, BlockingService.removeShield clears the block.

import Foundation
import ManagedSettings
import FamilyControls
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {

    // MARK: - Shared storage

    private let defaults: UserDefaults = {
        guard let d = UserDefaults(suiteName: "group.com.debrajpal.frictiongate") else {
            fatalError("App Group is not configured for FrictionGateShield.")
        }
        return d
    }()

    private let selectionsKey = "stored_selections"

    /// Written by the extension; read by the main app on every foreground.
    static let pendingUnlockRuleIDKey = "pending_unlock_rule_id"

    // MARK: - Application shield handler

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {

        case .primaryButtonPressed:
            let ruleID = ruleID(for: application)

            // 1. Write the pending ruleID + a timestamp so the main app can
            //    ignore stale requests (e.g. tapped hours ago, never completed).
            if let ruleID {
                defaults.set(ruleID, forKey: ShieldActionExtension.pendingUnlockRuleIDKey)
                defaults.set(Date().timeIntervalSince1970,
                             forKey: "pending_unlock_timestamp")
            }

            // 2. Fire an immediate local notification that opens Friction when tapped.
            //    This is the only reliable cross-process mechanism on iOS —
            //    UIApplication / URL schemes are unavailable in shield extensions.
            scheduleUnlockNotification(ruleID: ruleID, appToken: application)

            // 3. .close dismisses the blocked app → user lands on home screen.
            //    The notification banner appears immediately and tapping it
            //    opens Friction, which then shows the unlock challenge.
            completionHandler(.close)

        case .secondaryButtonPressed:
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

    // MARK: - Local notification

    private func scheduleUnlockNotification(ruleID: String?, appToken: ApplicationToken) {
        let content = UNMutableNotificationContent()

        // Look up the app name for a friendlier notification title.
        let appName = ruleID.flatMap { appDisplayName(for: $0) } ?? "your blocked app"

        content.title = "Unlock \(appName)"
        content.body  = "Tap to open Friction and complete your challenge."
        content.sound = .default
        content.categoryIdentifier = "FRICTION_UNLOCK"

        if let ruleID {
            content.userInfo = ["ruleID": ruleID]
        }

        // nil trigger = deliver immediately.
        let request = UNNotificationRequest(
            identifier: "friction-unlock-\(ruleID ?? UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Token → ruleID lookup

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

    // MARK: - App display name lookup

    private func appDisplayName(for ruleID: String) -> String? {
        guard
            let rulesData = defaults.data(forKey: "stored_rules"),
            let rules     = try? JSONDecoder().decode([StoredRuleStub].self, from: rulesData),
            let rule      = rules.first(where: { $0.id == ruleID }),
            !rule.appDisplayName.isEmpty,
            rule.appDisplayName.lowercased() != "selected app"
        else { return nil }
        return rule.appDisplayName
    }
}

// MARK: - Minimal rule stub (id + appDisplayName only)

private struct StoredRuleStub: Decodable {
    let id: String
    let appDisplayName: String
}
