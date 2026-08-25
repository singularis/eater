import SwiftUI
import UIKit

struct ProductRowView: View {
  let product: Product
  let deletingProductTime: Int64?
  let onPhotoTap: (UIImage?, String) -> Void
  let onModify: (Int64, String, Int32, Double?) -> Void
  let onTryAgain: (Int64, String) -> Void
  let onAddSugar: (Int64, String) -> Void
  var onAddDrinkExtra: ((Int64, String, String) -> Void)? = nil
  var onAddFoodExtra: ((Int64, String, String) -> Void)? = nil
  let onShareSuccess: () -> Void
  var onDelete: (() -> Void)? = nil

  @EnvironmentObject private var authService: AuthenticationService
  @ObservedObject private var appSettings = AppSettingsService.shared
  @State private var remoteImage: UIImage? = nil
  @State private var isLoadingImage: Bool = false
  @State private var showShareLoginPrompt = false
  @State private var showDeleteConfirmation = false

  private static let macrosLilac = Color(red: 0.72, green: 0.66, blue: 0.88)

  private var displayImage: UIImage? {
    product.image ?? remoteImage
  }

  private var detailsText: String {
    "\(product.totalCalories) \(loc("units.kcal", "kcal")) • \(product.totalWeight)\(loc("units.gram_suffix", "g"))"
  }

  private var dishFontScale: CGFloat { CGFloat(appSettings.fontScale) }
  private var photoSize: CGFloat { 101 * dishFontScale }
  private var ratingStickerSize: CGFloat { 36 * dishFontScale }
  private var actionIconFrame: CGFloat { 30 * 1.15 * 1.20 * dishFontScale }
  private var actionGlyphSize: CGFloat { actionIconFrame * 0.48 }

  private var hasDishMacros: Bool {
    (product.proteins + product.fats + product.carbohydrates + product.sugar) > 0
  }

  private func macroAmount(_ value: Double) -> String {
    let grams = loc("units.gram_suffix", "g")
    let amount = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    return "\(amount)\(grams)"
  }

  private var dishMacrosLine1: String {
    "\(loc("macro.pro", "PRO")) \(macroAmount(product.proteins)) • \(loc("macro.fat", "FAT")) \(macroAmount(product.fats))"
  }

  private var dishMacrosLine2: String {
    "\(loc("macro.car", "CAR")) \(macroAmount(product.carbohydrates)) • \(loc("macro.sug", "SUG")) \(macroAmount(product.sugar))"
  }

  /// Ingredients already named in the dish title (e.g. "Noodle", "Fried cabbage").
  private var extraIngredientNames: [String] {
    let dish = Localization.shared.translateFoodName(product.name)
    return product.ingredients.compactMap { raw in
      let name = Localization.shared.translateFoodName(raw)
      return Self.isCoveredByDishName(name, dish: dish) ? nil : name
    }
  }

  private var extrasIconsText: String {
    var parts: [String] = []
    if product.extras["lemon_5g"] != nil { parts.append("🍋") }
    if product.extras["honey_10g"] != nil { parts.append("🍯") }
    if product.extras["milk_50g"] != nil { parts.append("🥛") }
    if product.extras["soy_sauce_15g"] != nil { parts.append("🥢") }
    if product.extras["wasabi_3g"] != nil { parts.append("🌿") }
    if product.extras["spicy_pepper_5g"] != nil { parts.append("🌶") }
    return parts.joined(separator: " ")
  }

  /// True if we have any extras to show (including added sugar)
  private var hasExtras: Bool {
    !extrasIconsText.isEmpty || product.addedSugarTsp > 0 || hasAddedSugarIngredient
  }

  private var hasAddedSugarIngredient: Bool {
    product.ingredients.contains { $0.caseInsensitiveCompare("Sugar") == .orderedSame }
  }

  @ViewBuilder
  private var extrasIconsView: some View {
    HStack(spacing: 4) {
      if !extrasIconsText.isEmpty {
        Text(extrasIconsText)
      }
      if product.addedSugarTsp > 0 || hasAddedSugarIngredient {
        Image(systemName: "cube.fill")
          .font(.system(size: 14 * dishFontScale))
          .foregroundColor(AppTheme.textSecondary)
      }
    }
  }

