import SwiftUI
import GoogleSignIn
import UserNotifications

@main
struct AppNameApp: App {
    @StateObject private var authService = AuthenticationService()
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
                    .preferredColorScheme(.dark)
                    .environmentObject(authService)
                    .onAppear {
                        NotificationService.shared.initializeOnLaunch()
                    }
            } else {
                LoginView()
                    .environmentObject(authService)
                    .onAppear {
                        NotificationService.shared.initializeOnLaunch()
                    }
            }
        }
    }
}
