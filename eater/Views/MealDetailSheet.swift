import SwiftUI

struct MealDetailSheet: View {
  let product: Product
  let onModify: (Int64, String, Int32, Double?) -> Void
  let onTryAgain: (Int64, String) -> Void
  let onAddSugar: (Int64, String) -> Void
  var onAddDrinkExtra: ((Int64, String, String) -> Void)? = nil
  var onAddFoodExtra: ((Int64, String, String) -> Void)? = nil
  let onShareSuccess: () -> Void
  var onPhotoTap: ((UIImage?, String) -> Void)? = nil

  @EnvironmentObject private var authService: AuthenticationService
  @Environment(\.dismiss) private var dismiss
  @State private var customGrams = ""
  @State private var showShareLoginPrompt = false
  @State private var healthTitle = ""
  @State private var healthDescription = ""
  @State private var healthSummary = ""
  @State private var isLoadingHealth = false

  private var displayImage: UIImage? { product.image }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            header
            macrosBlock
            if !healthTitle.isEmpty || isLoadingHealth {
              healthBlock
            }
            portionBlock
            extrasBlock
            actionsBlock
          }
          .padding(16)
        }
      }
      .navigationTitle(loc("meal.detail.title", "Meal"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(loc("common.done", "Done")) { dismiss() }
        }
      }
      .onAppear { loadHealth() }
      .alert(
        loc("share.login_required.title", "Login Required"),
        isPresented: $showShareLoginPrompt
      ) {
        Button(loc("common.not_yet", "Not Yet"), role: .cancel) {}
        Button(loc("login.prompt.confirm", "Login Now")) {
          AppNavigation.shared.showInPlaceLogin = true
        }
      } message: {
        Text(
          loc(
            "share.login_required.message",
            "Create an account or log in to share food with friends."))
      }
    }
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 14) {
      Group {
        if let image = displayImage {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
        } else {
          RoundedRectangle(cornerRadius: AppTheme.smallRadius)
            .fill(AppTheme.surfaceAlt)
            .overlay(Image(systemName: "photo").foregroundColor(AppTheme.textSecondary))
        }
      }
      .frame(width: 88, height: 88)
      .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallRadius, style: .continuous))
      .onTapGesture {
        onPhotoTap?(displayImage, product.name)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text(Localization.shared.translateFoodName(product.name))
          .font(.title3.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
        Text("\(product.totalCalories) \(loc("units.kcal", "kcal")) • \(product.totalWeight)\(loc("units.gram_suffix", "g"))")
          .font(.subheadline)
          .foregroundColor(AppTheme.textSecondary)
        if product.healthRating >= 0 {
          Text("\(product.effectiveHealthRating)")
            .font(.caption.weight(.bold))
            .foregroundColor(healthColor(product.effectiveHealthRating))
        }
      }
      Spacer(minLength: 0)
    }
  }

  private var macrosBlock: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(loc("meal.detail.macros", "Macros"))
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)
      Text(
        "\(loc("macro.pro", "PRO")) \(fmt(product.proteins)) • \(loc("macro.fat", "FAT")) \(fmt(product.fats)) • \(loc("macro.car", "CAR")) \(fmt(product.carbohydrates)) • \(loc("macro.sug", "SUG")) \(fmt(product.sugar))"
      )
      .font(.subheadline.weight(.medium))
      .foregroundColor(AppTheme.textSecondary)
    }
  }

  @ViewBuilder
  private var healthBlock: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(loc("health.score.section.title", "Your Health Score"))
        .font(.headline)
      if isLoadingHealth {
        ProgressView()
      } else {
        if !healthTitle.isEmpty {
          Text(healthTitle)
            .font(.subheadline.weight(.semibold))
        }
        if !healthSummary.isEmpty {
          Text(healthSummary)
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)
        }
        if !healthDescription.isEmpty {
          Text(healthDescription)
            .font(.body)
            .foregroundColor(AppTheme.textPrimary)
        }
      }
    }
  }

  private var portionBlock: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(loc("portion.modify.title", "Modify Portion"))
        .font(.headline)
      let portions: [(String, Int32)] = [
        (loc("meal.detail.portion_50", "50%"), 50),
        (loc("meal.detail.portion_75", "75%"), 75),
        (loc("meal.detail.portion_125", "125%"), 125),
        (loc("meal.detail.portion_150", "150%"), 150),
        (loc("meal.detail.portion_200", "200%"), 200),
      ]
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
        ForEach(portions, id: \.1) { title, pct in
          Button(title) {
            onModify(product.time, product.name, pct, nil)
            dismiss()
          }
          .buttonStyle(SecondaryButtonStyle())
        }
      }
      HStack {
        TextField(loc("portion.custom.manual_placeholder", "e.g. 146.4"), text: $customGrams)
          .keyboardType(.decimalPad)
          .textFieldStyle(.roundedBorder)
        Button(loc("common.save", "Submit")) {
          let normalized = customGrams.replacingOccurrences(of: ",", with: ".")
          guard let grams = Double(normalized), grams > 0, product.weight > 0 else { return }
          let pct = Int32((grams / Double(product.weight) * 100.0).rounded())
          onModify(product.time, product.name, pct, grams)
          dismiss()
        }
        .buttonStyle(PrimaryButtonStyle())
      }
    }
  }

  @ViewBuilder
  private var extrasBlock: some View {
    if product.isFruitOrVegetable {
      EmptyView()
    } else {
      VStack(alignment: .leading, spacing: 8) {
        Text(loc("portion.additional", "Additives"))
          .font(.headline)
        if product.isDrink {
          extraButton(loc("portion.extra.lemon", "Lemon 5g")) {
            onAddDrinkExtra?(product.time, product.name, "lemon_5g")
          }
          extraButton(loc("portion.extra.honey", "Honey 10g")) {
            onAddDrinkExtra?(product.time, product.name, "honey_10g")
          }
          extraButton(loc("portion.extra.milk", "Milk 50g")) {
            onAddDrinkExtra?(product.time, product.name, "milk_50g")
          }
          extraButton(loc("portion.add_extra", "Add 1 tsp sugar")) {
            onAddSugar(product.time, product.name)
          }
        } else {
          extraButton(loc("portion.extra.soy", "Soy sauce 15g")) {
            onAddFoodExtra?(product.time, product.name, "soy_sauce_15g")
          }
          extraButton(loc("portion.extra.wasabi", "Wasabi 3g")) {
            onAddFoodExtra?(product.time, product.name, "wasabi_3g")
          }
          extraButton(loc("portion.extra.pepper", "Spicy pepper 5g")) {
            onAddFoodExtra?(product.time, product.name, "spicy_pepper_5g")
          }
        }
      }
    }
  }

  private var actionsBlock: some View {
    VStack(spacing: 10) {
      Button(loc("portion.share", "Share food with friend")) {
        if authService.isAnonymous {
          showShareLoginPrompt = true
        } else {
          AlertHelper.showShareFriends(
            foodName: product.name, time: product.time, imageId: product.imageId,
            onShareSuccess: {
              onShareSuccess()
              dismiss()
            })
        }
      }
      .buttonStyle(SecondaryButtonStyle())

      Button(loc("common.try_manual", "Try manually")) {
        if authService.isAnonymous {
          showShareLoginPrompt = true
        } else {
          onTryAgain(product.time, product.imageId)
          dismiss()
        }
      }
      .buttonStyle(SecondaryButtonStyle())
    }
  }

  private func extraButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(title) {
      action()
      dismiss()
    }
    .buttonStyle(SecondaryButtonStyle())
  }

  private func fmt(_ value: Double) -> String {
    let grams = loc("units.gram_suffix", "g")
    let amount = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    return "\(amount)\(grams)"
  }

  private func healthColor(_ rating: Int) -> Color {
    switch rating {
    case 0...39: return Color(red: 1.0, green: 0.0, blue: 0.0)
    case 40..<60: return Color(red: 1.0, green: 0.6, blue: 0.0)
    case 60..<80: return Color(red: 0.85, green: 0.7, blue: 0.0)
    case 80..<95: return Color(red: 0.5, green: 0.9, blue: 0.3)
    default: return Color(red: 0.0, green: 1.0, blue: 0.0)
    }
  }

  private func loadHealth() {
    if let cached = ProductStorageService.shared.getHealthLevel(time: product.time) {
      healthTitle = cached.title
      healthDescription = cached.description
      healthSummary = cached.healthSummary
      return
    }
    isLoadingHealth = true
    GRPCService().getFoodHealthLevel(time: product.time, foodName: product.name) { response in
      DispatchQueue.main.async {
        isLoadingHealth = false
        guard let response else { return }
        ProductStorageService.shared.saveHealthLevel(
          time: product.time,
          title: response.title,
          description: response.description_p,
          healthSummary: response.healthSummary
        )
        healthTitle = response.title
        healthDescription = response.description_p
        healthSummary = response.healthSummary
      }
    }
  }
}
