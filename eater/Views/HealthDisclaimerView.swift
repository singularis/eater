import SwiftUI

struct HealthDisclaimerView: View {
  /// Stored day score from the server. Nil until a row exists. The phone does not average dishes.
  var todayHealthScore: (score: Int, color: Color)? = nil
  var dayISO: String = ""
  var newestDishTime: Int64 = 0
  var userEmail: String = ""
  var scoreFailed: Bool = false

  @Environment(\.dismiss) private var dismiss
  @State private var explainText = ""
  @State private var explaining = false

  private var appLocale: Locale { Locale(identifier: LanguageService.shared.currentCode) }
  private var lastUpdatedText: String {
    let df = DateFormatter()
    df.locale = appLocale
    df.dateStyle = .medium
    df.timeStyle = .none
    return loc("disc.updated", "Last Updated:") + " " + df.string(from: Date())
  }

  private func scoreBandLabel(_ score: Int) -> String {
    switch score {
    case 0..<40: return loc("health.score.band.poor", "Needs Improvement")
    case 40..<60: return loc("health.score.band.low", "Fair")
    case 60..<80: return loc("health.score.band.fair", "Good")
    case 80..<95: return loc("health.score.band.good", "Very Good")
    default: return loc("health.score.band.great", "Excellent")
    }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 16) {
            Text(loc("health.score.section.title", "Your Health Score"))
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 16) {
              if let today = todayHealthScore {
                ZStack {
                  Circle()
                    .stroke(today.color.opacity(0.2), lineWidth: 5)
                  Circle()
                    .trim(from: 0, to: CGFloat(today.score) / 100.0)
                    .stroke(today.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                  Text("\(today.score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(today.color)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 2) {
                  Text(loc("health.score.value.label", "Today's Score"))
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                  Text(scoreBandLabel(today.score))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(today.color)
                }
              } else {
                Image(systemName: "heart.text.square")
                  .font(.system(size: 32))
                  .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                Text(loc(
                  scoreFailed ? "health.score.unavailable" : "health.score.none",
                  scoreFailed
                    ? "Sorry, we could not calculate this score."
                    : "No score for this day yet."
                ))
                  .font(.subheadline)
                  .foregroundColor(AppTheme.textSecondary)
              }
            }

            Text(loc(
              "health.score.weighs",
              "This score weighs how much of each meal, not how many meals."
            ))
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)

            Button(action: explainDay) {
              Text(loc("health.score.explain", "Explain"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(explaining)

            if explaining {
              HStack(spacing: 8) {
                ProgressView()
                Text(loc("health.score.explaining", "Explaining your food score"))
                  .font(.subheadline)
                  .foregroundColor(AppTheme.textSecondary)
              }
            }

            if !explainText.isEmpty {
              Text(explainText)
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)
            }

            Text(
              loc(
                "health.score.explanation",
                "Each meal gets its own 0-100 score from its ingredients. The number above weighs how much of each meal you ate. Tap a meal to see that meal's score."
              )
            )
            .font(.body)
            .foregroundColor(AppTheme.textPrimary)
          }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(AppTheme.surface)
          .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))

          Text(loc("disc.title", "Health Information Disclaimer"))
            .font(.caption.weight(.semibold))
            .foregroundColor(AppTheme.textSecondary)
            .padding(.top, 28)

          Group {
            Text(loc("disc.section.notice", "Important Notice"))
              .font(.caption.weight(.semibold))
              .foregroundColor(AppTheme.textSecondary)

            Text(
              loc(
                "disc.notice.text",
                "This app provides general nutritional information and dietary suggestions for educational purposes only. The information is not intended to replace professional medical advice, diagnosis, or treatment."
              )
            )
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
          }

          Group {
            Text(loc("disc.section.medical", "Medical Disclaimer"))
              .font(.caption.weight(.semibold))
              .foregroundColor(AppTheme.textSecondary)

            Text(
              loc(
                "disc.medical.text",
                "Always consult with a qualified healthcare provider before making any changes to your diet or nutrition plan, especially if you have medical conditions, allergies, or dietary restrictions."
              )
            )
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
          }

