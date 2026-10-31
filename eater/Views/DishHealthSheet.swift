import SwiftUI

/// Full-screen explanation for one dish. The short lines stay in the small popup.
struct DishHealthSheet: View {
  let product: Product

  @EnvironmentObject private var authService: AuthenticationService
  @Environment(\.dismiss) private var dismiss

  @State private var explaining = false
  @State private var explainText = ""

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            Text(Localization.shared.translateFoodName(product.name))
              .font(.title3.weight(.semibold))
              .foregroundColor(AppTheme.textPrimary)

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

            VStack(alignment: .leading, spacing: 6) {
              Text(loc("disc.title", "Health Information Disclaimer"))
                .font(.caption.weight(.semibold))
              Text(loc(
                "disc.notice.text",
                "This app provides general nutritional information and dietary suggestions for educational purposes only. The information is not intended to replace professional medical advice, diagnosis, or treatment."
              ))
              Text(loc(
                "disc.medical.text",
                "Always consult with a qualified healthcare provider before making any changes to your diet or nutrition plan, especially if you have medical conditions, allergies, or dietary restrictions."
              ))
            }
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
            .padding(.top, 28)
          }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .scaledNavTitle(loc("health.score.explain", "Explain"))
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { dismiss() }) {
            Text(loc("common.done", "Done"))
              .foregroundColor(AppTheme.textPrimary)
          }
        }
      }
      .onAppear(perform: explainDish)
    }
    .appInterfaceScale()
  }

  private var email: String { authService.userEmail ?? "" }

  private func explainDish() {
    if let entry = FoodScoreExplainStore.shared.dishEntry(email: email, dishTime: product.time),
      entry.basisDishTime == product.time
    {
      explainText = entry.text
      return
    }
    explaining = true
    explainText = ""
    let day = Self.dayISO(from: product.time)
    GRPCService().explainFoodScore(
      userName: email,
      day: day,
      languageCode: LanguageService.shared.currentCode,
      dishTime: product.time
    ) { result in
      explaining = false
      guard let result else { return }
      let basis = result.basisDishTime != 0 ? result.basisDishTime : product.time
      FoodScoreExplainStore.shared.saveDish(
        email: email,
        dishTime: product.time,
        text: result.text,
        basisDishTime: basis
      )
      explainText = result.text
    }
  }

  private static func dayISO(from millis: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return "" }
    return String(format: "%04d-%02d-%02d", year, month, day)
  }
}
