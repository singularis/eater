import SwiftUI

struct HealthDisclaimerView: View {
  /// Today's (or currently viewed date's) average health score, matching the ring
  /// shown in the top bar. Nil when no rated food has been logged yet.
  var todayHealthScore: (score: Int, color: Color)? = nil

  @Environment(\.dismiss) private var dismiss

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
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(loc("disc.title", "Health Information Disclaimer"))
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(AppTheme.textPrimary)
            .padding(.bottom, 10)

          Group {
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
                Text(loc("health.score.none", "No rated food logged yet today."))
                  .font(.subheadline)
                  .foregroundColor(AppTheme.textSecondary)
              }
            }

            Text(
              loc(
                "health.score.explanation",
                "This is the average health rating of everything you've logged today. Each food item gets a 0-100 score from our LLM's nutritional analysis \u{2014} based on ingredients, processing level and macro balance \u{2014} as soon as you scan it. This number is the average across all rated items for the day and updates automatically as you add or remove food. Tap any food's ring on its card to see that item's individual score and recommendation."
              )
            )
            .font(.body)
            .foregroundColor(AppTheme.textPrimary)
          }

          Group {
            Text(loc("disc.section.notice", "Important Notice"))
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.textPrimary)

            Text(
              loc(
                "disc.notice.text",
                "This app provides general nutritional information and dietary suggestions for educational purposes only. The information is not intended to replace professional medical advice, diagnosis, or treatment."
              )
            )
            .font(.body)
            .foregroundColor(AppTheme.textPrimary)
          }

          Group {
            Text(loc("disc.section.medical", "Medical Disclaimer"))
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.textPrimary)

            Text(
              loc(
                "disc.medical.text",
                "Always consult with a qualified healthcare provider before making any changes to your diet or nutrition plan, especially if you have medical conditions, allergies, or dietary restrictions."
              )
            )
            .font(.body)
            .foregroundColor(AppTheme.textPrimary)
          }

          Group {
            Text(loc("disc.section.sources", "Data Sources & Citations"))
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.textPrimary)

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
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.textPrimary)

            Text(
              loc(
                "disc.accuracy.text",
                "Nutritional estimates are based on visual analysis and may not be completely accurate. Actual nutritional content may vary based on preparation methods, portion sizes, and ingredient variations."
              )
            )
            .font(.body)
            .foregroundColor(AppTheme.textPrimary)
          }

          Group {
            Text(loc("disc.section.features", "App Features & Limitations"))
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.textPrimary)

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
            .font(.body)
            .foregroundColor(AppTheme.textPrimary)
          }

          Text(lastUpdatedText)
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
            .padding(.top, 20)
        }
        .padding()
        }
      }
      .navigationTitle(loc("disc.nav", "Health Information"))
      .navigationBarTitleDisplayMode(.inline)
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
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(AppTheme.textPrimary)

      Text(loc(sourceKey, sourceFallback))
        .font(.caption)
        .foregroundColor(AppTheme.accent)
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
