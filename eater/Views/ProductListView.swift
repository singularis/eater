import SwiftUI

struct ProductListView: View {
  let products: [Product]
  let onRefresh: () -> Void
  let onDelete: (Int64) -> Void
  let onModify: (Int64, String, Int32) -> Void
  let onTryAgain: (Int64, String) -> Void
  let onAddSugar: (Int64, String) -> Void
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
            ProductRowView(
              product: product,
              deletingProductTime: deletingProductTime,
              onPhotoTap: onPhotoTap,
              onModify: onModify,
              onTryAgain: onTryAgain,
              onAddSugar: onAddSugar,
              onShareSuccess: onShareSuccess
            )
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
