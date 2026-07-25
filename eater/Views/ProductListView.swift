import SwiftUI

// Custom swipe-to-delete (left) / swipe-to-camera (right) row so the gesture
// wins over TabView's paging swipe.
private struct SwipeToDeleteRow<Content: View>: View {
  let onDelete: () -> Void
  let isDisabled: Bool
  let deleteLabel: String
  var onSwipeRight: (() -> Void)? = nil
  @ViewBuilder let content: () -> Content

  private let deleteWidth: CGFloat = 100
  private let cameraRevealMax: CGFloat = 90
  private let cameraTriggerThreshold: CGFloat = 70
  @State private var offset: CGFloat = 0
  @State private var showDeleteConfirmation = false

  /// 0...1 — hide red background when not swiping left
  private var deleteRevealProgress: CGFloat {
    min(1, max(0, -offset / deleteWidth))
  }

  /// Red button is visible and tappable only after sufficient swipe
  private var isDeleteZoneActive: Bool {
    deleteRevealProgress > 0.25
  }

  /// 0...1 — hide green camera background when not swiping right
  private var cameraRevealProgress: CGFloat {
    min(1, max(0, offset / cameraRevealMax))
  }

  private func requestDelete() {
    guard !isDisabled else { return }
    HapticsService.shared.warning()
    showDeleteConfirmation = true
  }

  private func confirmDelete() {
    onDelete()
    withAnimation(.easeOut(duration: 0.15)) { offset = 0 }
  }

  private func cancelDelete() {
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
        requestDelete()
      }
      .allowsHitTesting(isDeleteZoneActive)

      // Green zone appears only on swipe right, revealing a camera hint
      if onSwipeRight != nil {
        HStack {
          Image(systemName: "camera.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(width: cameraRevealMax)
          Spacer()
        }
        .background(AppTheme.success)
        .opacity(Double(cameraRevealProgress))
        .allowsHitTesting(false)
      }

      content()
        .background(AppTheme.backgroundGradient)
        .padding(.trailing, 44)
        .offset(x: offset)
        .overlay(alignment: .trailing) {
          Button {
            requestDelete()
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
              if tx >= 0 {
                offset = onSwipeRight != nil ? min(cameraRevealMax, tx) : 0
              } else {
                offset = max(-deleteWidth, tx)
              }
            }
            .onEnded { value in
              if value.translation.width >= cameraTriggerThreshold {
                onSwipeRight?()
              }
              withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offset = 0 }
            }
        )
    }
    .clipped()
    .alert(
      loc("list.delete.confirm.title", "Delete Food?"), isPresented: $showDeleteConfirmation
    ) {
      Button(loc("common.cancel", "Cancel"), role: .cancel) {
        cancelDelete()
      }
      Button(deleteLabel, role: .destructive) {
        confirmDelete()
      }
    } message: {
      Text(
        loc(
          "list.delete.confirm.message",
          "Are you sure you want to delete this food entry? This action cannot be undone."))
    }
  }
}

struct ProductListView: View {
  let products: [Product]
  let onRefresh: () -> Void
  let onDelete: (Int64) -> Void
  let onModify: (Int64, String, Int32, Double?) -> Void
  let onTryAgain: (Int64, String) -> Void
  let onAddSugar: (Int64, String) -> Void
  var onAddDrinkExtra: ((Int64, String, String) -> Void)? = nil
  var onAddFoodExtra: ((Int64, String, String) -> Void)? = nil
  let onPhotoTap: (UIImage?, String) -> Void
  let deletingProductTime: Int64?
  let onShareSuccess: () -> Void
  var onSwipeRight: (() -> Void)? = nil

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
              deleteLabel: loc("common.remove", "Remove"),
              onSwipeRight: onSwipeRight
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
