import Foundation
import SwiftUI
import UIKit
import GoogleSignIn
import GoogleSignInSwift
import CryptoKit            // ← built-in

// MARK: - JWT helpers

private enum JWTError: Error { case malformed, invalidSignature, expired }

private struct JWT {
    // Base64-URL with no padding
    private static func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    private static func b64urlDecode(_ str: String) -> Data? {
        var s = str.replacingOccurrences(of: "-", with: "+")
                   .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - s.count % 4
        if padding < 4 { s.append(String(repeating: "=", count: padding)) }
        return Data(base64Encoded: s)
    }

    // Sign {header}.{payload}
    static func signHS256(payload: [String: Any], secret: String,
                          expInterval: TimeInterval) throws -> String {
        let header = ["alg": "HS256", "typ": "JWT"]
        let exp    = Date().addingTimeInterval(expInterval).timeIntervalSince1970
        var body   = payload
        body["exp"] = Int(exp)

        let headerData  = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: body)
        let headerPart  = b64url(headerData)
        let payloadPart = b64url(payloadData)
        let signingInput = "\(headerPart).\(payloadPart)"

        let key  = SymmetricKey(data: Data(secret.utf8))
        let mac  = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let sig  = b64url(Data(mac))

        return "\(signingInput).\(sig)"
    }

    // Verify & decode
    static func verifyHS256(token: String, secret: String) throws -> [String: Any] {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw JWTError.malformed }
        let signingInput = parts[0] + "." + parts[1]

        // recompute signature
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let expected = b64url(Data(mac))
        guard expected == parts[2] else { throw JWTError.invalidSignature }

        // decode payload
        guard let payloadData = b64urlDecode(String(parts[1])),
              let obj = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { throw JWTError.malformed }

        // expiration?
        if let exp = obj["exp"] as? TimeInterval,
           Date(timeIntervalSince1970: exp) < Date() {
            throw JWTError.expired
        }
        return obj
    }
}

// MARK: - AuthenticationService (pure CryptoKit edition)

@MainActor
final class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String?

    private let secretKey: String

    init() {
        // load secret
        if let path = Bundle.main.path(forResource: "config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["EATER_SECRET_KEY"] as? String {
            self.secretKey = key
        } else {
            self.secretKey = "StingSecertGeneratorSalt"
        }

        // restore token
        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            do { try validateAndSetToken(token) }
            catch { UserDefaults.standard.removeObject(forKey: "auth_token") }
        }
    }

    // Google Sign-In
    func signInWithGoogle() {
        #if DEBUG
        // In preview mode, simulate successful sign in
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            generateAndStoreToken(for: "preview@example.com")
            return
        }
        #endif
        
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            print("❌ Missing GIDClientID")
            return
        }
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get the root view controller using a more reliable method
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            // If we're in a preview or the window scene isn't ready, try to get the key window
            if let keyWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let keyWindow = keyWindowScene.windows.first(where: { $0.isKeyWindow }),
               let rootVC = keyWindow.rootViewController {
                startGoogleSignIn(with: rootVC)
            } else {
                print("❌ Could not get root view controller")
            }
            return
        }
        
        startGoogleSignIn(with: rootVC)
    }
    
    private func startGoogleSignIn(with viewController: UIViewController) {
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
            if let error = error {
                print("❌ Google Sign-In error:", error.localizedDescription)
                return
            }
            
            guard let email = result?.user.profile?.email else {
                print("❌ No email found in Google Sign-In result")
                return
            }
            
            self?.generateAndStoreToken(for: email)
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        clearAllUserData()
        isAuthenticated = false
        userEmail = nil
    }
    
    func clearAllUserData() {
        // Remove authentication token
        UserDefaults.standard.removeObject(forKey: "auth_token")
        
        // Remove user preferences
        UserDefaults.standard.removeObject(forKey: "softLimit")
        UserDefaults.standard.removeObject(forKey: "hardLimit")
        
        // Synchronize to ensure data is immediately written
        UserDefaults.standard.synchronize()
    }
    
    func deleteAccountAndClearData() {
        // Sign out from Google
        GIDSignIn.sharedInstance.signOut()
        
        // Clear all local user data
        clearAllUserData()
        
        // Reset authentication state
        isAuthenticated = false
        userEmail = nil
    }

    // MARK: private
    private func generateAndStoreToken(for email: String) {
        do {
            let token = try JWT.signHS256(
                payload: ["sub": email, "iat": Int(Date().timeIntervalSince1970)],
                secret: secretKey,
                expInterval: 20_000 * 3600
            )
            UserDefaults.standard.set(token, forKey: "auth_token")
            isAuthenticated = true
            userEmail = email
        } catch { print("JWT sign failed:", error) }
    }

    private func validateAndSetToken(_ token: String) throws {
        let obj = try JWT.verifyHS256(token: token, secret: secretKey)
        guard let email = obj["sub"] as? String else { throw JWTError.malformed }
        isAuthenticated = true
        userEmail = email
    }
}
