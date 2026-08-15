import SwiftUI
import UIKit

struct ProductRowView: View {
  let product: Product
  let deletingProductTime: Int64?
  let onPhotoTap: (UIImage?, String) -> Void
  let onModify: (Int64, String, Int32, Double?) -> Void
  let onTryAgain: (Int64, String) -> Void
  let onAddSugar: (Int64, String) -> Void
  var onAddDrinkExtra: ((Int64, String, String) -> Void)? = nil  // time, foodName, extraKey
  var onAddFoodExtra: ((Int64, String, String) -> Void)? = nil  // time, foodName, extraKey
  let onShareSuccess: () -> Void

  @EnvironmentObject private var authService: AuthenticationService
  @State private var remoteImage: UIImage? = nil
  @State private var isLoadingImage: Bool = false
  @State private var showShareLoginPrompt = false

  private static let macrosLilac = Color(red: 0.72, green: 0.66, blue: 0.88)

  /// Returns the best available image: local first, then remote fetched
  private var displayImage: UIImage? {
    // First try local image
    if let localImage = product.image {
      return localImage
    }
    // Then try remotely fetched image
    return remoteImage
  }

  private var detailsText: String {
    "\(product.totalCalories) \(loc("units.kcal", "kcal")) • \(product.totalWeight)\(loc("units.gram_suffix", "g"))"
  }

  private var hasDishMacros: Bool {
    (product.proteins + product.fats + product.carbohydrates + product.sugar) > 0
  }

  private var dishMacrosText: String {
    let grams = loc("units.gram_suffix", "g")
    func fmt(_ v: Double) -> String {
      v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }
    let line1 = [
      "\(loc("macro.pro", "PRO")) \(fmt(product.proteins))\(grams)",
      "\(loc("macro.fat", "FAT")) \(fmt(product.fats))\(grams)",
    ].joined(separator: " · ")
    let line2 = [
      "\(loc("macro.car", "CAR")) \(fmt(product.carbohydrates))\(grams)",
      "\(loc("macro.sug", "SUG")) \(fmt(product.sugar))\(grams)",
    ].joined(separator: " · ")
    return "\(line1)\n\(line2)"
  }

  private var extrasIconsText: String {
    var parts: [String] = []
    if product.extras["lemon_5g"] != nil { parts.append("🍋") }
    if product.extras["honey_10g"] != nil { parts.append("🍯") }
    if product.extras["milk_50g"] != nil { parts.append("🥛") }
    if product.extras["soy_sauce_15g"] != nil { parts.append("🥢") }
    if product.extras["wasabi_3g"] != nil { parts.append("🌿") }
    if product.extras["spicy_pepper_5g"] != nil { parts.append("🌶") }
    // Sugar (refined/cube) shown via extrasIconsView, not emoji
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
          .font(.system(size: 12))
          .foregroundColor(AppTheme.textSecondary)
      }
    }
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      HStack(spacing: 12) {
        // Food photo - clickable for full screen
        if let image = displayImage {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 80, height: 80)
            .clipped()
            .cornerRadius(AppTheme.smallRadius)
            .onTapGesture {
              if deletingProductTime != product.time {
                HapticsService.shared.select()
                onPhotoTap(image, product.name)
              }
            }
        } else if isLoadingImage {
          // Show loading indicator while fetching
          RoundedRectangle(cornerRadius: AppTheme.smallRadius)
            .fill(AppTheme.surfaceAlt)
            .frame(width: 80, height: 80)
            .overlay(
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.textSecondary))
            )
        } else {
          // Placeholder - no image available
          RoundedRectangle(cornerRadius: AppTheme.smallRadius)
            .fill(AppTheme.surfaceAlt)
            .frame(width: 80, height: 80)
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
                    // Try to get image using fallback mechanism
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

        // Food details — tap still opens options; ⋯ is the visible control
        VStack(alignment: .leading, spacing: 4) {
          Text(Localization.shared.translateFoodName(product.name))
            .font(.headline)
            .foregroundColor(AppTheme.textPrimary)

          Text(detailsText)
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)

          FittingIngredientsText(names: product.ingredients.map { Localization.shared.translateFoodName($0) })

          if hasDishMacros {
            Text(dishMacrosText)
              .font(.caption.weight(.medium))
              .foregroundColor(Self.macrosLilac)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
              .minimumScaleFactor(0.9)
          }

          // Extras icons (refined sugar = cube, others = emoji)
          if hasExtras {
            extrasIconsView
              .font(.caption)
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(1)
          }
        }
        .onTapGesture {
          openPortionMenu()
        }
        
        Spacer()
      }
      .padding(.trailing, deletingProductTime != product.time ? 68 : 0)

      // Share icon + health ring (or a loading spinner while deleting)
      if deletingProductTime == product.time {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
          .scaleEffect(0.8)
          .padding(.trailing, 8)
      } else {
        VStack(alignment: .trailing, spacing: 6) {
          HStack(spacing: 8) {
            shareIconButton
            moreOptionsIconButton
          }
          if product.healthRating >= 0 {
            HealthRatingRing(
              rating: product.effectiveHealthRating,
              color: getHealthRatingColor(rating: product.effectiveHealthRating)
            )
              .frame(width: 44, height: 44)
              .onTapGesture {
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
          }
        }
      }
    }
    .padding(.vertical, 8)
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
      Image(systemName: "square.and.arrow.up")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(AppTheme.success)
        .frame(width: 32, height: 32)
        .background(AppTheme.surface)
        .clipShape(Circle())
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
      Image(systemName: "ellipsis.circle.fill")
        .font(.system(size: 22))
        .foregroundColor(AppTheme.textSecondary)
        .frame(width: 32, height: 32)
    }
    .buttonStyle(.plain)
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

  /// Fetches the image from the backend if needed
  private func fetchRemoteImageIfNeeded() {
    // Only fetch if there's no local image and we have an imageId
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
}

struct HealthRatingRing: View {
    let rating: Int
    let color: Color
    
    private let circleSize: CGFloat = 40
    
    var body: some View {
        // Always use circle (ring); heart is only for the average in the top bar
        let maxRating: Double = 100.0
        let progress = max(0, min(1.0, Double(rating) / maxRating))
        
        ZStack {
            // Background track
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Rating text
            Text("\(rating)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(width: circleSize, height: circleSize)
    }
}

private struct FittingIngredientsText: View {
  let names: [String]
  private let maxLines = 2
  @State private var fitted: String = ""

  var body: some View {
    Text(fitted)
      .font(.caption)
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
      .accessibilityLabel(names.joined(separator: ", "))
  }

  private func update(width: CGFloat) {
    let next = Self.fit(names: names, width: width, maxLines: maxLines)
    if next != fitted { fitted = next }
  }

  private static func fit(names: [String], width: CGFloat, maxLines: Int) -> String {
    guard width > 1, !names.isEmpty else { return "" }
    let font = UIFont.preferredFont(forTextStyle: .caption1)
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
