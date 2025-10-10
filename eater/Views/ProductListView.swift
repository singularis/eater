import SwiftUI

struct ProductListView: View {
  let products: [Product]
  let onRefresh: () -> Void
  let onDelete: (Int64) -> Void
  let onModify: (Int64, String, Int32) -> Void
  let onPhotoTap: (UIImage?, String) -> Void
  let deletingProductTime: Int64?
  let onShareSuccess: () -> Void

  var sortedProducts: [Product] {
    products.sorted { $0.time > $1.time }
  }

  var body: some View {
    Group {
      if sortedProducts.isEmpty {
        ScrollView {
          VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
              .font(.system(size: 64))
              .foregroundColor(AppTheme.textSecondary.opacity(0.5))
            
            Text(loc("list.empty.title", "No meals yet"))
              .font(.title2)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.textPrimary)
            
            Text(loc("list.empty.subtitle", "Add your first meal from the Home screen."))
              .font(.subheadline)
              .foregroundColor(AppTheme.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 32)
          }
          .frame(maxWidth: .infinity)
          .frame(minHeight: UIScreen.main.bounds.height - 400)
        }
        .refreshable {
          onRefresh()
        }
      } else {
        List {
          ForEach(sortedProducts) { product in
            VStack(spacing: 6) {
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

              if deletingProductTime == product.time {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                  .scaleEffect(0.8)
              }
              }
              .padding(.vertical, 8)
              .opacity(deletingProductTime == product.time ? 0.6 : 1.0)
            
            }
            .listRowBackground(Color.clear)
            .swipeActions {
              Button {
                HapticsService.shared.warning()
                onDelete(product.time)
              } label: {
                Text(loc("common.remove", "Remove"))
              }
              .tint(.red)
              .disabled(deletingProductTime == product.time)
            }
          }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .padding(.top, 0)
        .refreshable {
          onRefresh()
        }
        .animation(AppSettingsService.shared.reduceMotion ? .none : .easeInOut(duration: 0.2), value: products)
      }
    }
  }
}
