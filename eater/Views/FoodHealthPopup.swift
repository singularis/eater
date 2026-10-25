import SwiftUI

struct FoodHealthPopupModel: Identifiable {
  let id = UUID()
  let title: String
  let description: String
  let summary: String
}

/// Food health card. OK and Explain follow the text-size slider, unlike a system alert.
struct FoodHealthPopup: View {
  let title: String
  let description: String
  let lines: [HealthComponentLine]
  var onExplain: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          Text(AlertHelper.localizedHealthText(title))
            .font(.title3.weight(.semibold))
            .foregroundColor(AppTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

          if !description.isEmpty {
            Text(AlertHelper.localizedHealthText(description))
              .font(.body)
              .foregroundColor(AppTheme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          ForEach(lines) { line in
            VStack(alignment: .leading, spacing: 2) {
              if !line.name.isEmpty {
                Text(line.name)
                  .font(.headline)
                  .foregroundColor(AppTheme.textPrimary)
              }
              if !line.note.isEmpty {
                Text(line.note)
                  .font(.subheadline)
                  .foregroundColor(line.isRisk ? .orange : AppTheme.success)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }

          Text(loc(
            "rec.disclaimer.text",
            "⚠️ This information is for educational purposes only and should not replace professional medical advice. Consult your healthcare provider before making dietary changes."
          ))
          .font(.footnote)
          .foregroundColor(AppTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 8)

          Button(loc("health.score.explain", "Explain")) {
            HapticsService.shared.select()
            onExplain()
            dismiss()
          }
          .buttonStyle(PrimaryButtonStyle())

          Button(loc("common.ok", "OK")) {
            dismiss()
          }
          .buttonStyle(SecondaryButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(AppTheme.backgroundGradient.ignoresSafeArea())
      .scaledNavTitle(loc("health.score.section.title", "Health"))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(loc("common.ok", "OK")) { dismiss() }
        }
      }
    }
    .appInterfaceScale()
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}
