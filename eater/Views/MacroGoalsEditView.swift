import SwiftUI

/// Editable macro goals sheet. Lets the user override the default 20/30/50
/// protein/fat/carbs split with their own gram targets, or reset back to the
/// recommendation derived from their calorie goal.
struct MacroGoalsEditView: View {
  let initialTargets: (protein: Double, fat: Double, carbs: Double, sugarMax: Double)
  let hasCustomGoals: Bool
  let onSave: (Double, Double, Double) -> Void
  let onResetToRecommended: () -> Void
  let onCancel: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var proteinText: String = ""
  @State private var fatText: String = ""
  @State private var carbsText: String = ""

  private var grams: String { loc("units.g", "g") }

  private var isValid: Bool {
    Double(proteinText) != nil && Double(fatText) != nil && Double(carbsText) != nil
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Capsule()
          .fill(AppTheme.textSecondary.opacity(0.45))
          .frame(width: 40, height: 5)
          .padding(.top, 8)

        Text(loc("macro.targets.alert.title", "Macro goals"))
          .font(.title3.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
          .padding(.top, 12)

        Text(
          loc(
            "macro.edit.subtitle",
            "Set your own daily targets, or use our recommendation based on your calorie goal."
          )
        )
        .font(.subheadline)
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.center)
        .padding(.top, 6)
        .padding(.horizontal, 20)

        VStack(spacing: 14) {
          AppLabeledNumberField(
            label: loc("macro.pro.full", "Protein"),
            unit: grams,
            text: $proteinText
          )
          AppLabeledNumberField(
            label: loc("macro.fat.full", "Fat"),
            unit: grams,
            text: $fatText
          )
          AppLabeledNumberField(
            label: loc("macro.car.full", "Carbs"),
            unit: grams,
            text: $carbsText
          )

          HStack {
            Text(loc("macro.sug.full", "Sugar"))
              .font(.subheadline.weight(.semibold))
              .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text("40–50\(grams)")
              .font(.subheadline.weight(.medium))
              .foregroundColor(AppTheme.textPrimary)
          }
          .padding(.top, 4)
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)

        VStack(spacing: 10) {
          Button(loc("common.save", "Save")) {
            guard let p = Double(proteinText), let f = Double(fatText), let c = Double(carbsText)
            else { return }
            HapticsService.shared.success()
            onSave(p, f, c)
          }
          .buttonStyle(PrimaryButtonStyle())
          .disabled(!isValid)
          .opacity(isValid ? 1.0 : 0.55)

          if hasCustomGoals {
            Button(loc("macro.edit.reset", "Reset to recommended")) {
              HapticsService.shared.select()
              onResetToRecommended()
            }
            .buttonStyle(SecondaryButtonStyle())
          }

          Button(loc("common.cancel", "Cancel")) {
            onCancel()
            dismiss()
          }
          .font(.body.weight(.medium))
          .foregroundColor(AppTheme.textPrimary)
          .padding(.top, 4)
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
      }
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.backgroundGradient.ignoresSafeArea())
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.hidden)
    .tint(AppTheme.primaryButtonFill)
    .onAppear {
      proteinText = String(format: "%.0f", initialTargets.protein)
      fatText = String(format: "%.0f", initialTargets.fat)
      carbsText = String(format: "%.0f", initialTargets.carbs)
    }
  }
}
