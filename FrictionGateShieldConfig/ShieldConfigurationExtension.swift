import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the custom appearance for the Friction block screen.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let defaults = UserDefaults(
        suiteName: "group.com.debrajpal.frictiongate"
    )

    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        makeConfiguration(appName: displayName(for: application))
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(appName: displayName(for: application))
    }

    // Locked ink palette — matches AppColors.accentMint / inkSurface.
    private static let accentMint = UIColor(red: 126/255, green: 255/255, blue: 212/255, alpha: 1)
    private static let inkSurface = UIColor(red: 15/255, green: 30/255, blue: 42/255, alpha: 1)
    private static let textPrimary = UIColor(red: 232/255, green: 237/255, blue: 242/255, alpha: 1)
    private static let textMuted = UIColor(red: 61/255, green: 90/255, blue: 110/255, alpha: 1)
    private static let onAccent = UIColor(red: 4/255, green: 10/255, blue: 7/255, alpha: 1)

    private func makeConfiguration(appName: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor:     Self.inkSurface,
            icon:                UIImage(systemName: "lock.shield.fill")?
                                     .withTintColor(Self.accentMint, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(
                text:  appName,
                color: Self.textPrimary
            ),
            subtitle: ShieldConfiguration.Label(
                text:  "Open Friction to complete a challenge and unlock this app.",
                color: Self.textMuted
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text:  "unlock",
                color: Self.onAccent
            ),
            primaryButtonBackgroundColor: Self.accentMint
        )
    }

    private func displayName(for application: Application) -> String {
        if let name = application.localizedDisplayName, !name.isEmpty {
            return name
        }
        if let ruleID   = defaults?.string(forKey: "pending_unlock_rule_id"),
           let rulesData = defaults?.data(forKey: "stored_rules"),
           let rules    = try? JSONDecoder().decode([StoredRuleStub].self, from: rulesData),
           let rule     = rules.first(where: { $0.id == ruleID }) {
            return rule.appDisplayName
        }
        return "Blocked App"
    }
}

private struct StoredRuleStub: Decodable {
    let id: String
    let appDisplayName: String
}
