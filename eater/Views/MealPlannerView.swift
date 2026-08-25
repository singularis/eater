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
  @State private var variantCount = 5
  @State private var loading = false
  @State private var failed = false
  @State private var showExtras = false
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

              if remaining.kcal >= 80 {
                extrasButton
              }
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

  private var extrasButton: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button {
        HapticsService.shared.select()
        withAnimation(.easeInOut(duration: 0.2)) {
          showExtras.toggle()
        }
      } label: {
        HStack(spacing: 8) {
          Text(MealPlannerEngine.extrasTitle(language: languageCode))
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.textPrimary)
          Spacer()
          Image(systemName: showExtras ? "chevron.up" : "chevron.down")
            .font(.footnote.weight(.semibold))
            .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous)
            .stroke(AppTheme.divider, lineWidth: 1)
        )
      }
      .buttonStyle(PressScaleButtonStyle())
      .accessibilityHint(MealPlannerEngine.extrasTitle(language: languageCode))

      if showExtras {
        Text(MealPlannerEngine.extraTips(language: languageCode))
          .font(.body)
          .foregroundColor(AppTheme.textPrimary)
          .lineSpacing(4)
          .textSelection(.enabled)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(.top, 8)
  }

  func nextVariant() {
    variant = (variant + 1) % max(variantCount, 1)
    fetchPlan()
  }

  private func fetchPlan() {
    let local = MealPlannerEngine.plan(
      language: languageCode,
      variant: variant,
      mealsToday: mealsToday,
      remaining: remaining
    )
    text = local.text
    variantCount = local.variantCount
    variant = local.variant
    failed = false
    loading = false

    GRPCService().fetchMealPlan(
      languageCode: languageCode,
      variant: variant,
      mealsToday: mealsToday,
      remaining: remaining
    ) { result in
      if let result, !result.text.isEmpty {
        self.text = result.text
        self.variantCount = max(1, result.variantCount)
        self.variant = result.variant
      }
    }
  }
}
