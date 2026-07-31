import SwiftUI

// MARK: - StatusPill

struct StatusPill: View {
    enum Status { case blocked, active, paused }
    let status: Status

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bgColor)
            .foregroundColor(textColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(borderColor, lineWidth: 1))
    }

    private var label: String {
        switch status {
        case .blocked: return "blocked"
        case .active:  return "active"
        case .paused:  return "paused"
        }
    }

    private var bgColor: Color {
        switch status {
        case .blocked: return AppColors.blockedBg
        case .active:  return AppColors.accentMintBg
        case .paused:  return AppColors.pausedBg
        }
    }

    private var textColor: Color {
        switch status {
        case .blocked: return AppColors.blockedText
        case .active:  return AppColors.accentMint
        case .paused:  return AppColors.pausedText
        }
    }

    private var borderColor: Color {
        switch status {
        case .blocked: return AppColors.blockedBorder
        case .active:  return AppColors.accentMintBorder
        case .paused:  return AppColors.pausedBorder
        }
    }
}

// MARK: - CompactToggle

struct CompactToggle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? AppColors.accentMintDim : Color(hex: "#141e26"))
                .frame(width: 34, height: 20)
                .overlay(Capsule().stroke(
                    isOn ? AppColors.accentMintBorder : Color(hex: "#1a2d3a"),
                    lineWidth: 1
                ))
            Circle()
                .fill(isOn ? AppColors.accentMint : Color(hex: "#2a3d4d"))
                .frame(width: 14, height: 14)
                .padding(3)
        }
        .onTapGesture { action() }
        .animation(.easeInOut(duration: 0.18), value: isOn)
    }
}

// MARK: - EyebrowLabel

struct EyebrowLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(AppColors.textSecondary)
    }
}

// MARK: - FrictionFeatureRow

struct FrictionFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .light))
                .foregroundColor(AppColors.accentMint)
                .frame(width: 26, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - PrimaryCTA
// Mint fill + dark on-accent text. Never use .borderedProminent with light mint.

struct PrimaryCTA: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(enabled ? AppColors.onAccent : AppColors.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(enabled ? AppColors.accentMint : AppColors.inkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(enabled ? Color.clear : AppColors.inkBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - StatDisplay

struct StatDisplay: View {
    let number: String
    let label: String
    let color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(number)
                .font(.system(size: 22, weight: .light))
                .foregroundColor(color)
                .tracking(-0.8)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textDim)
                .tracking(0.6)
                .multilineTextAlignment(.leading)
        }
    }
}
