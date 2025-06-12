import Foundation
import SwiftUI
import UIKit
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit

// MARK: - Network Models

struct TokenRequest: Codable {
    let provider: String
    let idToken: String
    let email: String
    let name: String?
    let profilePictureURL: String?
}

struct TokenResponse: Codable {
    let token: String
    let expiresIn: Int
    let userEmail: String
    let userName: String?
    let profilePictureURL: String?
}

struct ErrorResponse: Codable {
    let error: String
    let message: String?
}

// MARK: - JWT helpers

private enum JWTError: Error { case malformed, invalidSignature, expired }

private struct JWT {
    private static func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    static func b64urlDecode(_ str: String) -> Data? {
        var s = str.replacingOccurrences(of: "-", with: "+")
                   .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - s.count % 4
        if padding < 4 { s.append(String(repeating: "=", count: padding)) }
        return Data(base64Encoded: s)
    }

    static func verifyHS256(token: String, secret: String) throws -> [String: Any] {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw JWTError.malformed }
        let signingInput = parts[0] + "." + parts[1]

        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let expected = b64url(Data(mac))
        guard expected == parts[2] else { throw JWTError.invalidSignature }

        guard let payloadData = b64urlDecode(String(parts[1])),
              let obj = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { throw JWTError.malformed }

        if let exp = obj["exp"] as? TimeInterval,
           Date(timeIntervalSince1970: exp) < Date() {
            throw JWTError.expired
        }
        return obj
    }
    
    // More lenient validation that allows expired tokens
    static func validateTokenStructure(token: String) -> [String: Any]? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        
        guard let payloadData = b64urlDecode(String(parts[1])),
              let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { return nil }
        
        return obj
    }
}

// MARK: - AuthenticationService

