import SwiftUI

struct ProductRowView: View {
  let product: Product
  let deletingProductTime: Int64?
  let onPhotoTap: (UIImage?, String) -> Void
  let onModify: (Int64, String, Int32) -> Void
  let onShareSuccess: () -> Void

  var body: some View {
    ZStack(alignment: .trailing) {
      HStack(spacing: 12) {
        // Food photo - clickable for full screen
        if let image = product.image {
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
        } else {
          RoundedRectangle(cornerRadius: AppTheme.smallRadius)
            .fill(AppTheme.surfaceAlt)
            .frame(width: 80, height: 80)
            .overlay(
              Image(systemName: "photo")
                .foregroundColor(AppTheme.textSecondary)
            )
            .onTapGesture {
              if deletingProductTime != product.time {
                // Try to get image using fallback mechanism
                let image = product.image
                HapticsService.shared.select()
                onPhotoTap(image, product.name)
              }
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
            onPortionSelected: { percentage in
              HapticsService.shared.success()
              onModify(product.time, product.name, percentage)
            }, onShareSuccess: onShareSuccess)
        }
        
        Spacer()
      }
      .padding(.trailing, (product.healthRating > 0 && deletingProductTime != product.time) ? 45 : 0)

      // Separate layer for Smiley or ProgressView
      if deletingProductTime == product.time {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
          .scaleEffect(0.8)
          .padding(.trailing, 8)
      } else if product.healthRating > 0 {
        Image(systemName: getHealthRatingIconName(rating: product.healthRating))
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 40, height: 40)
          .foregroundColor(getHealthRatingColor(rating: product.healthRating))
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
  }

  private func getHealthRatingIconName(rating: Int) -> String {
    switch rating {
    case 0:
      return "exclamationmark.triangle.fill" // Hazard
    case 1:
      return "exclamationmark.triangle" // Hazard
    case 2:
      return "hand.thumbsdown.fill"
    case 3:
      return "hand.thumbsdown"
    case 4:
      return "face.dashed"
    case 5:
      return "face.expressionless"
    case 6:
      return "face.smiling"
    case 7:
      return "hand.thumbsup.fill"
    case 8:
      return "face.smiling.with.heart.eyes"
    case 9:
      return "star.fill"
    case 10:
      return "crown.fill"
    default:
      return "face.smiling"
    }
  }
  
  private func getHealthRatingColor(rating: Int) -> Color {
    // 0 is bad (red), 10 is good (green)
    // Clamp value between 0 and 10
    let clampedRating = max(0, min(10, Double(rating)))
    let normalized = clampedRating / 10.0
    
    // Simple interpolation between red and green
    // Red: 1.0 -> 0.0 (as rating increases)
    // Green: 0.0 -> 1.0 (as rating increases)
    return Color(red: 1.0 - normalized, green: normalized, blue: 0.0)
  }
}