          Group {
            Text(loc("disc.section.sources", "Data Sources & Citations"))
              .font(.caption.weight(.semibold))
              .foregroundColor(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
              CitationView(
                titleKey: "disc.src.nutrition.title",
                titleFallback: "Nutritional Data",
                sourceKey: "disc.src.nutrition.source",
                sourceFallback: "USDA FoodData Central",
                urlString: "https://fdc.nal.usda.gov/",
                descKey: "disc.src.nutrition.desc",
                descFallback: "Comprehensive nutrient database for food composition analysis"
              )

              CitationView(
                titleKey: "disc.src.guidelines.title",
                titleFallback: "Dietary Guidelines",
                sourceKey: "disc.src.guidelines.source",
                sourceFallback: "U.S. Department of Health and Human Services",
                urlString: "https://www.dietaryguidelines.gov/",
                descKey: "disc.src.guidelines.desc",
                descFallback: "Evidence-based nutritional guidance for Americans"
              )

              CitationView(
                titleKey: "disc.src.caloric.title",
                titleFallback: "Caloric Requirements",
                sourceKey: "disc.src.caloric.source",
                sourceFallback: "Institute of Medicine (IOM)",
                urlString: "https://www.nationalacademies.org/",
                descKey: "disc.src.caloric.desc",
                descFallback: "Dietary Reference Intakes for energy and macronutrients"
              )

              CitationView(
                titleKey: "disc.src.foodsafety.title",
                titleFallback: "Food Safety Information",
                sourceKey: "disc.src.foodsafety.source",
                sourceFallback: "FDA - U.S. Food and Drug Administration",
                urlString: "https://www.fda.gov/food",
                descKey: "disc.src.foodsafety.desc",
                descFallback: "Food safety and nutrition labeling guidelines"
              )

              CitationView(
                titleKey: "disc.src.research.title",
                titleFallback: "Nutritional Science Research",
                sourceKey: "disc.src.research.source",
                sourceFallback: "American Journal of Clinical Nutrition",
                urlString: "https://academic.oup.com/ajcn",
                descKey: "disc.src.research.desc",
                descFallback: "Peer-reviewed research on nutrition and health"
              )

              CitationView(
                titleKey: "disc.src.composition.title",
                titleFallback: "Food Composition Database",
                sourceKey: "disc.src.composition.source",
                sourceFallback: "USDA National Nutrient Database",
                urlString:
                  "https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-research-center/methods-and-application-of-food-composition-laboratory/",
                descKey: "disc.src.composition.desc",
                descFallback: "Standard reference for nutrient content of foods"
              )
            }
          }

          Group {
            Text(loc("disc.section.accuracy", "Accuracy Disclaimer"))
              .font(.caption.weight(.semibold))
              .foregroundColor(AppTheme.textSecondary)

            Text(
              loc(
                "disc.accuracy.text",
                "Nutritional estimates are based on visual analysis and may not be completely accurate. Actual nutritional content may vary based on preparation methods, portion sizes, and ingredient variations."
              )
            )
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
          }

          Group {
            Text(loc("disc.section.features", "App Features & Limitations"))
              .font(.caption.weight(.semibold))
              .foregroundColor(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
              Text(
                loc(
                  "disc.feature.calories",
                  "• Calorie Tracking: Estimates based on visual food analysis"))
              Text(
                loc(
                  "disc.feature.macros",
                  "• Nutritional Analysis: Macronutrient breakdown using LLM image recognition"))
              Text(
                loc(
                  "disc.feature.recommendations",
                  "• Dietary Recommendations: General suggestions based on nutritional guidelines"))
              Text(
                loc(
                  "disc.feature.weight",
                  "• Weight Tracking: User-input data for personal monitoring"))
              Text(
                loc(
                  "disc.feature.limits",
                  "• Calorie Limits: Default values or personalized calculations based on health data"
                ))
              Text(
                loc(
                  "disc.feature.plans",
                  "• Personalized Plans: Optional BMR-based calorie recommendations using user health data"
                ))
            }
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
          }

          Text(lastUpdatedText)
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
            .padding(.top, 20)
        }
        .padding()
        }
      }
      .onAppear(perform: showCachedExplanation)
      .scaledNavTitle(loc("health.score.section.title", "Your Health Score"))
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(loc("common.done", "Done")) {
            dismiss()
          }
          .foregroundColor(AppTheme.textPrimary)
        }
      }
    }
  }

  private func showCachedExplanation() {
    guard
      let entry = FoodScoreExplainStore.shared.dayEntry(email: userEmail, day: dayISO),
      entry.basisDishTime == newestDishTime
    else {
      explainText = ""
      return
    }
    explainText = entry.text
  }

  private func explainDay() {
    if let entry = FoodScoreExplainStore.shared.dayEntry(email: userEmail, day: dayISO),
      entry.basisDishTime == newestDishTime
    {
      explainText = entry.text
      return
    }
    explaining = true
    explainText = ""
    GRPCService().explainFoodScore(
      userName: userEmail,
      day: dayISO,
      languageCode: LanguageService.shared.currentCode,
      dishTime: 0
    ) { result in
      explaining = false
      guard let result else { return }
      let basis = result.basisDishTime != 0 ? result.basisDishTime : newestDishTime
      FoodScoreExplainStore.shared.saveDay(
        email: userEmail,
        day: dayISO,
        text: result.text,
        basisDishTime: basis
      )
      explainText = result.text
    }
  }
}

struct CitationView: View {
  let titleKey: String
  let titleFallback: String
  let sourceKey: String
  let sourceFallback: String
  let urlString: String
  let descKey: String
  let descFallback: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(loc(titleKey, titleFallback))
        .font(.caption.weight(.medium))
        .foregroundColor(AppTheme.textSecondary)

      Text(loc(sourceKey, sourceFallback))
        .font(.caption2)
        .foregroundColor(AppTheme.textSecondary)
        .onTapGesture {
          if let link = URL(string: urlString) {
            UIApplication.shared.open(link)
          }
        }

      Text(loc(descKey, descFallback))
        .font(.caption)
        .foregroundColor(AppTheme.textSecondary)
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  HealthDisclaimerView()
}
