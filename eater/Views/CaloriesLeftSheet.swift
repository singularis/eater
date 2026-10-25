import SwiftUI

/// Explains the home calorie number. Manual limits open only from here.
struct CaloriesLeftSheet: View {
  let remaining: Int
  var onSetLimits: () -> Void
  var onCalculateLimits: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          Text("\(remaining)")
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .foregroundColor(remaining <= -1 ? AppTheme.danger : AppTheme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

          Text(loc("calories.left.title", "Calories left"))
            .font(.title3.weight(.semibold))
            .foregroundColor(AppTheme.textPrimary)

          Text(loc("calories.left.msg", "This number is how many calories you have left today."))
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

          Button(loc("calories.left.calculate", "Calculate my limit")) {
            HapticsService.shared.select()
            onCalculateLimits()
            dismiss()
          }
          .buttonStyle(PrimaryButtonStyle())
          .padding(.top, 8)

          Button(loc("calories.left.set_limits", "Set manual limits")) {
            HapticsService.shared.select()
            onSetLimits()
            dismiss()
          }
          .buttonStyle(SecondaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
      }
      .background(AppTheme.backgroundGradient.ignoresSafeArea())
      .scaledNavTitle(loc("calories.left.title", "Calories left"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(loc("common.cancel", "Cancel")) { dismiss() }
        }
      }
    }
    .appInterfaceScale()
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}
