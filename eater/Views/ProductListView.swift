import SwiftUI

// Custom swipe-to-delete row so the gesture wins over TabView's paging swipe.
private struct SwipeToDeleteRow<Content: View>: View {
  let onDelete: () -> Void
  let isDisabled: Bool
  let deleteLabel: String
  @ViewBuilder let content: () -> Content

  private let deleteWidth: CGFloat = 100
  @State private var offset: CGFloat = 0

  /// 0...1 — hide red background when not swiping
  private var deleteRevealProgress: CGFloat {
    min(1, max(0, -offset / deleteWidth))
  }

  /// Red button is visible and tappable only after sufficient swipe
  private var isDeleteZoneActive: Bool {
    deleteRevealProgress > 0.25
  }

  private func performDelete() {
    guard !isDisabled else { return }
    HapticsService.shared.warning()
    onDelete()
    withAnimation(.easeOut(duration: 0.15)) { offset = 0 }
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      // Red zone appears only on swipe left; delete by tapping "Remove"
      HStack {
        Spacer()
        Label(deleteLabel, systemImage: "trash")
          .font(.subheadline.weight(.semibold))
          .foregroundColor(.white)
          .frame(width: deleteWidth)
      }
      .background(Color.red)
      .opacity(Double(isDeleteZoneActive ? 1 : (deleteRevealProgress / 0.25)))
      .contentShape(Rectangle())
      .onTapGesture {
        performDelete()
      }
      .allowsHitTesting(isDeleteZoneActive)

      content()
        .background(AppTheme.backgroundGradient)
        .padding(.trailing, 44)
        .offset(x: offset)
        .overlay(alignment: .trailing) {
          Button {
            performDelete()
          } label: {
            Image(systemName: "trash")
              .font(.system(size: 18, weight: .medium))
              .foregroundColor(.red)
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(isDisabled)
          .opacity(isDisabled ? 0.5 : 1)
        }
        .highPriorityGesture(
          DragGesture(minimumDistance: 24)
            .onChanged { value in
              let tx = value.translation.width
              offset = min(0, max(-deleteWidth, tx))
            }
            .onEnded { _ in
              withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offset = 0 }
            }
        )
    }
    .clipped()
  }
}

struct ProductListView: View {
  let products: [Product]
  let onRefresh: () -> Void
  let onDelete: (Int64) -> Void
  let onModify: (Int64, String, Int32) -> Void
  let onTryAgain: (Int64, String) -> Void
  let onAddSugar: (Int64, String) -> Void
  var onAddDrinkExtra: ((Int64, String, String) -> Void)? = nil
  var onAddFoodExtra: ((Int64, String, String) -> Void)? = nil
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
            SwipeToDeleteRow(
              onDelete: { onDelete(product.time) },
              isDisabled: deletingProductTime == product.time,
              deleteLabel: loc("common.remove", "Remove")
            ) {
              ProductRowView(
                product: product,
                deletingProductTime: deletingProductTime,
                onPhotoTap: onPhotoTap,
                onModify: onModify,
                onTryAgain: onTryAgain,
                onAddSugar: onAddSugar,
                onAddDrinkExtra: onAddDrinkExtra,
                onAddFoodExtra: onAddFoodExtra,
                onShareSuccess: onShareSuccess
              )
            }
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(AppTheme.textSecondary.opacity(0.3))
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
