// FrictionGateShieldConfig/ShieldConfigurationExtension.swift
//
// ─────────────────────────────────────────────────────────────────────────────
// XCODE SETUP (do this once before building):
//
// 1. File → New → Target → search "Shield Configuration Extension" → Add
//    • Product Name: FrictionGateShieldConfig
//    • Bundle ID auto-fills as com.debrajpal.frictiongate.FrictionGateShieldConfig
//    • Leave it as-is.
//
// 2. Select the FrictionGateShieldConfig target → Signing & Capabilities:
//    • + Capability → App Groups → add group.com.debrajpal.frictiongate
//    • + Capability → Family Controls
//
// 3. Set minimum deployment target to iOS 16.0 (same as main app).
//
// 4. Replace Xcode's generated stub file in FrictionGateShieldConfig/ with
//    this file (or rename the stub to ShieldConfigurationExtension.swift and
//    paste this content in).
// ─────────────────────────────────────────────────────────────────────────────

import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the custom appearance for the Friction block screen.
///
/// When a user tries to open a blocked app, iOS shows the shield overlay.
/// This class controls:
///   - The title (the blocked app's display name)
///   - The subtitle ("A Friction block rule is active")
///   - The primary button label ("Unlock in Friction")
///
/// The primary button tap is handled by `ShieldActionExtension` in the
/// `FrictionGateShield` target — it writes to App Group UserDefaults and
/// Friction's main app presents the unlock challenge.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Shared storage

    private let defaults = UserDefaults(
        suiteName: "group.com.debrajpal.frictiongate"
    )

    // MARK: - ShieldConfigurationDataSource

    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        let appName = displayName(for: application)
        return makeConfiguration(appName: appName)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        let appName = displayName(for: application)
        return makeConfiguration(appName: appName)
    }

    // MARK: - Configuration builder

    private func makeConfiguration(appName: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor:     UIColor.systemBackground.withAlphaComponent(0.95),
            icon:                UIImage(systemName: "lock.shield.fill"),
            title: ShieldConfiguration.Label(
                text:  appName,
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text:  "A Friction block rule is active",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text:  "Unlock in Friction",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemBlue
        )
    }

    // MARK: - Display name helper

    private func displayName(for application: Application) -> String {
        // Use the localised name from the Application object if available.
        if let name = application.localizedDisplayName, !name.isEmpty {
            return name
        }
        // Fall back to the rule's stored display name read from App Group UserDefaults.
        // `pending_unlock_rule_id` is written by ShieldActionExtension when the user
        // taps the primary button — but for the *configuration* call (which happens
        // before any tap), we read the app name from the stored rules.
        if let ruleID   = defaults?.string(forKey: "pending_unlock_rule_id"),
           let rulesData = defaults?.data(forKey: "stored_rules"),
           let rules    = try? JSONDecoder().decode([StoredRuleStub].self, from: rulesData),
           let rule     = rules.first(where: { $0.id == ruleID }) {
            return rule.appDisplayName
        }
        return "Blocked App"
    }
}

// MARK: - Minimal rule stub for name lookup
//
// We only need the id + appDisplayName from the stored JSON — no need to
// link the full Rule model (which pulls in FamilyControls/ManagedSettings).

private struct StoredRuleStub: Decodable {
    let id: String
    let appDisplayName: String
}
