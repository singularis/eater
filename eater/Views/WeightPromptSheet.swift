import SwiftUI

/// Scaled replacement for the system weight alert. System alerts ignore the text-size slider.
struct WeightPromptSheet: View {
  @Binding var weightText: String
  var onPhoto: () -> Void
  var onSubmit: () -> Bool
  var startsOnManual: Bool = false

  @Environment(\.dismiss) private var dismiss
  @State private var manual = false
  @State private var invalid = false
  @FocusState private var focused: Bool

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if manual {
            Text(loc("weight.enter.msg", "Enter your weight in kilograms"))
              .font(.subheadline)
              .foregroundColor(AppTheme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)

            TextField(loc("weight.enter.placeholder", "Weight (kg)"), text: $weightText)
              .keyboardType(.decimalPad)
              .focused($focused)
              .appFormField()
              .onChange(of: weightText) { _, _ in invalid = false }

            if invalid {
              Text(loc("weight.invalid.msg", "Please enter a valid weight in kilograms."))
                .font(.footnote)
                .foregroundColor(AppTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button(loc("common.save", "Submit")) {
              let normalized = weightText.replacingOccurrences(of: ",", with: ".")
              guard let value = Float(normalized), value > 0 else {
                invalid = true
                HapticsService.shared.error()
                return
              }
              if onSubmit() {
                dismiss()
              }
            }
            .buttonStyle(PrimaryButtonStyle())
          } else {
            Text(loc("weight.record.msg", "Choose how you'd like to record your weight"))
              .font(.subheadline)
              .foregroundColor(AppTheme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)

            Button(loc("weight.take_photo", "Take scale photo")) {
              HapticsService.shared.select()
              onPhoto()
              dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(loc("weight.manual_entry", "Manual Entry")) {
              HapticsService.shared.select()
              weightText = ""
              invalid = false
              manual = true
              focused = true
            }
            .buttonStyle(SecondaryButtonStyle())
          }
        }
        .padding(20)
      }
      .background(AppTheme.backgroundGradient.ignoresSafeArea())
      .scaledNavTitle(
        manual
          ? loc("weight.enter.title", "Enter Weight")
          : loc("weight.record.title", "Record Weight")
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(loc("common.cancel", "Cancel")) { dismiss() }
        }
      }
      .onAppear {
        manual = startsOnManual
        if startsOnManual { focused = true }
      }
    }
    .appInterfaceScale()
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}
