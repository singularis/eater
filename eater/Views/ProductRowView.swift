import SwiftUI

struct ProductRowView: View {
  let product: Product
  let deletingProductTime: Int64?
  let onPhotoTap: (UIImage?, String) -> Void
  let onModify: (Int64, String, Int32) -> Void
  let onTryAgain: (Int64, String) -> Void
  let onAddSugar: (Int64, String) -> Void
  let onShareSuccess: () -> Void

  @State private var remoteImage: UIImage? = nil
  @State private var isLoadingImage: Bool = false

  /// Returns the best available image: local first, then remote fetched
  private var displayImage: UIImage? {
    // First try local image
    if let localImage = product.image {
      return localImage
    }
    // Then try remotely fetched image
    return remoteImage
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

        // Food details - clickable for portion modification
        VStack(alignment: .leading, spacing: 4) {
          Text(Localization.shared.translateFoodName(product.name))
            .font(.headline)
            .foregroundColor(AppTheme.textPrimary)

          // Show total calories (including added sugar)
          let caloriesDisplay = product.addedSugarTsp > 0 
            ? "\(product.totalCalories) \(loc("units.kcal", "kcal")) (\(product.calories) + \(Int(product.addedSugarTsp * 20))☕)"
            : "\(product.calories) \(loc("units.kcal", "kcal"))"
          let details = "\(caloriesDisplay) • \(product.weight)\(loc("units.gram_suffix", "g"))"
          Text(details)
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)

          // Show ingredients and sugar info
          if product.addedSugarTsp > 0 {
            let sugarText = product.addedSugarTsp == 1 
              ? loc("sugar.added.1tsp", "🍬 +1 tsp sugar")
              : String(format: loc("sugar.added.multiple", "🍬 +%.1f tsp sugar"), product.addedSugarTsp)
            Text("\(product.ingredients.map { Localization.shared.translateFoodName($0) }.joined(separator: ", ")) • \(sugarText)")
              .font(.caption)
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(2)
          } else {
            Text(product.ingredients.map { Localization.shared.translateFoodName($0) }.joined(separator: ", "))
              .font(.caption)
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(2)
          }
        }
        .onTapGesture {
          HapticsService.shared.lightImpact()
          AlertHelper.showPortionSelectionAlert(
            foodName: product.name, originalWeight: product.weight, time: product.time,
            imageId: product.imageId,
            onPortionSelected: { percentage in
              HapticsService.shared.success()
              onModify(product.time, product.name, percentage)
            },
            onTryAgain: {
              HapticsService.shared.select()
              onTryAgain(product.time, product.imageId)
            },
            onAddSugar: {
              HapticsService.shared.success()
              onAddSugar(product.time, product.name)
            },
            onShareSuccess: onShareSuccess)
        }
        
        Spacer()
      }
      .padding(.trailing, (product.healthRating >= 0 && deletingProductTime != product.time) ? 45 : 0)

      // Separate layer for Smiley or ProgressView
      if deletingProductTime == product.time {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
          .scaleEffect(0.8)
          .padding(.trailing, 8)
      } else if product.healthRating >= 0 {
        HealthRatingRing(rating: product.healthRating, color: getHealthRatingColor(rating: product.healthRating))
          .frame(width: 44, height: 44)
          .onTapGesture {
            HapticsService.shared.select()

            // Check cache first
            if let cached = ProductStorageService.shared.getHealthLevel(time: product.time) {
              AlertHelper.showHealthLevelInfo(
                title: cached.title,
                description: cached.description,
                healthSummary: cached.healthSummary
              )
              return
            }

            // Fetch if not cached
            GRPCService().getFoodHealthLevel(time: product.time, foodName: product.name) { response in
              DispatchQueue.main.async {
                if let response = response {
                  // Cache the result
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
    .padding(.vertical, 8)
    .opacity(deletingProductTime == product.time ? 0.6 : 1.0)
    .onAppear {
      fetchRemoteImageIfNeeded()
    }
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
         if let token = UserDefaults.standard.string(forKey: "auth_token") {
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
    private let heartSize: CGFloat = 50
    
    var body: some View {
        // Show heart outline for excellent ratings (95-100)
        if rating >= 95 {
            ZStack {
                // Background heart (light)
                Image(systemName: "heart")
                    .font(.system(size: 44))
                    .foregroundColor(color.opacity(0.2))
                
                // Foreground heart (solid stroke)
                Image(systemName: "heart")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(color)
                
                // Rating text
                Text("\(rating)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .frame(width: heartSize, height: heartSize)
        } else {
            // Regular ring for other ratings
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
}
