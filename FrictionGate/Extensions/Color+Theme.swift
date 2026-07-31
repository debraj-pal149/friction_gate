import SwiftUI
import UIKit

// MARK: - Friction Design System aliases

extension Color {

    static var appAccent: Color       { AppColors.accentMint }
    static var appAccentFill: Color   { AppColors.accentMintDim }
    static var appAccentBright: Color { AppColors.accentMint }
    static var appOnAccent: Color     { AppColors.onAccent }

    static var appPrimary: Color   { AppColors.textPrimary }
    static var appSecondary: Color { AppColors.textSecondary }
    static var appTertiary: Color  { AppColors.textMuted }

    static var appBackground: Color { AppColors.inkBase }
    static var appSurface: Color    { AppColors.inkSurface }
    static var appSurface2: Color   { AppColors.inkDeep }
    static var appSurface3: Color   { AppColors.inkDeep }
    static var appBorder: Color     { AppColors.inkBorder }

    static var appDestructive: Color { AppColors.blockedText }
    static var appSuccess: Color     { AppColors.accentMint }
    static var appWarning: Color     { AppColors.escalationText }
}

// MARK: - List helpers

extension View {
    /// Hides the default List scroll background and applies the ink page background.
    func inkBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppColors.inkBase)
    }

    /// Flat transparent list row — redesign uses no nested card surfaces.
    func surfaceRow() -> some View {
        self.listRowBackground(Color.clear)
    }

    /// Distinct ink surface block for builder condition / challenge sections.
    func builderBlock() -> some View {
        self
            .listRowBackground(AppColors.inkSurface)
            .listRowSeparatorTint(AppColors.inkDeep)
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
    }

    /// Shared chrome for rule-builder pickers (conditions, challenges, escalation).
    func builderListChrome() -> some View {
        self
            .inkBackground()
            .listStyle(.insetGrouped)
            .tint(AppColors.accentMint)
            .foregroundColor(AppColors.textPrimary)
            .modifier(BuilderSectionSpacing())
    }

    /// Flat elevated surface (no glow / gradient / shadow).
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(AppColors.inkSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.inkBorder, lineWidth: 1)
            }
    }

    /// No-op kept for call-site compatibility — redesign forbids glows.
    func accentGlow(radius: CGFloat = 12) -> some View {
        self
    }
}

/// Extra gap between builder sections so each option reads as its own block.
private struct BuilderSectionSpacing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.listSectionSpacing(24)
        } else {
            content
        }
    }
}

// MARK: - Builder section header

struct BuilderSectionHeader: View {
    let title: String
    let icon: String
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .symbolRenderingMode(.hierarchical)
            if let caption {
                Text(caption)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .textCase(nil)
    }
}

struct BuilderSectionFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(AppColors.textMuted)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .textCase(nil)
    }
}

// MARK: - Legacy badge (prefer StatusPill / plain captions in new UI)

struct ThemeBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }
}