  @ViewBuilder
  private var photoThumb: some View {
    let photo = Group {
      if let image = displayImage {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: photoSize, height: photoSize)
          .clipped()
          .cornerRadius(AppTheme.smallRadius)
          .onTapGesture {
            if deletingProductTime != product.time {
              HapticsService.shared.select()
              onPhotoTap(image, product.name)
            }
          }
      } else if isLoadingImage {
        RoundedRectangle(cornerRadius: AppTheme.smallRadius)
          .fill(AppTheme.surfaceAlt)
          .frame(width: photoSize, height: photoSize)
          .overlay(
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.textSecondary))
          )
      } else {
        RoundedRectangle(cornerRadius: AppTheme.smallRadius)
          .fill(AppTheme.surfaceAlt)
          .frame(width: photoSize, height: photoSize)
          .overlay(
            Image(systemName: product.needsRemoteFetch ? "arrow.down.circle" : "photo")
              .foregroundColor(AppTheme.textSecondary)
          )
          .onTapGesture {
            if deletingProductTime != product.time {
              if product.needsRemoteFetch {
                HapticsService.shared.select()
                fetchRemoteImageIfNeeded()
              } else {
                let image = product.image ?? remoteImage
                HapticsService.shared.select()
                onPhotoTap(image, product.name)
              }
            }
          }
          .onLongPressGesture {
            HapticsService.shared.mediumImpact()
            runDiagnostic()
          }
      }
    }

    photo.overlay(alignment: .bottomLeading) {
      if product.healthRating >= 0, deletingProductTime != product.time {
        HealthRatingRing(
          rating: product.effectiveHealthRating,
          color: getHealthRatingColor(rating: product.effectiveHealthRating),
          size: ratingStickerSize
        )
        .background(Circle().fill(AppTheme.surface.opacity(0.94)))
        .offset(x: -4, y: 6)
        .onTapGesture { presentHealthInfo() }
      }
    }
    .padding(.leading, 4)
  }

  var body: some View {
    let scale = dishFontScale
    HStack(alignment: .top, spacing: 10 * scale) {
      photoThumb

      VStack(alignment: .leading, spacing: 2 * scale) {
        Text(Localization.shared.translateFoodName(product.name))
          .font(.system(size: 16 * scale, weight: .semibold))
          .foregroundColor(AppTheme.textPrimary)
          .lineLimit(2)
          .minimumScaleFactor(0.85)

        Text(detailsText)
          .font(.system(size: 14 * scale))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)

        if hasDishMacros {
          VStack(alignment: .leading, spacing: 2 * scale) {
            Text(dishMacrosLine1)
            Text(dishMacrosLine2)
          }
          .font(.system(size: 13 * scale, weight: .medium, design: .rounded))
          .foregroundColor(Self.macrosLilac)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .allowsTightening(true)
        }

        if !extraIngredientNames.isEmpty {
          FittingIngredientsText(names: extraIngredientNames, pointSize: 13 * scale)
        }

        if hasExtras {
          extrasIconsView
            .font(.system(size: 14 * scale))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .contentShape(Rectangle())
      .onTapGesture {
        presentHealthInfo()
      }

      if deletingProductTime == product.time {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
          .scaleEffect(0.8)
          .frame(width: actionIconFrame)
      } else {
        VStack(spacing: 6 * scale) {
          shareIconButton
          moreOptionsIconButton
          deleteIconButton
        }
      }
    }
    .padding(.vertical, 4 * scale)
    .id(appSettings.fontScale)
    .opacity(deletingProductTime == product.time ? 0.6 : 1.0)
    .onAppear {
      fetchRemoteImageIfNeeded()
    }
  }

  private var shareIconButton: some View {
    Button(action: {
      HapticsService.shared.lightImpact()
      if authService.isAnonymous {
        showShareLoginPrompt = true
      } else {
        AlertHelper.showShareFriends(
          foodName: product.name, time: product.time, imageId: product.imageId,
          onShareSuccess: onShareSuccess)
      }
    }) {
      actionCircle(
        systemName: "square.and.arrow.up",
        color: AppTheme.success,
        fill: AppTheme.surface,
        glyphOffsetY: -1
      )
      .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
    .buttonStyle(.plain)
    .alert(
      loc("share.login_required.title", "Login Required"), isPresented: $showShareLoginPrompt
    ) {
      Button(loc("common.not_yet", "Not Yet"), role: .cancel) {}
      Button(loc("login.prompt.confirm", "Login Now")) {
        NotificationCenter.default.post(name: NSNotification.Name("ForceLogout"), object: nil)
      }
    } message: {
      Text(
        loc(
          "share.login_required.message",
          "Create an account or log in to share food with friends."))
    }
  }

  private var moreOptionsIconButton: some View {
    Button(action: {
      openPortionMenu()
    }) {
      actionCircle(
        systemName: "ellipsis",
        color: AppTheme.textSecondary,
        fill: AppTheme.surfaceAlt
      )
    }
    .buttonStyle(.plain)
  }

  private var deleteIconButton: some View {
    Button(action: {
      HapticsService.shared.warning()
      showDeleteConfirmation = true
    }) {
      actionCircle(
        systemName: "trash",
        color: .red,
        fill: AppTheme.surface
      )
      .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
    .buttonStyle(.plain)
    .disabled(onDelete == nil)
    .alert(
      loc("list.delete.confirm.title", "Delete Food?"), isPresented: $showDeleteConfirmation
    ) {
      Button(loc("common.cancel", "Cancel"), role: .cancel) {}
      Button(loc("common.remove", "Remove"), role: .destructive) {
        onDelete?()
      }
    } message: {
      Text(
        loc(
          "list.delete.confirm.message",
          "Are you sure you want to delete this food entry? This action cannot be undone."))
    }
  }

  private func actionCircle(
    systemName: String,
    color: Color,
    fill: Color,
    glyphOffsetY: CGFloat = 0
  ) -> some View {
    Image(systemName: systemName)
      .font(.system(size: actionGlyphSize, weight: .semibold))
      .foregroundColor(color)
      .offset(y: glyphOffsetY)
      .frame(width: actionIconFrame, height: actionIconFrame, alignment: .center)
      .background(fill)
      .clipShape(Circle())
  }

  private func openPortionMenu() {
    HapticsService.shared.lightImpact()
    AlertHelper.showPortionSelectionAlert(
      foodName: product.name,
      originalWeight: product.weight,
      time: product.time,
      imageId: product.imageId,
      isDrink: product.isDrink,
      isFruitOrVegetable: product.isFruitOrVegetable,
      onPortionSelected: { percentage, grams in
        HapticsService.shared.success()
        onModify(product.time, product.name, percentage, grams)
      },
      onTryAgain: {
        HapticsService.shared.select()
        onTryAgain(product.time, product.imageId)
      },
      onAddSugar: product.isDrink
        ? {
          HapticsService.shared.success()
          onAddSugar(product.time, product.name)
        }
        : nil,
      onAddDrinkExtra: product.isDrink
        ? { key in
          HapticsService.shared.success()
          onAddDrinkExtra?(product.time, product.name, key)
        }
        : nil,
      onAddFoodExtra: product.isDrink
        ? nil
        : { key in
          HapticsService.shared.success()
          onAddFoodExtra?(product.time, product.name, key)
        },
      onShareSuccess: onShareSuccess)
  }

  private func presentHealthInfo() {
    HapticsService.shared.select()

    if let cached = ProductStorageService.shared.getHealthLevel(time: product.time) {
      AlertHelper.showHealthLevelInfo(
        title: cached.title,
        description: cached.description,
        healthSummary: cached.healthSummary
      )
      return
    }

    GRPCService().getFoodHealthLevel(time: product.time, foodName: product.name) { response in
      DispatchQueue.main.async {
        if let response = response {
          ProductStorageService.shared.saveHealthLevel(
            time: product.time,
            title: response.title,
            description: response.description_p,
            healthSummary: response.healthSummary
          )
          AlertHelper.showHealthLevelInfo(
            title: response.title,
            description: response.description_p,
            healthSummary: response.healthSummary
          )
        }
      }
    }
  }

  private func fetchRemoteImageIfNeeded() {
    guard product.image == nil,
          product.needsRemoteFetch,
          !isLoadingImage else {
      return
    }

    isLoadingImage = true
    
    FoodPhotoService.shared.fetchPhoto(imageId: product.imageId) { image in
      isLoadingImage = false
      if let image = image {
        remoteImage = image
      }
    }
  }


  
  private func getHealthRatingColor(rating: Int) -> Color {
    // Health rating color ranges:
    // 0-39: RED (unhealthy)
    // 40-59: ORANGE (poor)
    // 60-79: YELLOW (moderate)
    // 80-94: LIGHT GREEN (good)
    // 95-100: BRIGHT GREEN (excellent)
    
    switch rating {
    case 0...39:
      // Red
      return Color(red: 1.0, green: 0.0, blue: 0.0)
    case 40..<60:
      // Orange
      return Color(red: 1.0, green: 0.6, blue: 0.0)
    case 60..<80:
      // Golden Yellow (darker for better contrast on white)
      return Color(red: 0.85, green: 0.7, blue: 0.0)
    case 80..<95:
      // Light Green (salad green)
      return Color(red: 0.5, green: 0.9, blue: 0.3)
    case 95...100:
      // Bright Green (excellent)
      return Color(red: 0.0, green: 1.0, blue: 0.0)
    default:
      // Fallback for negative or out-of-range values
      return Color.gray
    }
  }
  
  private func runDiagnostic() {
      let imageId = product.imageId
      let hasLocal = ImageStorageService.shared.imageExists(forTime: product.time)
      let hasCached = ImageStorageService.shared.cachedImageExists(forImageId: imageId)
      
      var message = "Image ID: \(imageId.isEmpty ? "EMPTY" : imageId)\n"
      message += "Local File Exists: \(hasLocal)\n"
      message += "Cached File Exists: \(hasCached)\n"
      message += "Needs Remote Fetch: \(product.needsRemoteFetch)\n"
      
      // Attempt manual network check
      if !imageId.isEmpty {
         message += "Starting Probe...\n"
         
         guard let encoded = imageId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "\(AppEnvironment.baseURL)/get_photo?image_id=\(encoded)") else {
             message += "Invalid URL construction"
             AlertHelper.showAlert(title: "Diagnostic", message: message)
             return
         }
         
         var request = URLRequest(url: url)
         if let token = KeychainHelper.shared.read("auth_token") {
             request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
         }
         
         URLSession.shared.dataTask(with: request) { _, response, error in
             DispatchQueue.main.async {
                 if let error = error {
                     message += "Probe Error: \(error.localizedDescription)"
                 } else if let http = response as? HTTPURLResponse {
                     message += "HTTP Status: \(http.statusCode)"
                     if http.statusCode == 403 { message += " (Forbidden)"}
                     if http.statusCode == 404 { message += " (Not Found)"}
                 }
                 AlertHelper.showAlert(title: "Diagnostic Result", message: message)
             }
         }.resume()
         return
      }
      
      AlertHelper.showAlert(title: "Diagnostic Result", message: message)
  }

  private static func isCoveredByDishName(_ ingredient: String, dish: String) -> Bool {
    let ingredientWords = tokenWords(ingredient)
    let dishWords = tokenWords(dish)
    guard !ingredientWords.isEmpty else { return true }
    return ingredientWords.allSatisfy { word in
      dishWords.contains { dishWord in tokensMatch(dishWord, word) }
    }
  }

  private static func tokenWords(_ value: String) -> [String] {
    value
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .split { !$0.isLetter && !$0.isNumber }
      .map(String.init)
      .filter { $0.count >= 2 }
  }

  private static func tokensMatch(_ a: String, _ b: String) -> Bool {
    if a == b { return true }
    let shortest = min(a.count, b.count)
    if shortest >= 4 && (a.hasPrefix(b) || b.hasPrefix(a)) { return true }
    guard abs(a.count - b.count) <= 2, shortest >= 4 else { return false }
    return a.prefix(3) == b.prefix(3)
  }
}

struct HealthRatingRing: View {
    let rating: Int
    let color: Color
    var size: CGFloat = 34

    var body: some View {
        let progress = max(0, min(1.0, Double(rating) / 100.0))
        let lineWidth = max(3, size * 0.1)

        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(rating)")
                .font(.system(size: size * 0.48, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }
}

private struct FittingIngredientsText: View {
  let names: [String]
  var pointSize: CGFloat = 11
  private let maxLines = 1
  @State private var fitted: String = ""

  var body: some View {
    Text(fitted)
      .font(.system(size: pointSize))
      .foregroundColor(AppTheme.textSecondary)
      .lineLimit(maxLines)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        GeometryReader { geo in
          Color.clear
            .onAppear { update(width: geo.size.width) }
            .onChange(of: geo.size.width) { _, w in update(width: w) }
        }
      )
      .onChange(of: names) { _, _ in fitted = "" }
      .onChange(of: pointSize) { _, _ in fitted = "" }
      .accessibilityLabel(names.joined(separator: ", "))
  }

  private func update(width: CGFloat) {
    let next = Self.fit(names: names, width: width, maxLines: maxLines, pointSize: pointSize)
    if next != fitted { fitted = next }
  }

  private static func fit(names: [String], width: CGFloat, maxLines: Int, pointSize: CGFloat) -> String {
    guard width > 1, !names.isEmpty else { return "" }
    let font = UIFont.systemFont(ofSize: pointSize)
    let maxHeight = font.lineHeight * CGFloat(maxLines) + 1
    var kept: [String] = []
    for name in names {
      let candidate = kept.isEmpty ? name : kept.joined(separator: ", ") + ", " + name
      let bounds = (candidate as NSString).boundingRect(
        with: CGSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font],
        context: nil
      )
      if bounds.height <= maxHeight {
        kept.append(name)
      } else if kept.isEmpty {
        return name
      } else {
        break
      }
    }
    return kept.joined(separator: ", ")
  }
}
