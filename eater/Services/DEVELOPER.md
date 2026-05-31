import Foundation
import SwiftUI

/// Environment configuration for the app, including session cookie handling.
enum AppEnvironment {
    /// Flag to determine if the app is using the development environment.
    static var useDevEnvironment: Bool {
        get {
            UserDefaults.standard.bool(forKey: "useDevEnvironment")
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: "useDevEnvironment")
        }
    }
    
    /// The prefix used for session cookies depending on the environment.
    static var sessionCookiePrefix: String {
        return useDevEnvironment ? "_dev:chater_ui:" : "chater_ui:"
    }
    
    /// Base URL for API calls depending on the environment.
    static var apiBaseURL: URL {
        if useDevEnvironment {
            return URL(string: "https://dev.api.chater.com")!
        } else {
            return URL(string: "https://api.chater.com")!
        }
    }
    
    /// Base WebSocket URL depending on the environment.
    static var webSocketBaseURL: URL {
        if useDevEnvironment {
            return URL(string: "wss://dev.ws.chater.com")!
        } else {
            return URL(string: "wss://ws.chater.com")!
        }
    }
    
    /// Clears cookies that do not match the current session cookie prefix.
    /// This is called on environment switches to prevent session contamination.
    static func clearMismatchedCookies() {
        let storage = HTTPCookieStorage.shared
        let cookies = storage.cookies ?? []
        
        for cookie in cookies {
            if cookie.name.hasPrefix("chater_ui:") || cookie.name.hasPrefix("_dev:chater_ui:") {
                // Remove cookie if it does not match current environment prefix
                if !cookie.name.hasPrefix(sessionCookiePrefix) {
                    storage.deleteCookie(cookie)
                }
            }
        }
    }
}

// Example SwiftUI view demonstrating environment switching and cookie clearing.
struct EnvironmentSwitcherView: View {
    @AppStorage("useDevEnvironment") private var useDevEnvironment: Bool = false
    
    var body: some View {
        VStack {
            Toggle("Use Development Environment", isOn: $useDevEnvironment)
                .padding()
        }
        .onChange(of: useDevEnvironment) { _, _ in
            AppEnvironment.clearMismatchedCookies()
            // Additional logic on environment switch can be added here.
        }
    }
}
