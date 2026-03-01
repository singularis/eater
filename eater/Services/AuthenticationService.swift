import AuthenticationServices
import Foundation
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import UIKit

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

// MARK: - JWT helpers (client-side: structure & expiration checks only)

private enum JWTError: Error { case malformed, expired }

private enum JWT {
  static func b64urlDecode(_ str: String) -> Data? {
    var s = str.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let padding = 4 - s.count % 4
    if padding < 4 { s.append(String(repeating: "=", count: padding)) }
    return Data(base64Encoded: s)
  }

  /// Client-side validation: checks JWT structure and expiration only.
  /// Signature verification is done exclusively on the backend.
  static func validateToken(token: String) throws -> [String: Any] {
    let parts = token.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else { throw JWTError.malformed }

    guard let payloadData = b64urlDecode(String(parts[1])),
      let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
    else { throw JWTError.malformed }

    if let exp = obj["exp"] as? TimeInterval,
      Date(timeIntervalSince1970: exp) < Date()
    {
      throw JWTError.expired
    }
    return obj
  }

  /// Lenient check: returns payload if structurally valid, ignoring expiration.
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
  
  private var currentAuthorizationController: ASAuthorizationController?

  override init() {
    super.init()

    // Restore stored authentication
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
      let email = json["email"] as? String
    else {
      return nil
    }
    return email
  }

  private func updateAuthenticationState(with response: TokenResponse) {
    // Store token in Keychain (not UserDefaults) for security
    KeychainHelper.shared.save(response.token, for: "auth_token")
    UserDefaults.standard.set(response.userEmail, forKey: "user_email")

    // Mark token as fresh from server
    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "token_created_timestamp")

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

    UserDefaults.standard.synchronize()

