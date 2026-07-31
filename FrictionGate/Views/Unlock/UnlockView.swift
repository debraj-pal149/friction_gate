import SwiftUI

struct UnlockView: View {

    @StateObject private var vm: UnlockViewModel
    @Environment(\.dismiss) private var dismiss

    init(rule: Rule, ruleStore: RuleStore) {
        _vm = StateObject(wrappedValue: UnlockViewModel(rule: rule, ruleStore: ruleStore))
    }

    var body: some View {
        ZStack {
            AppColors.inkBase.ignoresSafeArea()

            if vm.isUnlocked {
                successState
            } else {
                VStack(spacing: 0) {
                    UnlockTopBar(rule: vm.rule) {
                        vm.abandon()
                        dismiss()
                    }

                    if vm.totalChallenges > 1 {
                        Text("challenge \(vm.currentChallengeIndex + 1) of \(vm.totalChallenges)")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundColor(AppColors.textDim)
                            .padding(.top, 12)
                    }

                    Spacer(minLength: 0)

                    challengeContent

                    Spacer(minLength: 0)

                    if vm.isEscalating {
                        escalationBanner
                            .padding(.bottom, 12)
                    }

                    footerMeta
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: vm.isUnlocked) { unlocked in
            if unlocked {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    dismiss()
                }
            }
        }
        // Don't call abandon after a successful unlock — timers are already
        // torn down in completeAllChallenges / advance path.
        .onDisappear {
            if !vm.isUnlocked {
                vm.abandon()
            }
        }
    }

    @ViewBuilder
    private var challengeContent: some View {
        switch vm.currentChallenge {
        case .steps(let required):
            StepChallengeView(vm: vm, required: required)
        case .maths:
            MathsChallengeView(vm: vm)
        case .typeSentence:
            TypeSentenceView(vm: vm)
        case .wait:
            WaitChallengeView(vm: vm)
        case .writeReason:
            WriteReasonView(vm: vm)
        case nil:
            if vm.isUnlocked {
                successState
            } else {
                VStack(spacing: 12) {
                    Text("nothing to unlock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    Text("this rule has no challenges, and the app isn’t blocked")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textMuted)
                        .multilineTextAlignment(.center)
                    Button("close") {
                        vm.abandon()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.accentMint)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
            }
        }
    }

    private var escalationBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flame")
                .font(.system(size: 16))
                .foregroundColor(AppColors.escalationText)
            VStack(alignment: .leading, spacing: 3) {
                Text("escalated")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.escalationText)
                    .tracking(0.2)
                Text("challenge \(vm.currentMultiplier)× harder this session")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.escalationBody)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColors.escalationBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.escalationBorder, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var footerMeta: some View {
        HStack {
            Text("\(vm.rule.sessionDurationMinutes) min session on unlock")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textGhost)
                .tracking(0.4)
            Spacer()
            Button("give up") {
                vm.abandon()
                dismiss()
            }
            .font(.system(size: 11))
            .foregroundColor(AppColors.textGhost)
            .tracking(0.2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .padding(.bottom, 8)
    }

    private var successState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.accentMint)
            Text("unlocked")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(AppColors.textPrimary)
                .tracking(-0.8)
            Text("you have \(vm.rule.sessionDurationMinutes) minutes")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.inkBase)
    }
}

// MARK: - Top bar

private struct UnlockTopBar: View {
    let rule: Rule
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                ZStack {
                    Circle()
                        .fill(AppColors.inkSurface)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(AppColors.inkBorder, lineWidth: 1))
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .buttonStyle(.plain)

            AppIconView(token: rule.appToken, appName: rule.appDisplayName, size: 32)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Prefer stored name. FamilyControls Label(titleOnly) reports a near-zero
            // ideal width when fixedSize'd — never constrain it that way.
            if !rule.appDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(rule.appDisplayName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if let token = rule.appToken {
                Label(token)
                    .labelStyle(.titleOnly)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Offer real width (same idea as RuleRowView) so the name can lay out.
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("App")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 48)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}
