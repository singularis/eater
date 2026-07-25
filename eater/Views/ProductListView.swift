import SwiftUI

// Uses the system's native swipe actions (leading = camera, trailing = remove)
// rather than a custom DragGesture. A custom horizontal drag here always loses
// to the main screen's paged TabView, which owns horizontal drags for switching
// to Statistics, and it also competes with the list's pull-to-refresh.
private struct FoodListRow<Content: View>: View {
  let onDelete: () -> Void
  let isDisabled: Bool
  let deleteLabel: String
  var onSwipeRight: (() -> Void)? = nil
  @ViewBuilder let content: () -> Content

  @State private var showDeleteConfirmation = false

  private func requestDelete() {
    guard !isDisabled else { return }
    HapticsService.shared.warning()
    showDeleteConfirmation = true
  }

  var body: some View {
    content()
      .background(AppTheme.backgroundGradient)
      .padding(.trailing, 44)
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
      .swipeActions(edge: .leading, allowsFullSwipe: true) {
        if let onSwipeRight {
          Button(action: onSwipeRight) {
            Label(loc("list.swipe_camera.action", "Camera"), systemImage: "camera.fill")
          }
          .tint(AppTheme.success)
        }
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
          requestDelete()
        } label: {
          Label(deleteLabel, systemImage: "trash")
        }
        .disabled(isDisabled)
      }
      .alert(
        loc("list.delete.confirm.title", "Delete Food?"), isPresented: $showDeleteConfirmation
      ) {
        Button(loc("common.cancel", "Cancel"), role: .cancel) {}
        Button(deleteLabel, role: .destructive) {
          onDelete()
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

  private static let swipeCameraHintKey = "hasSeenSwipeCameraHint"
  @State private var showSwipeCameraHintBanner = false

  var sortedProducts: [Product] {
    products.sorted { $0.time > $1.time }
  }

  private var shouldOfferSwipeCameraHint: Bool {
    onSwipeRight != nil && !KeychainHelper.shared.getBool(Self.swipeCameraHintKey)
  }

  private func dismissSwipeCameraHint() {
    KeychainHelper.shared.setBool(true, for: Self.swipeCameraHintKey)
    withAnimation(.easeOut(duration: 0.25)) {
      showSwipeCameraHintBanner = false
    }
  }

  private func maybeShowSwipeCameraHint() {
    guard shouldOfferSwipeCameraHint else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      withAnimation(.easeIn(duration: 0.3)) {
        showSwipeCameraHintBanner = true
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
        dismissSwipeCameraHint()
      }
    }
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
        ZStack(alignment: .top) {
          List {
            ForEach(sortedProducts) { product in
              FoodListRow(
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
          .onAppear {
            maybeShowSwipeCameraHint()
          }

          if showSwipeCameraHintBanner {
            SwipeCameraHintBanner(onDismiss: dismissSwipeCameraHint)
              .padding(.horizontal, 16)
              .padding(.top, 8)
              .transition(.move(edge: .top).combined(with: .opacity))
              .zIndex(1)
          }
        }
      }
    }
  }
}

/// One-time, dismissible hint that teaches the swipe-right-for-camera gesture.
private struct SwipeCameraHintBanner: View {
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "camera.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(AppTheme.success)

      Text(loc("list.swipe_camera.hint", "Tip: Swipe a meal right to quickly snap another photo"))
        .font(.footnote.weight(.medium))
        .foregroundColor(AppTheme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 4)

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(AppTheme.textSecondary.opacity(0.6))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .cardContainer(padding: 0)
    .onTapGesture {
      onDismiss()
    }
  }
}
