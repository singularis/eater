import SwiftUI

struct RecommendationView: View {
  @Environment(\.dismiss) private var dismiss
  let recommendationText: String
  var embedded: Bool = false

  private var localizedRecommendationText: String {
    if let json = Self.jsonObject(from: recommendationText) {
      return formatRecommendationJSON(json)
    }
    var text = recommendationText
    // Keep until recommendation cache TTL (7 days) has turned over after the
    // backend format change. Do not remove in the same App Store build as that deploy.
    text = stripUnwantedSections(from: text)
    text = limitBulletSection(in: text, matching: ["Foods to Reduce", "Reduce or Avoid", loc("rec.foods_to_reduce", "Foods to Reduce or Avoid")], maxItems: 2)
    text = localizeSectionHeaders(in: text)
    text = text.replacingOccurrences(of: "- Dish Name:", with: "- " + loc("rec.dish_name_label", "Dish Name:"))
    text = text.replacingOccurrences(of: "- Description:", with: "- " + loc("rec.description_label", "Description:"))
    text = text.replacingOccurrences(of: "Dish Name:", with: loc("rec.dish_name_label", "Dish Name:"))
    text = text.replacingOccurrences(of: "Description:", with: loc("rec.description_label", "Description:"))
    return text
  }

  private func localizeSectionHeaders(in text: String) -> String {
    let pairs: [(String, String)] = [
      ("Healthier Food Options", loc("rec.healthier_foods", "Healthier Food Options")),
      ("Foods to Reduce or Avoid", loc("rec.foods_to_reduce", "Foods to Reduce or Avoid")),
      ("General Recommendations", loc("rec.general", "General Recommendations")),
      ("Coffee Warning", loc("rec.coffee_warning", "Coffee Warning")),
      ("Weekly Sugar Intake", loc("rec.weekly_sugar", "Weekly Sugar Intake")),
      ("healthier_foods", loc("rec.healthier_foods", "Healthier Food Options")),
      ("foods_to_reduce_or_avoid", loc("rec.foods_to_reduce", "Foods to Reduce or Avoid")),
      ("general_recommendations", loc("rec.general", "General Recommendations")),
      ("weekly_sugar_summary", loc("rec.weekly_sugar", "Weekly Sugar Intake")),
      ("coffee_warning", loc("rec.coffee_warning", "Coffee Warning")),
    ]
    var result = text
    for (english, localized) in pairs where english != localized {
      result = result.replacingOccurrences(of: english, with: localized)
    }
    return result
  }

  private static func jsonObject(from raw: String) -> [String: Any]? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("```") {
      s = s.replacingOccurrences(of: "^```(?:json)?\\s*", with: "", options: .regularExpression)
      s = s.replacingOccurrences(of: "\\s*```$", with: "", options: .regularExpression)
      s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard s.hasPrefix("{"), let data = s.data(using: .utf8),
      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return obj
  }

  private func formatRecommendationJSON(_ json: [String: Any]) -> String {
    var parts: [String] = []
    parts.append(contentsOf: formatFoodList(json["foods_to_reduce_or_avoid"], emoji: "🔴", header: loc("rec.foods_to_reduce", "Foods to Reduce or Avoid"), maxItems: 2))
    parts.append(contentsOf: formatFoodList(json["healthier_foods"], emoji: "🟢", header: loc("rec.healthier_foods", "Healthier Food Options"), maxItems: nil))
    if let general = formatRecommendations(json["general_recommendations"]) {
      parts.append(general)
    }
    if let coffee = json["coffee_warning"] as? String, !coffee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      parts.append("☕ \(loc("rec.coffee_warning", "Coffee Warning")):\n\(coffee)")
    }
    if let sugar = json["weekly_sugar_summary"] as? String, !sugar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      parts.append("🍬 \(loc("rec.weekly_sugar", "Weekly Sugar Intake")):\n\(sugar)")
    }
    let joined = parts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n\n")
    if !joined.isEmpty { return joined }
    return localizeSectionHeaders(in: stripUnwantedSections(from: recommendationText))
  }

  private func formatFoodList(_ value: Any?, emoji: String, header: String, maxItems: Int?) -> [String] {
    guard let foods = value as? [Any], !foods.isEmpty else { return [] }
    var lines = ["\(emoji) \(header):\n"]
    let limited = maxItems.map { Array(foods.prefix($0)) } ?? foods
    for food in limited {
      if let dict = food as? [String: Any] {
        let name = (dict["dish_name"] as? String) ?? loc("rec.unnamed_dish", "Unnamed Dish")
        let reason = (dict["reason"] as? String) ?? ""
        if reason.isEmpty {
          lines.append("- \(name)")
        } else {
          lines.append("- \(name): \(reason)")
        }
      } else {
        lines.append("- \(food)")
      }
    }
    return [lines.joined(separator: "\n")]
  }

  private func formatRecommendations(_ value: Any?) -> String? {
    let header = loc("rec.general", "General Recommendations")
    if let dict = value as? [String: Any], !dict.isEmpty {
      let bullets = dict.values.compactMap { $0 as? String }.map { "- \($0)" }
      guard !bullets.isEmpty else { return nil }
      return "\(header):\n\n" + bullets.joined(separator: "\n")
    }
    if let list = value as? [Any], !list.isEmpty {
      let bullets = list.map { "- \($0)" }
      return "\(header):\n\n" + bullets.joined(separator: "\n")
    }
    if let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "\(header):\n\n\(text)"
    }
    return nil
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
