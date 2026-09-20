import SwiftUI

/// Sheet to set daily calorie limits. Replaces the system alert, whose fields
/// and tinted actions were unreadable on the light theme.
struct CalorieLimitsEditView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var softLimitText: String
  @Binding var hardLimitText: String
  let hasHealthData: Bool
  let onSave: () -> Bool
  let onUseHealth: () -> Void

  @State private var errorMessage: String?

  private var kcal: String { loc("units.kcal", "kcal") }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Capsule()
          .fill(AppTheme.textSecondary.opacity(0.45))
          .frame(width: 40, height: 5)
          .padding(.top, 8)

        Text(loc("limits.title", "Set Calorie Limits"))
          .font(.title3.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
          .padding(.top, 12)

        VStack(spacing: 14) {
          AppLabeledNumberField(
            label: loc("limits.soft", "Soft Limit"),
            unit: kcal,
            text: $softLimitText
          )
          AppLabeledNumberField(
            label: loc("limits.hard", "Hard Limit"),
            unit: kcal,
            text: $hardLimitText
          )
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)

        if let errorMessage {
          Text(errorMessage)
            .font(.caption.weight(.medium))
            .foregroundColor(AppTheme.danger)
            .multilineTextAlignment(.center)
            .padding(.top, 10)
            .padding(.horizontal, 24)
        }

        VStack(spacing: 10) {
          Button(loc("limits.save_manual", "Save Manual Limits")) {
            if onSave() {
              HapticsService.shared.success()
              dismiss()
            } else {
              HapticsService.shared.warning()
              errorMessage = loc(
                "limits.invalid_input_msg",
                "Please enter valid positive numbers. Soft limit must be less than or equal to hard limit."
              )
            }
          }
          .buttonStyle(PrimaryButtonStyle())

          if hasHealthData {
            Button(loc("limits.use_health", "Use Health-Based Calculation")) {
              HapticsService.shared.select()
              onUseHealth()
              dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
          }

          Button(loc("common.cancel", "Cancel")) {
            dismiss()
          }
          .font(.body.weight(.medium))
          .foregroundColor(AppTheme.textPrimary)
          .padding(.top, 4)
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)

        Text(
          loc(
            "limits.msg",
            "Set your daily calorie limits manually, or use health-based calculation if you have health data.\n\n⚠️ These are general guidelines. Consult a healthcare provider for personalized dietary advice."
          )
        )
        .font(.footnote)
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 16)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.backgroundGradient.ignoresSafeArea())
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.hidden)
    .tint(AppTheme.primaryButtonFill)
    .onChange(of: softLimitText) { _, _ in errorMessage = nil }
    .onChange(of: hardLimitText) { _, _ in errorMessage = nil }
  }
}
