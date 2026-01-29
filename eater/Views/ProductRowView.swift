import SwiftUI

struct ProductRowView: View {
  let product: Product
  let deletingProductTime: Int64?
  let onPhotoTap: (UIImage?, String) -> Void
  let onModify: (Int64, String, Int32) -> Void
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
          Text(product.name)
            .font(.headline)
            .foregroundColor(AppTheme.textPrimary)

          let details =
            "\(product.calories) \(loc("units.kcal", "kcal")) • \(product.weight)\(loc("units.gram_suffix", "g"))"
          Text(details)
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)

          Text(product.ingredients.joined(separator: ", "))
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(2)
        }
        .onTapGesture {
          HapticsService.shared.lightImpact()
          AlertHelper.showPortionSelectionAlert(
            foodName: product.name, originalWeight: product.weight, time: product.time,
            imageId: product.imageId,
            onPortionSelected: { percentage in
              HapticsService.shared.success()
              onModify(product.time, product.name, percentage)
            }, onShareSuccess: onShareSuccess)
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
    // 0 is bad (red), 10 is good (green)
    let maxRating: Double = 100.0
    let clampedRating = max(0, min(maxRating, Double(rating)))
    let normalized = clampedRating / maxRating
    
    // Vibrant gradient: Red -> Orange -> Yellow -> Green
    // This ensures 0 is clearly red, and we move through orange/yellow to green
    
    if normalized < 0.5 {
        // Red (1.0, 0.0, 0.0) -> Yellow (1.0, 1.0, 0.0)
        // Red stays 1.0, Green increases
        let green = normalized * 2.0
        return Color(red: 1.0, green: green, blue: 0.0)
    } else {
        // Yellow (1.0, 1.0, 0.0) -> Green (0.0, 1.0, 0.0)
        // Green stays 1.0, Red decreases
        let red = 1.0 - (normalized - 0.5) * 2.0
        return Color(red: red, green: 1.0, blue: 0.0)
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
               let url = URL(string: "https://chater.singularis.work/get_photo?image_id=\(encoded)") else {
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
    
    var body: some View {
        let maxRating: Double = 100.0
        let progress = max(0, min(1.0, Double(rating) / maxRating))
        
        return ZStack {
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
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}
