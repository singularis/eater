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
