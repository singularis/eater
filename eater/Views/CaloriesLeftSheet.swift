import SwiftUI

/// Explains the home calorie number. Manual limits open only from here.
struct CaloriesLeftSheet: View {
  let caloriesTotal: Int
  let eaten: Int
  let caloriesLeft: Int
  /// Home calorie color: green, amber, or red when left is negative.
  let tone: Color
  var onSetLimits: () -> Void
  var onCalculateLimits: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          VStack(spacing: 10) {
            calorieLine(loc("calories.sheet.limit", "Limit"), caloriesTotal)
            calorieLine(loc("calories.sheet.eaten", "Eaten today"), eaten)
            calorieLine(
              loc("calories.sheet.left", "Left"),
              caloriesLeft,
              emphasize: true
            )
          }
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(tone.opacity(0.14))
          .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
              .stroke(tone.opacity(0.45), lineWidth: 1)
          )
          .appCorner(AppTheme.cornerRadius)

          if caloriesTotal == 0 {
            Text(loc(
              "calories.sheet.no_limit",
              "No limit saved on the server yet. The flame still uses the limit on this phone until you save one."
            ))
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
          }

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
    .tint(AppTheme.primaryButtonFill)
    .presentationBackground { AppTheme.backgroundGradient }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  private func calorieLine(_ title: String, _ value: Int, emphasize: Bool = false) -> some View {
    HStack {
      Text(title)
        .font(emphasize ? .body.weight(.semibold) : .body)
        .foregroundColor(emphasize ? tone : AppTheme.textPrimary)
      Spacer(minLength: 12)
      Text("\(value)")
        .font(.system(size: emphasize ? 22 : 18, weight: .semibold, design: .rounded))
        .foregroundColor(emphasize ? tone : AppTheme.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
  }
}
