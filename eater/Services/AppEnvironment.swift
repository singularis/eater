import Foundation

struct AppEnvironment {
    private static let useDevEnvKey = "use_dev_environment"

    static var useDevEnvironment: Bool {
        get {
            #if !DEBUG
            return false // Always false in production releases
            #else
            if UserDefaults.standard.object(forKey: useDevEnvKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: useDevEnvKey)
            #endif
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useDevEnvKey)
        }
    }

    static var baseURL: String {
        if useDevEnvironment {
            return "https://chater.singularis.work/dev"
        }
        return "https://chater.singularis.work"
    }

    static var autocompleteBaseURL: String {
        if useDevEnvironment {
            return "https://chater.singularis.work/dev"
        }
        return "https://chater.singularis.work"
    }

    static var webSocketURL: URL {
        if useDevEnvironment {
            return URL(string: "wss://chater.singularis.work/dev/autocomplete")!
        }
        return URL(string: "wss://chater.singularis.work/autocomplete")!
    }
    
    /// The session cookie prefix for the current environment (matches backend).
    static var sessionCookiePrefix: String {
        useDevEnvironment ? "_dev:chater_ui:" : "chater_ui:"
    }
    /// Clear all cookies whose name starts with the 'wrong' prefix for current environment.
    static func clearMismatchedCookies() {
        let storage = HTTPCookieStorage.shared
        let validPrefix = sessionCookiePrefix
        let allCookies = storage.cookies ?? []
        for cookie in allCookies {
            if cookie.name.hasPrefix("chater_ui:") && validPrefix != "chater_ui:" {
                storage.deleteCookie(cookie)
            } else if cookie.name.hasPrefix("_dev:chater_ui:") && validPrefix != "_dev:chater_ui:" {
                storage.deleteCookie(cookie)
            }
        }
    }
}
