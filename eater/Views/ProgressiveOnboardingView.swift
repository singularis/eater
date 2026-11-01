import SwiftUI

enum ProgressiveOnboardingStep {
  case notifications
  case none
}

/// Reminder prompt. Health details are collected in Health Settings.
struct ProgressiveOnboardingView: View {
  let step: ProgressiveOnboardingStep
  @Binding var isPresented: Bool
  var onComplete: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)

      VStack(spacing: 16) {
        Image(systemName: "bell.badge.fill")
          .font(.system(size: 36, weight: .semibold))
          .foregroundColor(AppTheme.accent)
          .frame(width: 72, height: 72)
          .background(AppTheme.accent.opacity(0.12))
          .clipShape(Circle())

        Text(loc("prog.notif.title", "Stay on Track"))
          .font(.system(size: 28, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)
          .multilineTextAlignment(.center)

        Text(loc("onboarding.notifications.desc", "Enable reminders to snap your meals."))
          .font(.body)
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 24)

      Spacer(minLength: 0)

      VStack(spacing: 4) {
        Button(action: enableReminders) {
          Text(loc("onboarding.notifications.enable", "Enable Reminders"))
            .font(.body.weight(.semibold))
        }
        .buttonStyle(PrimaryButtonStyle())

        Button(action: skipReminders) {
          Text(loc("onboarding.notifications.notnow", "Not Now"))
            .font(.body.weight(.medium))
            .foregroundColor(AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 12)
    }
    .background(AppTheme.backgroundGradient.ignoresSafeArea())
  }

  private func skipReminders() {
    HapticsService.shared.select()
    onComplete()
  }

  private func enableReminders() {
    HapticsService.shared.select()
    NotificationService.shared.requestAuthorizationAndEnable(true) { _ in
      onComplete()
    }
  }
}
