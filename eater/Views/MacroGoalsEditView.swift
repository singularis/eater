import SwiftUI

/// Editable macro goals sheet. Lets the user override the default 20/30/50
/// protein/fat/carbs split with their own gram targets, or reset back to the
/// recommendation derived from their calorie goal.
struct MacroGoalsEditView: View {
  @Environment(\.colorScheme) private var environmentColorScheme

  let initialTargets: (protein: Double, fat: Double, carbs: Double, sugarMax: Double)
  let hasCustomGoals: Bool
  let onSave: (Double, Double, Double) -> Void
  let onResetToRecommended: () -> Void
  let onCancel: () -> Void

  @State private var proteinText: String = ""
  @State private var fatText: String = ""
  @State private var carbsText: String = ""

  private var grams: String { loc("units.g", "g") }

  private var isValid: Bool {
    Double(proteinText) != nil && Double(fatText) != nil && Double(carbsText) != nil
  }

  var body: some View {
    VStack(spacing: 0) {
      Capsule()
        .fill(AppTheme.textSecondary.opacity(0.3))
        .frame(width: 40, height: 5)
        .padding(.top, 8)

      Text(loc("macro.targets.alert.title", "Macro goals"))
        .font(.title3.weight(.semibold))
        .foregroundColor(AppTheme.textPrimary)
        .padding(.top, 12)

      Text(loc("macro.edit.subtitle", "Set your own daily targets, or use our recommendation based on your calorie goal."))
        .font(.caption)
        .foregroundColor(AppTheme.textSecondary)
        .multilineTextAlignment(.center)
        .padding(.top, 4)
        .padding(.horizontal, 16)

      VStack(spacing: 14) {
        macroField(label: loc("macro.pro.full", "Protein"), text: $proteinText)
        macroField(label: loc("macro.fat.full", "Fat"), text: $fatText)
        macroField(label: loc("macro.car.full", "Carbs"), text: $carbsText)

        HStack {
          Text(loc("macro.sug.full", "Sugar"))
            .foregroundColor(AppTheme.textPrimary)
          Spacer()
          Text("40–50\(grams)")
            .foregroundColor(AppTheme.textSecondary)
        }
        .font(.subheadline)
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
        .opacity(isValid ? 1.0 : 0.5)

        if hasCustomGoals {
          Button(loc("macro.edit.reset", "Reset to recommended")) {
            HapticsService.shared.select()
            onResetToRecommended()
          }
          .buttonStyle(SecondaryButtonStyle())
        }
      }
      .padding(.top, 20)
      .padding(.horizontal, 24)
      .padding(.bottom, 16)

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
    .presentationDetents([.height(hasCustomGoals ? 480 : 420)])
    .presentationDragIndicator(.hidden)
    .onAppear {
      proteinText = String(format: "%.0f", initialTargets.protein)
      fatText = String(format: "%.0f", initialTargets.fat)
      carbsText = String(format: "%.0f", initialTargets.carbs)
    }
  }

  @ViewBuilder
  private func macroField(label: String, text: Binding<String>) -> some View {
    HStack {
      Text(label)
        .foregroundColor(AppTheme.textPrimary)
        .frame(width: 90, alignment: .leading)
      TextField("0", text: text)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
      Text(grams)
        .foregroundColor(AppTheme.textSecondary)
    }
    .font(.subheadline)
  }
}
