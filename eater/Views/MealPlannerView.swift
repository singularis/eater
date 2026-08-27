import SwiftUI

struct MealPlannerRemaining {
  let kcal: Int
  let protein: Double
  let carbs: Double
  let fats: Double
  let sugar: Double
}

struct MealPlanResult {
  let text: String
  let variant: Int
  let variantCount: Int
}

struct MealPlannerView: View {
  @Environment(\.dismiss) private var dismiss
  let remaining: MealPlannerRemaining
  let mealsToday: Int
  let languageCode: String
  var cycleToken: Int = 0

  @State private var variant = 0
  @State private var text = ""
  @State private var variantCount = 3
  @State private var loading = false
  @State private var failed = false
  @ObservedObject private var themeService = ThemeService.shared

  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            if let mascot = themeService.currentMascot.mealPlannerMascotImage {
              HStack {
                Spacer()
                Image(mascot)
                  .resizable()
                  .scaledToFit()
                  .frame(width: 96, height: 96)
                  .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                  .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                Spacer()
              }
              .padding(.top, 4)
            }

            if loading {
              HStack {
                Spacer()
                ProgressView()
                  .padding(.top, 40)
                Spacer()
              }
              Text(loc("meal_planner.loading", "Preparing a meal idea..."))
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
            } else if failed {
              Text(loc("meal_planner.error", "Could not load a meal plan. Try again."))
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)
              Button(loc("meal_planner.retry", "Retry")) {
                fetchPlan()
              }
              .buttonStyle(PressScaleButtonStyle())
            } else {
              Text(text)
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(4)
                .textSelection(.enabled)

              Text(String(format: loc("meal_planner.variant", "%d of %d"), variant + 1, variantCount))
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.top, 8)
            }
          }
          .padding()
        }
      }
      .navigationTitle(loc("meal_planner.title", "Meal Plan"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            HapticsService.shared.select()
            nextVariant()
          } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
          }
          .accessibilityLabel(loc("meal_planner.next", "Another idea"))
          .disabled(loading)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(loc("common.done", "Done")) {
            dismiss()
          }
        }
      }
    }
    .onAppear { fetchPlan() }
    .onChange(of: cycleToken) { _, token in
      if token > 0 { nextVariant() }
    }
  }

  func nextVariant() {
    variant = (variant + 1) % max(variantCount, 1)
    fetchPlan()
  }

  private func fetchPlan() {
    loading = true
    failed = false
    GRPCService().getMealSuggest(
      languageCode: languageCode,
      variant: variant,
      mealsToday: mealsToday,
      remaining: remaining
    ) { result in
      loading = false
      if let result, !result.text.isEmpty {
        text = result.text
        variantCount = max(1, result.variantCount)
        variant = result.variant
        failed = false
      } else {
        failed = text.isEmpty
      }
    }
  }
}
