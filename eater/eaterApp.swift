import GoogleSignIn
import SwiftUI
import UserNotifications

@main
struct AppNameApp: App {
  @StateObject private var authService = AuthenticationService()
  @ObservedObject private var appSettings = AppSettingsService.shared

  var body: some Scene {
    WindowGroup {
      if authService.isAuthenticated {
        ContentView()
          .preferredColorScheme(appSettings.scheme)
          .tint(AppTheme.accent)
          .environmentObject(authService)
          .environmentObject(LanguageService.shared)
          .environmentObject(appSettings)
          .id(LanguageService.shared.currentCode)
          .onAppear {
            NotificationService.shared.initializeOnLaunch()
          }
      } else {
        LoginView()
          .preferredColorScheme(appSettings.scheme)
          .tint(AppTheme.accent)
          .environmentObject(authService)
          .environmentObject(LanguageService.shared)
          .environmentObject(appSettings)
          .id(LanguageService.shared.currentCode)
          .onAppear {
            NotificationService.shared.initializeOnLaunch()
          }
      }
    }
  }
}