@MainActor
final class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var userProfilePictureURL: String?
    @Published var isLoading = false

    private let secretKey: String
    private let baseURL = "https://chater.singularis.work"

    override init() {
        // Load secret key
        if let path = Bundle.main.path(forResource: "config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) {
            self.secretKey = dict["EATER_SECRET_KEY"] as? String ?? "StingSecertGeneratorSalt"
        } else {
            self.secretKey = "StingSecertGeneratorSalt"
        }

        super.init()
        
        // Restore stored authentication with improved logic
        restoreAuthenticationState()
    }

    // MARK: - Helper Methods
    
    private func extractName(from fullName: PersonNameComponents?) -> String? {
        guard let fullName = fullName else { return nil }
        let name = [fullName.givenName, fullName.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        return name.isEmpty ? nil : name
    }
    
    private func extractEmailFromAppleToken(_ tokenString: String) -> String? {
        let parts = tokenString.split(separator: ".")
        guard parts.count > 1,
              let payloadData = JWT.b64urlDecode(String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let email = json["email"] as? String else {
            return nil
        }
        return email
    }
    
    private func updateAuthenticationState(with response: TokenResponse) {
        // Store data persistently
        UserDefaults.standard.set(response.token, forKey: "auth_token")
        UserDefaults.standard.set(response.userEmail, forKey: "user_email") // Store email separately
        
        if let userName = response.userName {
            UserDefaults.standard.set(userName, forKey: "user_name")
        } else {
            UserDefaults.standard.removeObject(forKey: "user_name")
        }
        
        if let profileURL = response.profilePictureURL {
            UserDefaults.standard.set(profileURL, forKey: "profile_picture_url")
        } else {
            UserDefaults.standard.removeObject(forKey: "profile_picture_url")
        }
        
        // Ensure UserDefaults are written to disk immediately
        UserDefaults.standard.synchronize()
        
        // Update UI state
        isAuthenticated = true
        userEmail = response.userEmail
        userName = response.userName
        userProfilePictureURL = response.profilePictureURL
        isLoading = false
    }

    private func restoreAuthenticationState() {
        // First, try to restore user data from UserDefaults
        let storedEmail = UserDefaults.standard.string(forKey: "user_email")
        let storedName = UserDefaults.standard.string(forKey: "user_name")
        let storedProfileURL = UserDefaults.standard.string(forKey: "profile_picture_url")
        let storedToken = UserDefaults.standard.string(forKey: "auth_token")
        
        // If we have basic user data, restore the session
        if let email = storedEmail {
            isAuthenticated = true
            userEmail = email
            userName = storedName
            userProfilePictureURL = storedProfileURL
            
            // Try to validate the token if it exists, but don't fail the session if it's invalid
            if let token = storedToken {
                do {
                    try validateStoredToken(token)
                    print("✅ Token validation successful")
                } catch {
                    print("⚠️ Token validation failed: \(error). User remains logged in but may need to re-authenticate for secure operations.")
                    // Keep the user logged in but mark that token needs refresh
                    // You could add a flag here to indicate token needs refresh
                }
            }
        }
    }

    // MARK: - Network Layer
    
    private func requestToken(with tokenRequest: TokenRequest) async throws -> TokenResponse {
        guard let url = URL(string: "\(baseURL)/eater_auth") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        request.httpBody = try JSONEncoder().encode(tokenRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "AuthError", code: httpResponse.statusCode, 
                            userInfo: [NSLocalizedDescriptionKey: errorResponse.message ?? errorResponse.error])
            } else {
                throw URLError(.badServerResponse)
            }
        }
    }

    // MARK: - Authentication Methods

    func signInWithGoogle() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            simulatePreviewAuth()
            return
        }
        #endif
        
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            return
        }
        
        isLoading = true
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isLoading = false
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.isLoading = false
                    return
                }
                
                guard let user = result?.user,
                      let email = user.profile?.email,
                      let idToken = user.idToken?.tokenString else {
                    self.isLoading = false
                    return
                }
                
                await self.handleAuthenticationSuccess(
                    provider: "google",
                    idToken: idToken,
                    email: email,
                    name: user.profile?.name,
                    profilePictureURL: user.profile?.imageURL(withDimension: 120)?.absoluteString
                )
            }
        }
    }
    
    func signInWithApple() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            simulatePreviewAuth()
            return
        }
        #endif
        
        isLoading = true
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func handleAuthenticationSuccess(provider: String, idToken: String, email: String, name: String?, profilePictureURL: String?) async {
        do {
            let tokenRequest = TokenRequest(
                provider: provider,
                idToken: idToken,
                email: email,
                name: name,
                profilePictureURL: profilePictureURL
            )
            
            let tokenResponse = try await requestToken(with: tokenRequest)
            updateAuthenticationState(with: tokenResponse)
            
        } catch {
            isLoading = false
        }
    }
    
    private func simulatePreviewAuth() {
        Task { @MainActor in
            isLoading = true
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            isAuthenticated = true
            userEmail = "preview@example.com"
            userName = "Preview User"
            userProfilePictureURL = nil
            isLoading = false
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        clearAllUserData()
        
        isAuthenticated = false
        userEmail = nil
        userName = nil
        userProfilePictureURL = nil
    }
    
    func clearAllUserData() {
        let keys = ["auth_token", "user_email", "user_name", "profile_picture_url", "softLimit", "hardLimit", "hasSeenOnboarding"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UserDefaults.standard.synchronize()
    }
    
    func deleteAccountAndClearData() {
        GIDSignIn.sharedInstance.signOut()
        clearAllUserData()
        
        isAuthenticated = false
        userEmail = nil
        userName = nil
        userProfilePictureURL = nil
    }
    
    // MARK: - Public Methods
    
    func setPreviewState(email: String, userName: String? = nil, profilePictureURL: String? = nil) {
        isAuthenticated = true
        userEmail = email
        self.userName = userName ?? "Preview User"
        userProfilePictureURL = profilePictureURL
    }

    func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "auth_token")
    }
    
    func isTokenValidForSecureOperations() -> Bool {
        guard let token = UserDefaults.standard.string(forKey: "auth_token") else {
            return false
        }
        
        do {
            _ = try JWT.verifyHS256(token: token, secret: secretKey)
            return true
        } catch {
            return false
        }
    }
    
    func requiresFreshAuthentication() -> Bool {
        return !isTokenValidForSecureOperations()
    }
    
    func getGreeting() -> String {
        if let name = userName, !name.isEmpty {
            return "Hello \(name)"
        } else if let email = userEmail {
            let firstName = email.components(separatedBy: "@")[0].capitalized
            return "Hello \(firstName)"
        }
        return "Hello"
    }
    
    private func validateStoredToken(_ token: String) throws {
        do {
            // First try strict validation
            let obj = try JWT.verifyHS256(token: token, secret: secretKey)
            
            guard let email = obj["sub"] as? String else {
                throw JWTError.malformed
            }
            
            // Token is valid, update user data if needed
            if userEmail == nil {
                userEmail = email
            }
            if userName == nil {
                userName = UserDefaults.standard.string(forKey: "user_name")
            }
            if userProfilePictureURL == nil {
                userProfilePictureURL = UserDefaults.standard.string(forKey: "profile_picture_url")
            }
            
        } catch JWTError.expired {
            // Token is expired but structurally valid - try lenient validation
            if let obj = JWT.validateTokenStructure(token: token),
               let email = obj["sub"] as? String {
                print("⚠️ Token is expired but structurally valid. User remains logged in.")
                // Keep user logged in but they may need to re-authenticate for secure operations
                if userEmail == nil {
                    userEmail = email
                }
                if userName == nil {
                    userName = UserDefaults.standard.string(forKey: "user_name")
                }
                if userProfilePictureURL == nil {
                    userProfilePictureURL = UserDefaults.standard.string(forKey: "profile_picture_url")
                }
            } else {
                throw JWTError.expired
            }
        } catch {
            // Re-throw other errors (malformed, invalidSignature)
            throw error
        }
    }
    
    // MARK: - Debug Methods
    
    func getTokenStatus() -> String {
        guard let token = UserDefaults.standard.string(forKey: "auth_token") else {
            return "No token stored"
        }
        
        do {
            let obj = try JWT.verifyHS256(token: token, secret: secretKey)
            if let exp = obj["exp"] as? TimeInterval {
                let expirationDate = Date(timeIntervalSince1970: exp)
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return "Token valid until: \(formatter.string(from: expirationDate))"
            } else {
                return "Token valid (no expiration)"
            }
        } catch JWTError.expired {
            if let obj = JWT.validateTokenStructure(token: token),
               let exp = obj["exp"] as? TimeInterval {
                let expirationDate = Date(timeIntervalSince1970: exp)
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return "Token expired on: \(formatter.string(from: expirationDate))"
            } else {
                return "Token expired"
            }
        } catch JWTError.invalidSignature {
            return "Token has invalid signature"
        } catch JWTError.malformed {
            return "Token is malformed"
        } catch {
            return "Token validation error: \(error)"
        }
    }
}

// MARK: - Apple Sign-In Delegates

extension AuthenticationService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                self.isLoading = false
                return
            }
            
            let email = appleIDCredential.email ?? extractEmailFromAppleToken(tokenString)
            guard let finalEmail = email else {
                self.isLoading = false
                return
            }
            
            let name = extractName(from: appleIDCredential.fullName)
            
            await handleAuthenticationSuccess(
                provider: "apple",
                idToken: tokenString,
                email: finalEmail,
                name: name,
                profilePictureURL: nil
            )
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            self.isLoading = false
        }
    }
}


