import SwiftUI

/// Sheet-style swipe down: slides the page off and returns to Today.
/// Pull from the grabber always works. Pull on content works when the list is at the top.
struct SwipeDownToTodayModifier: ViewModifier {
  let enabled: Bool
  @Binding var isScrollAtTop: Bool
  let onDismiss: () -> Void

  @State private var dragY: CGFloat = 0
  @State private var pageHeight: CGFloat = 900

  func body(content: Content) -> some View {
    content
      .safeAreaInset(edge: .top, spacing: 0) {
        if enabled {
          Capsule()
            .fill(AppTheme.textSecondary.opacity(0.45))
            .frame(width: 40, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(drag(fromGrabber: true))
            .accessibilityLabel(loc("common.close", "Close"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { dismissAnimated() }
        }
      }
      .offset(y: enabled ? max(0, dragY) : 0)
      .background {
        GeometryReader { geo in
          Color.clear
            .onAppear { pageHeight = geo.size.height }
            .onChange(of: geo.size.height) { _, height in
              pageHeight = height
            }
        }
      }
      .simultaneousGesture(drag(fromGrabber: false))
      .onChange(of: enabled) { _, on in
        if !on { dragY = 0 }
      }
  }

  private func drag(fromGrabber: Bool) -> some Gesture {
    DragGesture(minimumDistance: 16, coordinateSpace: .global)
      .onChanged { value in
        guard enabled else { return }
        let dy = value.translation.height
        let dx = value.translation.width
        guard dy > 0, dy >= abs(dx) * 0.55 else { return }
        guard fromGrabber || isScrollAtTop || dragY > 0 else { return }
        dragY = dy
      }
      .onEnded { value in
        guard enabled else { return }
        let dy = max(dragY, value.translation.height)
        let predicted = value.predictedEndTranslation.height
        let isDown = dy > abs(value.translation.width)
        let farEnough = dy > 110 || predicted > 220
        let allowed = fromGrabber || isScrollAtTop || dragY > 40
        if isDown && farEnough && allowed {
          dismissAnimated()
        } else {
          withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            dragY = 0
          }
        }
      }
  }

  private func dismissAnimated() {
    HapticsService.shared.select()
    let target = max(pageHeight, 700)
    withAnimation(.easeIn(duration: 0.22)) {
      dragY = target
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
      onDismiss()
      dragY = 0
    }
  }
}

extension View {
  func swipeDownToToday(
    enabled: Bool,
    isScrollAtTop: Binding<Bool>,
    onDismiss: @escaping () -> Void
  ) -> some View {
    modifier(
      SwipeDownToTodayModifier(
        enabled: enabled,
        isScrollAtTop: isScrollAtTop,
        onDismiss: onDismiss
      )
    )
  }

  func reportScrollAtTop(_ isAtTop: Binding<Bool>) -> some View {
    onScrollGeometryChange(for: Bool.self) { geometry in
      geometry.contentOffset.y <= 8
    } action: { _, atTop in
      isAtTop.wrappedValue = atTop
    }
  }
}
