import GoogleSignIn
import SwiftUI
import UserNotifications

@main
struct AppNameApp: App {
  @StateObject private var authService = AuthenticationService()
  @ObservedObject private var appSettings = AppSettingsService.shared

  var body: some Scene {
    WindowGroup {
      Group {
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
              if let email = authService.userEmail {
                ProfileLocalStore.shared.restore(email: email)
              }
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
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceLogout"))) { _ in
        // Keep disk profile; only drop the session.
        authService.signOut()
      }
    }
  }
}
