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
            return "http://192.168.0.10:30601/dev"
        }
        return "https://chater.singularis.work"
    }

    static var autocompleteBaseURL: String {
        if useDevEnvironment {
            // Direct connection to eater-users-dev service
            return "http://192.168.0.118"
        }
        return "https://chater.singularis.work"
    }

    static var webSocketURL: URL {
        if useDevEnvironment {
            // Direct connection to eater-users-dev service (FastAPI supports WebSocket)
            return URL(string: "ws://192.168.0.118/autocomplete")!
        }
        return URL(string: "wss://chater.singularis.work/autocomplete")!
    }
}