    // Update UI state
    isAuthenticated = true
    userEmail = response.userEmail
    userName = response.userName
    userProfilePictureURL = response.profilePictureURL
    isLoading = false
  }

  private func restoreAuthenticationState() {
    let storedEmail = UserDefaults.standard.string(forKey: "user_email")
    let storedName = UserDefaults.standard.string(forKey: "user_name")
    let storedProfileURL = UserDefaults.standard.string(forKey: "profile_picture_url")
    let storedToken = KeychainHelper.shared.read("auth_token")

    if let email = storedEmail {
      isAuthenticated = true
      userEmail = email
      userName = storedName
      userProfilePictureURL = storedProfileURL

      if let token = storedToken {
        validateStoredToken(token)
      }
    }
  }

  // MARK: - Network Layer

  private func requestToken(with tokenRequest: TokenRequest) async throws -> TokenResponse {
    let authUrlString = "\(AppEnvironment.baseURL)/eater_auth"
    print("🔵 [AuthService] Preparing to request token from: \(authUrlString)")
    guard let url = URL(string: authUrlString) else {
      print("🔴 [AuthService] Bad URL generated: \(authUrlString)")
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 30.0
    request.httpBody = try JSONEncoder().encode(tokenRequest)
    
    print("🔵 [AuthService] Sending request to \(url)")
    if let bodyStr = String(data: request.httpBody!, encoding: .utf8) {
        // Redact idToken in logs to avoid spam
        let safeBody = bodyStr.replacingOccurrences(of: tokenRequest.idToken, with: "[REDACTED_TOKEN_TRUNCATED]")
        print("🔵 [AuthService] Request body: \(safeBody)")
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        print("🔴 [AuthService] Bad server response (not HTTPURLResponse)")
        throw URLError(.badServerResponse)
      }

      print("🔵 [AuthService] Response status code: \(httpResponse.statusCode)")

      if httpResponse.statusCode == 200 {
        print("🟢 [AuthService] Successfully decoded TokenResponse.")
        return try JSONDecoder().decode(TokenResponse.self, from: data)
      } else {
        let errStr = String(data: data, encoding: .utf8) ?? "unknown error body"
        print("🔴 [AuthService] Authentication failed with status \(httpResponse.statusCode). Body: \(errStr)")
        
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
          throw NSError(
            domain: "AuthError", code: httpResponse.statusCode,
            userInfo: [NSLocalizedDescriptionKey: errorResponse.message ?? errorResponse.error])
        } else {
          throw URLError(.badServerResponse)
        }
      }
    } catch {
      print("🔴 [AuthService] requestToken encountered an error: \(error.localizedDescription)")
      throw error
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

    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    // Delay presentation explicitly to allow SwiftUI interactions (like Button press animations) to conclude
    DispatchQueue.main.async {
      guard let topVC = UIApplication.topMostViewController else {
        print("🔴 [AuthService] Could not find topMostViewController to present GIDSignIn")
        return
      }

      GIDSignIn.sharedInstance.signIn(withPresenting: topVC) { [weak self] result, error in
        Task { @MainActor in
          guard let self = self else { return }

          if let error = error {
            print("🔴 [AuthService] GIDSignIn error: \(error.localizedDescription)")
            self.isLoading = false
            return
          }

          guard let user = result?.user,
            let email = user.profile?.email,
            let idToken = user.idToken?.tokenString
          else {
            print("🔴 [AuthService] GIDSignIn missing user or idToken")
            self.isLoading = false
            return
          }

          print("🔵 [AuthService] GIDSignIn complete for \(email), dispatching success handler")
          self.isLoading = true // Show loader during our backend call
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
  }

  func signInWithApple() {
    #if DEBUG
      if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        simulatePreviewAuth()
        return
      }
    #endif

    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]

    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    self.currentAuthorizationController = controller
    controller.performRequests()
  }

  private func handleAuthenticationSuccess(
    provider: String, idToken: String, email: String, name: String?, profilePictureURL: String?
  ) async {
    print("🔵 [AuthService] handleAuthenticationSuccess called for provider: \(provider), email: \(email)")
    do {
      let tokenRequest = TokenRequest(
        provider: provider,
        idToken: idToken,
        email: email,
        name: name,
        profilePictureURL: profilePictureURL
      )

      print("🔵 [AuthService] About to call requestToken...")
      let tokenResponse = try await requestToken(with: tokenRequest)
      print("🟢 [AuthService] requestToken succeeded. Updating auth state.")
      updateAuthenticationState(with: tokenResponse)

    } catch {
      print("🔴 [AuthService] handleAuthenticationSuccess error: \(error.localizedDescription)")
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
    let keys = [
      "user_email", "user_name", "profile_picture_url", "token_created_timestamp",
      "softLimit", "hardLimit", "hasSeenOnboarding",
    ]
    keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    UserDefaults.standard.synchronize()
    // Clear token from Keychain
    KeychainHelper.shared.save("", for: "auth_token")
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
    return KeychainHelper.shared.read("auth_token")
  }

  func isTokenValidForSecureOperations() -> Bool {
    guard let token = KeychainHelper.shared.read("auth_token"), !token.isEmpty else {
      return false
    }

    // Client only checks structure + expiration. Signature is verified by the backend.
    do {
      _ = try JWT.validateToken(token: token)
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

  private func validateStoredToken(_ token: String) {
    // Client-side: only check structure and expiration.
    // Signature verification is the backend's responsibility.
    guard let obj = JWT.validateTokenStructure(token: token) else { return }

    if let email = obj["sub"] as? String, userEmail == nil {
      userEmail = email
    }
    if userName == nil {
      userName = UserDefaults.standard.string(forKey: "user_name")
    }
    if userProfilePictureURL == nil {
      userProfilePictureURL = UserDefaults.standard.string(forKey: "profile_picture_url")
    }

    // If token is expired, user stays logged in but will need to re-auth for secure ops
    if let exp = obj["exp"] as? TimeInterval,
      Date(timeIntervalSince1970: exp) < Date()
    {
      // Token expired — user can still browse but secure operations will require re-auth
    }
  }

  // MARK: - Debug Methods

  func getTokenStatus() -> String {
    guard let token = KeychainHelper.shared.read("auth_token"), !token.isEmpty else {
      return "No token stored"
    }

    if let obj = JWT.validateTokenStructure(token: token) {
      if let exp = obj["exp"] as? TimeInterval {
        let expirationDate = Date(timeIntervalSince1970: exp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let isExpired = expirationDate < Date()
        let expStatus = isExpired ? "expired on" : "valid until"
        return "Token \(expStatus): \(formatter.string(from: expirationDate))"
      }
      return "Token valid (no expiration claim)"
    }

    return "Token is malformed"
  }
}

// MARK: - Apple Sign-In Delegates

extension AuthenticationService: ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding
{
  func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
    else {
      return ASPresentationAnchor()
    }
    return window
  }

  func authorizationController(
    controller _: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    Task { @MainActor in
      self.currentAuthorizationController = nil
      guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
        let identityToken = appleIDCredential.identityToken,
        let tokenString = String(data: identityToken, encoding: .utf8)
      else {
        print("🔴 [AuthService] Apple Sign In: Missing token or credential")
        self.isLoading = false
        return
      }


      let email = appleIDCredential.email ?? extractEmailFromAppleToken(tokenString)
      guard let finalEmail = email else {
        print("🔴 [AuthService] Apple Sign In: Could not extract email from identityToken")
        self.isLoading = false
        return
      }

      let name = extractName(from: appleIDCredential.fullName)
      print("🔵 [AuthService] Apple Sign In completed for \(finalEmail). Dispatching to success handler.")

      self.isLoading = true // Show loader during our backend call
      await handleAuthenticationSuccess(
        provider: "apple",
        idToken: tokenString,
        email: finalEmail,
        name: name,
        profilePictureURL: nil
      )
    }
  }

  func authorizationController(
    controller _: ASAuthorizationController, didCompleteWithError error: Error
  ) {
    Task { @MainActor in
      print("🔴 [AuthService] Apple Sign in encountered error: \(error.localizedDescription)")
      self.currentAuthorizationController = nil
      self.isLoading = false
    }
  }
}

// MARK: - View Controller Presentation Helper

extension UIApplication {
  static var topMostViewController: UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
    let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
      ?? scenes.first as? UIWindowScene
    guard let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first else {
      return nil
    }
    return getTopViewController(for: window.rootViewController)
  }

  private static func getTopViewController(for rootViewController: UIViewController?) -> UIViewController? {
    guard let rootViewController = rootViewController else { return nil }

    if let presentedViewController = rootViewController.presentedViewController {
      return getTopViewController(for: presentedViewController)
    }

    if let navigationController = rootViewController as? UINavigationController {
      return getTopViewController(for: navigationController.visibleViewController)
    }

    if let tabBarController = rootViewController as? UITabBarController {
      return getTopViewController(for: tabBarController.selectedViewController)
    }

    return rootViewController
  }
}
