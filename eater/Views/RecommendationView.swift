import SwiftUI

struct RecommendationView: View {
  @Environment(\.dismiss) private var dismiss
  let recommendationText: String
  var embedded: Bool = false

  private var localizedRecommendationText: String {
    var text = recommendationText
    // Keep until recommendation cache TTL (7 days) has turned over after the
    // backend format change. Do not remove in the same App Store build as that deploy.
    text = stripUnwantedSections(from: text)
    text = limitBulletSection(in: text, matching: ["Foods to Reduce", "Reduce or Avoid"], maxItems: 2)
    text = text.replacingOccurrences(of: "- Dish Name:", with: "- " + loc("rec.dish_name_label", "Dish Name:"))
    text = text.replacingOccurrences(of: "- Description:", with: "- " + loc("rec.description_label", "Description:"))
    text = text.replacingOccurrences(of: "Dish Name:", with: loc("rec.dish_name_label", "Dish Name:"))
    text = text.replacingOccurrences(of: "Description:", with: loc("rec.description_label", "Description:"))
    return text
  }

  private func stripUnwantedSections(from text: String) -> String {
    let markers = [
      "Favorite dish",
      "Favourite dish",
      "Favorite healthy",
      "Favourite healthy",
      loc("rec.favorite_dish", "Favorite dish:").replacingOccurrences(of: ":", with: ""),
      "Recommended dish",
      "Try This Dish",
      "Health Advice",
      "Age advice",
      "Age-based",
      "Порада за віком",
      "Улюблена",
      "Рекомендована страва",
    ]
    let dishFieldMarkers = [
      "Dish Name:",
      "Description:",
      loc("rec.dish_name_label", "Dish Name:"),
      loc("rec.description_label", "Description:"),
    ]
    let lines = text.components(separatedBy: "\n")
    var kept: [String] = []
    var skipping = false
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let isBullet = trimmed.hasPrefix("-") || trimmed.hasPrefix("•")
      if skipping {
        if trimmed.isEmpty {
          skipping = false
          continue
        }
        if ["🍬", "☕", "🔴", "🟢"].contains(where: { trimmed.hasPrefix($0) }) {
          skipping = false
        } else {
          continue
        }
      }
      if !isBullet && (trimmed.hasPrefix("💡") || markers.contains(where: { trimmed.localizedCaseInsensitiveContains($0) })) {
        skipping = true
        continue
      }
      if isBullet && dishFieldMarkers.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
        continue
      }
      kept.append(line)
    }
    return kept.joined(separator: "\n")
      .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
  }

  private func limitBulletSection(in text: String, matching headers: [String], maxItems: Int) -> String {
    let lines = text.components(separatedBy: "\n")
    var result: [String] = []
    var inSection = false
    var bullets = 0
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if headers.contains(where: { !$0.isEmpty && trimmed.localizedCaseInsensitiveContains($0) }) {
        inSection = true
        bullets = 0
        result.append(line)
        continue
      }
      if inSection {
        if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") {
          if bullets < maxItems {
            result.append(line)
            bullets += 1
          }
          continue
        }
        if trimmed.isEmpty {
          inSection = false
          result.append(line)
          continue
        }
        inSection = false
      }
      result.append(line)
    }
    return result.joined(separator: "\n")
  }

  var body: some View {
    Group {
      if embedded {
        recommendationStack
      } else {
        NavigationView {
          ZStack {
            AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
            ScrollView {
              recommendationStack
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
    }
  }

  private var recommendationStack: some View {
    VStack(alignment: .leading, spacing: 20) {
      if !embedded {
        Text(loc("rec.title", "Health Recommendation"))
          .font(.title)
          .fontWeight(.bold)
          .foregroundColor(AppTheme.textPrimary)
          .padding(.bottom, 10)
      }

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
          .background(AppTheme.surface)
          .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous)
              .stroke(AppTheme.divider, lineWidth: 1)
          )

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
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous)
            .stroke(AppTheme.divider, lineWidth: 1)
        )
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
    .padding(embedded ? 0 : 16)
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
