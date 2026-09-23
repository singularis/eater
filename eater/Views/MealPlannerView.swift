import SwiftUI

struct MealPlannerRemaining: Equatable {
  let kcal: Int
  let protein: Double
  let carbs: Double
  let fats: Double
  let sugar: Double
}

struct MealPlanResult {
  let text: String
  let name: String
  let why: String
  let howTo: String
  let basedOn: String
  let variant: Int
  let variantCount: Int
}

struct MealPlannerView: View {
  @Environment(\.dismiss) private var dismiss
  let remaining: MealPlannerRemaining
  let mealsToday: Int
  let languageCode: String
  var cycleToken: Int = 0
  var embedded: Bool = false
  /// When false (hidden tab), do not hit the LLM. TabView can appear this view at launch.
  var isActive: Bool = true

  @State private var variant = 0
  @State private var result: MealPlanResult?
  @State private var variantCount = 3
  @State private var loading = false
  @State private var failed = false
  @ObservedObject private var themeService = ThemeService.shared

  var body: some View {
    Group {
      if embedded {
        plannerStack
      } else {
        NavigationView {
          ZStack {
            AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
            ScrollView {
              plannerStack
            }
          }
          .navigationTitle(loc("meal_planner.title", "Meal Plan"))
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
              cycleButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
              Button(loc("common.done", "Done")) {
                dismiss()
              }
            }
          }
        }
      }
    }
    .onAppear { loadIfNeeded() }
    .onChange(of: isActive) { _, active in
      if active { loadIfNeeded() }
    }
    .onChange(of: cycleToken) { _, token in
      if token > 0 { nextVariant() }
    }
  }

  private var cycleButton: some View {
    Button {
      HapticsService.shared.select()
      nextVariant()
    } label: {
      Image(systemName: "arrow.triangle.2.circlepath")
    }
    .accessibilityLabel(loc("meal_planner.next", "Another idea"))
    .disabled(loading)
  }

  private var plannerStack: some View {
    VStack(alignment: .leading, spacing: 16) {
      if embedded {
        HStack {
          Text(loc("meal_planner.title", "Meal Plan"))
            .font(.title3.weight(.bold))
            .foregroundColor(AppTheme.textPrimary)
          Spacer()
          cycleButton
        }
      }

      if let mascot = themeService.currentMascot.mealPlannerMascotImage {
        HStack {
          Spacer()
          Image(mascot)
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
            )
            .appCardShadow()
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
          .fixedSize(horizontal: false, vertical: true)
        Button(loc("meal_planner.retry", "Retry")) {
          fetchPlan()
        }
        .buttonStyle(PrimaryButtonStyle())
      } else if let result {
        mealContent(result)
        Text(String(format: loc("meal_planner.variant", "%d of %d"), variant + 1, variantCount))
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)
          .padding(.top, 4)
      }
    }
    .padding(embedded ? 0 : 16)
  }

  @ViewBuilder
  private func mealContent(_ result: MealPlanResult) -> some View {
    if result.name.isEmpty {
      Text(result.text)
        .font(.body)
        .foregroundColor(AppTheme.textPrimary)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    } else {
      VStack(alignment: .leading, spacing: 18) {
        Text(result.name)
          .font(.title2.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)

        if !result.why.isEmpty {
          labeledBlock(title: loc("meal.why", "Why this"), body: result.why)
        }

        if !result.howTo.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text(loc("meal.how_to", "How to make it"))
              .font(.subheadline.weight(.semibold))
              .foregroundColor(AppTheme.textPrimary)
            Text(loc("meal.cook_time", "About 15-20 min"))
              .font(.caption)
              .foregroundColor(AppTheme.textSecondary)
            Text(result.howTo)
              .font(.body)
              .foregroundColor(AppTheme.textPrimary)
              .lineSpacing(5)
              .fixedSize(horizontal: false, vertical: true)
              .textSelection(.enabled)
          }
        }

        let chips = basedOnChips(result.basedOn)
        if !chips.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text(loc("meal.based_on", "From your week"))
              .font(.subheadline.weight(.semibold))
              .foregroundColor(AppTheme.textPrimary)
            MealChipWrap(chips: chips)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .appSurface()
    }
  }

  private func labeledBlock(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AppTheme.textPrimary)
      Text(body)
        .font(.body)
        .foregroundColor(AppTheme.textPrimary)
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }
  }

  private func basedOnChips(_ basedOn: String) -> [String] {
    basedOn
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  func nextVariant() {
    variant = (variant + 1) % max(variantCount, 1)
    fetchPlan()
  }

  private func loadIfNeeded() {
    guard isActive else { return }
    guard !loading else { return }
    if result != nil, !failed { return }
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
    ) { newResult in
      loading = false
      if let newResult, !newResult.name.isEmpty || !newResult.text.isEmpty {
        result = newResult
        variantCount = max(1, newResult.variantCount)
        variant = newResult.variant
        failed = false
      } else {
        failed = result == nil
      }
    }
  }
}

private struct MealChipWrap: View {
  let chips: [String]

  var body: some View {
    MealFlowLayout(spacing: 8) {
      ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
        Text(chip)
          .font(.caption.weight(.medium))
          .foregroundColor(AppTheme.textPrimary)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(AppTheme.surfaceAlt)
          .clipShape(Capsule())
          .overlay(
            Capsule()
              .stroke(AppTheme.divider, lineWidth: 1)
          )
      }
    }
  }
}

private struct MealFlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    layout(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let result = layout(in: bounds.width, subviews: subviews)
    for (index, origin) in result.origins.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
        proposal: .unspecified
      )
    }
  }

  private func layout(in width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
    var origins: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var maxX: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0 && x + size.width > width {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      origins.append(CGPoint(x: x, y: y))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      maxX = max(maxX, x - spacing)
    }
    return (origins, CGSize(width: max(maxX, 0), height: y + rowHeight))
  }
}
