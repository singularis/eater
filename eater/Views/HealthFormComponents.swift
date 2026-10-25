import SwiftUI

/// Focus tags for the Next key. Kept high so they never collide with other UIKit tags.
enum HealthFieldTag {
  static let height = 9101
  static let heightInches = 9102
  static let weight = 9103
  static let age = 9104
  static let target = 9105
}

struct HealthUnitPicker: View {
  @Binding var imperial: Bool

  var body: some View {
    HStack(spacing: 8) {
      option(loc("health.units.metric", "kg, cm"), selected: !imperial) { imperial = false }
      option(loc("health.units.imperial", "lb, ft"), selected: imperial) { imperial = true }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(loc("health.units.label", "Units"))
  }

  private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button {
      guard !selected else { return }
      HapticsService.shared.select()
      action()
    } label: {
      Text(title)
        .font(.footnote.weight(.semibold))
        .foregroundColor(selected ? .white : AppTheme.textPrimary)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(selected ? AppTheme.primaryButtonFill : AppTheme.surfaceAlt)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(selected ? Color.clear : AppTheme.divider, lineWidth: 1))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// Height in cm, or feet + inches in imperial mode.
struct HealthHeightField: View {
  let imperial: Bool
  @Binding var cm: String
  @Binding var feet: String
  @Binding var inches: String

  var body: some View {
    if imperial {
      VStack(alignment: .leading, spacing: 6) {
        Text(loc("health.field.height", "Height"))
          .font(.subheadline.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
        HStack(spacing: 8) {
          AppNumberTextField(text: $feet, placeholder: "5", keyboard: .numberPad, focusTag: HealthFieldTag.height)
            .frame(minHeight: 22)
            .appFormField()
          unit(loc("units.ft", "ft"))
          AppNumberTextField(text: $inches, placeholder: "9", keyboard: .numberPad, focusTag: HealthFieldTag.heightInches)
            .frame(minHeight: 22)
            .appFormField()
          unit(loc("units.in", "in"))
        }
      }
    } else {
      AppLabeledNumberField(
        label: loc("health.field.height", "Height"),
        unit: loc("units.cm", "cm"),
        text: $cm,
        keyboard: .numberPad,
        placeholder: "175",
        focusTag: HealthFieldTag.height
      )
    }
  }

  private func unit(_ text: String) -> some View {
    Text(text)
      .font(.subheadline.weight(.medium))
      .foregroundColor(AppTheme.textPrimary)
      .frame(minWidth: 24, alignment: .leading)
  }
}

/// Horizontal BMI scale with the healthy band and markers for now and target.
struct BMIScaleBar: View {
  let current: Double?
  let target: Double?
  let healthyUpper: Double

  private let lower = 15.0
  private let upper = 35.0

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      GeometryReader { geo in
        let width = geo.size.width
        ZStack(alignment: .leading) {
          Capsule()
            .fill(
              LinearGradient(
                colors: [AppTheme.macroCarb, AppTheme.success, AppTheme.warning, AppTheme.danger],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .opacity(0.35)
            .frame(height: 8)

          Capsule()
            .fill(AppTheme.success)
            .frame(width: x(healthyUpper, width) - x(HealthPlanCalculator.bmiMin, width), height: 8)
            .offset(x: x(HealthPlanCalculator.bmiMin, width))

          if let target {
            marker(color: AppTheme.primaryButtonFill, filled: false)
              .offset(x: x(target, width) - 8)
          }
          if let current {
            marker(color: AppTheme.textPrimary, filled: true)
              .offset(x: x(current, width) - 8)
          }
        }
        .frame(height: 16)
      }
      .frame(height: 16)

      HStack(spacing: 14) {
        if let current {
          legend(filled: true, color: AppTheme.textPrimary,
                 text: String(format: loc("health.bmi.now", "Now %.1f"), current))
        }
        if let target {
          legend(filled: false, color: AppTheme.primaryButtonFill,
                 text: String(format: loc("health.bmi.goal", "Goal %.1f"), target))
        }
        Spacer(minLength: 0)
        Text(String(format: loc("health.bmi.healthy", "Healthy %.1f-%.1f"), HealthPlanCalculator.bmiMin, healthyUpper))
          .font(.caption2)
          .foregroundColor(AppTheme.textSecondary)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func x(_ bmi: Double, _ width: CGFloat) -> CGFloat {
    let clamped = min(max(bmi, lower), upper)
    return CGFloat((clamped - lower) / (upper - lower)) * width
  }

  private func marker(color: Color, filled: Bool) -> some View {
    Circle()
      .fill(filled ? color : AppTheme.surface)
      .frame(width: 16, height: 16)
      .overlay(Circle().stroke(color, lineWidth: 3))
  }

  private func legend(filled: Bool, color: Color, text: String) -> some View {
    HStack(spacing: 4) {
      Circle()
        .fill(filled ? color : Color.clear)
        .frame(width: 8, height: 8)
        .overlay(Circle().stroke(color, lineWidth: 2))
      Text(text)
        .font(.caption2.weight(.semibold))
        .foregroundColor(AppTheme.textPrimary)
    }
  }
}

struct AppleHealthImportButton: View {
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "heart.fill")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.white)
          .frame(width: 28, height: 28)
          .background(Circle().fill(Color(red: 1.0, green: 0.22, blue: 0.37)))
        VStack(alignment: .leading, spacing: 1) {
          Text(loc("health.apple.import", "Fill from Apple Health"))
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.textPrimary)
          Text(loc("health.apple.import.sub", "Height, weight, age and sex"))
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
        }
        Spacer(minLength: 8)
        if isLoading {
          ProgressView()
        } else {
          Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundColor(AppTheme.textSecondary)
        }
      }
      .padding(12)
      .background(AppTheme.surfaceAlt)
      .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous)
          .stroke(AppTheme.divider, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(isLoading)
  }
}

/// Calorie target with target weight and timeline. Health settings and onboarding share it.
struct HealthPlanSummary: View {
  let calories: Int
  let targetText: String
  let timeline: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("\(calories)")
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)
          .contentTransition(.numericText())
        Text(loc("units.kcal_per_day", "kcal / day"))
          .font(.subheadline.weight(.semibold))
          .foregroundColor(AppTheme.textSecondary)
      }
      row(icon: "scalemass", title: loc("health.plan.target_weight_title", "Target weight"), value: targetText)
      row(icon: "calendar", title: loc("health.plan.timeline_title", "Estimated timeline"), value: timeline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func row(icon: String, title: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(AppTheme.accent)
        .frame(width: 18)
      Text(title)
        .font(.subheadline)
        .foregroundColor(AppTheme.textSecondary)
      Spacer(minLength: 8)
      Text(value)
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.trailing)
    }
  }
}

extension HealthPlanCalculator.Plan {
  var timelineText: String {
    switch goal {
    case .maintain:
      return loc("health.goal.maintain_timeline", "Keep your current weight")
    case .activityOnly:
      return loc("health.goal.activity_only_timeline", "Increase activity without changing calories")
    case .lose, .gain:
      return String(format: loc("health.goal.months_to_goal", "%d months to reach your goal"), months)
    }
  }
}
