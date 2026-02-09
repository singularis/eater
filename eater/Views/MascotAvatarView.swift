import SwiftUI

/// Displays the current theme mascot for a specific state (happy, gym, etc.)
struct MascotAvatarView: View {
  let state: MascotState
  let size: CGFloat
  @StateObject private var themeService = ThemeService.shared
  
  var body: some View {
    if themeService.currentMascot != .none,
       let imageName = themeService.getMascotImage(for: state) {
      Image(imageName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    } else if themeService.currentMascot != .none {
      Image(systemName: "pawprint.circle.fill")
        .font(.system(size: size * 0.5))
        .foregroundColor(AppTheme.textSecondary)
        .frame(width: size, height: size)
    }
  }
}

#Preview {
  VStack(spacing: 20) {
    Text("Happy")
    MascotAvatarView(state: .happy, size: 100)
    Text("Gym")
    MascotAvatarView(state: .gym, size: 100)
  }
  .padding()
}
