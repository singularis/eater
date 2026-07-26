import SwiftUI

/// Food rows and the Home screen's swipe-for-camera both react to horizontal
/// drags. A row handling one claims it here so the camera swipe stays out of
/// the way; only free space (empty list area, chrome) opens the camera.
final class FoodSwipeArbiter {
  static let shared = FoodSwipeArbiter()
  private(set) var rowSwipeActive = false
  private var release: DispatchWorkItem?

  func beginRowSwipe() {
    release?.cancel()
    rowSwipeActive = true
  }

  func endRowSwipe() {
    release?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.rowSwipeActive = false }
    release = work
    // Both gestures end on the same touch-up with no guaranteed ordering,
    // so the claim outlives the row's own gesture by a moment.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
  }
}

// Custom swipe on food rows:
//   right → same options menu as the ⋯ button
//   left  → delete (with confirmation)
// Action chips are compact (not full-bleed strips) so they don't cover the card.
private struct FoodListRow<Content: View>: View {
  let onDelete: () -> Void
  let isDisabled: Bool
  let deleteLabel: String
  var onSwipeOptions: (() -> Void)? = nil
  @ViewBuilder let content: () -> Content

  private let actionSize: CGFloat = 64
  private let revealWidth: CGFloat = 80
  private let triggerThreshold: CGFloat = 56
  @State private var offset: CGFloat = 0
  @State private var showDeleteConfirmation = false

  private var deleteRevealProgress: CGFloat {
    min(1, max(0, -offset / revealWidth))
  }

  private var isDeleteZoneActive: Bool {
    deleteRevealProgress > 0.25
  }

  private var optionsRevealProgress: CGFloat {
    min(1, max(0, offset / revealWidth))
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

  private var deleteActionChip: some View {
    Button {
      requestDelete()
    } label: {
      VStack(spacing: 4) {
        Image(systemName: "trash.fill")
          .font(.system(size: 18, weight: .semibold))
        Text(deleteLabel)
          .font(.system(size: 10, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .foregroundColor(.white)
      .frame(width: actionSize, height: actionSize)
      .background(Color.red)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
    .opacity(Double(isDeleteZoneActive ? 1 : (deleteRevealProgress / 0.25)))
    .scaleEffect(0.85 + 0.15 * deleteRevealProgress)
    .allowsHitTesting(isDeleteZoneActive)
  }

  private var optionsActionChip: some View {
    Button {
      HapticsService.shared.lightImpact()
      onSwipeOptions?()
      withAnimation(.easeOut(duration: 0.15)) { offset = 0 }
    } label: {
      VStack(spacing: 4) {
        Image(systemName: "ellipsis.circle.fill")
          .font(.system(size: 20, weight: .semibold))
        Text(loc("list.swipe_options.action", "Options"))
          .font(.system(size: 10, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .foregroundColor(.white)
      .frame(width: actionSize, height: actionSize)
      .background(AppTheme.accent)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
    .opacity(Double(optionsRevealProgress))
    .scaleEffect(0.85 + 0.15 * optionsRevealProgress)
    .allowsHitTesting(optionsRevealProgress > 0.5)
  }

  var body: some View {
    ZStack {
      // Compact chips only — no full-height colored bands behind the card
      HStack {
        if onSwipeOptions != nil {
          optionsActionChip
            .padding(.leading, 8)
        }
        Spacer(minLength: 0)
        deleteActionChip
          .padding(.trailing, 8)
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
        // minimumDistance keeps vertical list scroll / pull-to-refresh intact
        .gesture(
          DragGesture(minimumDistance: 24)
            .onChanged { value in
              let tx = value.translation.width
              let ty = value.translation.height
              guard abs(tx) > abs(ty) else { return }
              FoodSwipeArbiter.shared.beginRowSwipe()
              if tx >= 0 {
                offset = onSwipeOptions != nil ? min(revealWidth, tx) : 0
              } else {
                offset = max(-revealWidth, tx)
              }
            }
            .onEnded { value in
              let tx = value.translation.width
              let ty = value.translation.height
              if abs(tx) > abs(ty), tx >= triggerThreshold {
                HapticsService.shared.lightImpact()
                onSwipeOptions?()
              }
              FoodSwipeArbiter.shared.endRowSwipe()
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

  private static let swipeOptionsHintKey = "hasSeenSwipeOptionsHint"
  @State private var showSwipeOptionsHintBanner = false

  var sortedProducts: [Product] {
    products.sorted { $0.time > $1.time }
  }

  private var shouldOfferSwipeOptionsHint: Bool {
    !KeychainHelper.shared.getBool(Self.swipeOptionsHintKey)
  }

  private func dismissSwipeOptionsHint() {
    KeychainHelper.shared.setBool(true, for: Self.swipeOptionsHintKey)
    withAnimation(.easeOut(duration: 0.25)) {
      showSwipeOptionsHintBanner = false
    }
  }

  private func maybeShowSwipeOptionsHint() {
    guard shouldOfferSwipeOptionsHint else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      withAnimation(.easeIn(duration: 0.3)) {
        showSwipeOptionsHintBanner = true
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
        dismissSwipeOptionsHint()
      }
    }
  }

  private func openOptions(for product: Product) {
    AlertHelper.showPortionSelectionAlert(
      foodName: product.name,
      originalWeight: product.weight,
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
        }
    )
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
                onSwipeOptions: { openOptions(for: product) }
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
          .animation(
            AppSettingsService.shared.reduceMotion ? .none : .easeInOut(duration: 0.2),
            value: products)
          .onAppear {
            maybeShowSwipeOptionsHint()
          }

          if showSwipeOptionsHintBanner {
            SwipeOptionsHintBanner(onDismiss: dismissSwipeOptionsHint)
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

/// One-time hint for swipe-right → options on a food card.
private struct SwipeOptionsHintBanner: View {
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "ellipsis.circle.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(AppTheme.accent)

      Text(loc("list.swipe_options.hint", "Tip: Swipe a meal right to open options"))
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
