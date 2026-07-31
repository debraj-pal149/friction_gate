import SwiftUI
import FamilyControls
import ManagedSettings

struct RuleReviewView: View {

    @ObservedObject var vm: RuleBuilderViewModel
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 24)

            EyebrowLabel(text: "review your rule")

            if vm.selectedApplicationTokens.count > 1 {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.inkSurface)
                        .frame(width: 72, height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppColors.inkBorder, lineWidth: 1)
                        )
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(AppColors.accentMint)
                }
            } else {
                AppIconView(
                    token: vm.applicationToken,
                    appName: vm.appDisplayName,
                    size: 72
                )
            }

            Text(vm.reviewSummary)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 16)

            Button(action: onSave) {
                Text("set this rule")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(vm.isValid ? AppColors.accentMint : AppColors.inkSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(vm.isValid ? Color.clear : AppColors.inkBorder, lineWidth: 1)
                    )
            }
            .disabled(!vm.isValid)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.inkBase)
    }
}

// MARK: - UnlockChallenge long description

extension UnlockChallenge {
    var longDescription: String {
        switch self {
        case .steps(let n):        return "Walk \(n) steps"
        case .maths(let c):        return "Solve \(c) maths problem\(c == 1 ? "" : "s")"
        case .typeSentence(let s): return "Type: \u{201C}\(s)\u{201D}"
        case .wait(let m):         return "Wait \(m) minute\(m == 1 ? "" : "s")"
        case .writeReason:         return "Write a reason"
        }
    }
}
