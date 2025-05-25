import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authService: AuthenticationService
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Welcome to Eater")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Sign in to continue")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                // Sign in with Apple button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    #if targetEnvironment(simulator)
                    // Simulator fallback - simulate successful sign in
                    Task { @MainActor in
                        authService.generateAndStoreToken(for: "simulator_apple_user@privaterelay.appleid.com")
                    }
                    return
                    #endif
                    Task { @MainActor in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                // Use the email if provided, otherwise create a placeholder
                                let email = appleIDCredential.email ?? "apple_user_\(appleIDCredential.user)@privaterelay.appleid.com"
                                authService.generateAndStoreToken(for: email)
                            }
                        case .failure(let error):
                            // Only log non-cancellation errors
                            if let authError = error as? ASAuthorizationError {
                                switch authError.code {
                                case .canceled:
                                    print("User canceled Sign in with Apple")
                                case .failed:
                                    print("❌ Sign in with Apple failed:", error.localizedDescription)
                                case .invalidResponse:
                                    print("❌ Sign in with Apple invalid response:", error.localizedDescription)
                                case .notHandled:
                                    print("❌ Sign in with Apple not handled:", error.localizedDescription)
                                case .unknown:
                                    print("❌ Sign in with Apple unknown error:", error.localizedDescription)
                                @unknown default:
                                    print("❌ Sign in with Apple unknown error:", error.localizedDescription)
                                }
                            } else {
                                print("❌ Sign in with Apple error:", error.localizedDescription)
                            }
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(width: 280, height: 50)
                
                // Google Sign-In button
                GoogleSignInButton(scheme: .dark, style: .wide, state: .normal) {
                    authService.signInWithGoogle()
                }
                .frame(width: 280, height: 50)
            }
            .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    LoginView()
        .environmentObject({
            let authService = AuthenticationService()
            // For login view, we don't set preview state since it should show the login screen
            return authService
        }())
}
