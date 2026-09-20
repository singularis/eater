import SwiftUI

struct IdeasTabView: View {
  @ObservedObject private var nav = AppNavigation.shared
  @EnvironmentObject var languageService: LanguageService
  @State private var recommendationText = ""
  @State private var isLoadingRecommendation = false

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)

        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            MealPlannerView(
              remaining: nav.mealRemaining,
              mealsToday: nav.mealsToday,
              languageCode: languageService.currentCode,
              embedded: true
            )

            recommendationSection
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 24)
        }
      }
      .navigationTitle(loc("tab.ideas", "Ideas"))
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { fetchRecommendationIfNeeded() }
    }
    .environment(\.locale, Locale(identifier: languageService.currentCode))
  }

  private var recommendationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(loc("rec.title", "Health Recommendation"))
          .font(.title3.weight(.bold))
          .foregroundColor(AppTheme.textPrimary)
        Spacer()
        if isLoadingRecommendation {
          ProgressView()
        }
      }

      if recommendationText.isEmpty && !isLoadingRecommendation {
        Button(loc("ideas.load_advice", "Load this week's advice")) {
          fetchRecommendationIfNeeded(force: true)
        }
        .buttonStyle(PrimaryButtonStyle())
      } else if !recommendationText.isEmpty {
        RecommendationView(recommendationText: recommendationText, embedded: true)
      }
    }
  }

  private func fetchRecommendationIfNeeded(force: Bool = false) {
    guard force || recommendationText.isEmpty else { return }
    isLoadingRecommendation = true
    GRPCService().getRecommendation(days: 7, languageCode: languageService.currentCode) { recommendation in
      DispatchQueue.main.async {
        if recommendation.isEmpty {
          recommendationText = loc(
            "rec.fallback",
            "We couldn't customize your advice right now, but here are some general wellness tips:\n\nConsistent habits build a healthy lifestyle. Start by incorporating more whole foods like vegetables, fruits, nuts, and legumes into your meals. These provide essential fiber and nutrients that processed food often lacks.\n\nTry to limit added sugars and heavily processed snacks, opting instead for natural sweetness from fruit. Staying hydrated is often overlooked but crucial for metabolism and energy.\n\nPhysical activity is the perfect partner to nutrition. Even a daily 30-minute walk can make a significant difference. Lastly, quality sleep is when your body repairs itself—prioritize it just as you do your meals.\n\n⚠️ Disclaimer: This guide is for informational purposes only and is not a substitute for professional medical advice."
          )
        } else {
          recommendationText = recommendation
        }
        isLoadingRecommendation = false
      }
    }
  }
}
