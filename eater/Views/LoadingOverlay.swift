import SwiftUI

struct LoadingOverlay: View {
  let isVisible: Bool
  let message: String

  var body: some View {
    if isVisible {
      ZStack {
        Color.black.opacity(0.3)
          .edgesIgnoringSafeArea(.all)

        VStack(spacing: 16) {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.textPrimary))
            .scaleEffect(1.5)

          Text(message)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: AppTheme.cardShadow.color, radius: AppTheme.cardShadow.radius, x: AppTheme.cardShadow.x, y: AppTheme.cardShadow.y)
      }
      .animation(AppSettingsService.shared.reduceMotion ? .none : .easeInOut(duration: 0.3), value: isVisible)
    }
  }
}

#Preview {
  ZStack {
    Color.gray
    LoadingOverlay(isVisible: true, message: loc("loading.food", "Loading food data..."))
  }
}
