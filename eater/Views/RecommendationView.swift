import SwiftUI

struct RecommendationView: View {
  @Environment(\.dismiss) private var dismiss
  let recommendationText: String

  /// Replaces API English labels with localized strings in recommendation body
  private var localizedRecommendationText: String {
    var text = recommendationText
    text = text.replacingOccurrences(of: "Favorite dish:", with: loc("rec.favorite_dish", "Favorite dish:"))
    text = text.replacingOccurrences(of: "- Dish Name:", with: "- " + loc("rec.dish_name_label", "Dish Name:"))
    text = text.replacingOccurrences(of: "- Description:", with: "- " + loc("rec.description_label", "Description:"))
    text = text.replacingOccurrences(of: "Dish Name:", with: loc("rec.dish_name_label", "Dish Name:"))
    text = text.replacingOccurrences(of: "Description:", with: loc("rec.description_label", "Description:"))
    return text
  }

  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(loc("rec.title", "Health Recommendation"))
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(AppTheme.textPrimary)
            .padding(.bottom, 10)

          Group {
            Text(loc("rec.subtitle", "Your Personalized Recommendation"))
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.textPrimary)

            Text(loc("rec.basis", "This recommendation is generated specifically based on the food you ate over the last 7 days."))
              .font(.subheadline)
              .foregroundColor(AppTheme.textSecondary)
              .padding(.vertical, 4)
              .padding(.horizontal, 8)
              .background(AppTheme.surfaceAlt)
              .cornerRadius(8)

            Text(localizedRecommendationText)
              .font(.body)
              .foregroundColor(AppTheme.textPrimary)
              .lineSpacing(4)
          }

          Group {
            Text(loc("rec.disclaimer.title", "Important Health Disclaimer"))
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.warning)

            Text(
              loc(
                "rec.disclaimer.text",
                "⚠️ This information is for educational purposes only and should not replace professional medical advice. Consult your healthcare provider before making dietary changes."
              )
            )
            .font(.body)
            .foregroundColor(AppTheme.textPrimary)
            .padding()
            .background(AppTheme.warning.opacity(0.1))
            .cornerRadius(AppTheme.smallRadius)
          }

          Group {
            Text(loc("rec.sources", "Data Sources"))
              .font(.headline)
              .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
              Text(loc("rec.src.usda", "• USDA FoodData Central"))
              Text(loc("rec.src.guidelines", "• Dietary Guidelines for Americans"))
              Text(loc("rec.src.research", "• Evidence-based nutritional research"))
            }
            .font(.body)
            .foregroundColor(AppTheme.textSecondary)
          }

          Text(loc("rec.generated_on", "Generated on:") + " " + formatLocalizedDate(Date()))
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
            .padding(.top, 20)
        }
        .padding()
        }
      }
      .navigationTitle(loc("rec.title", "Health Recommendation"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(loc("common.done", "Done")) {
            dismiss()
          }
        }
      }
    }
  }

  private func formatLocalizedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: LanguageService.shared.currentCode)
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}

#Preview {
  RecommendationView(
    recommendationText:
      "Based on your recent eating patterns, we recommend incorporating more vegetables and lean proteins into your diet. Consider reducing processed foods and increasing your water intake. Your current calorie intake appears to be within healthy ranges."
  )
}
