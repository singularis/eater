import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

struct LoginView: View {
  @EnvironmentObject private var authService: AuthenticationService

  var body: some View {
    ZStack {
      AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
      VStack(spacing: 24) {
        Image(systemName: "fork.knife")
          .resizable()
          .scaledToFit()
          .frame(width: 100, height: 100)
          .foregroundColor(AppTheme.accent)

        Text(loc("login.welcome", "Welcome to Eateria"))
          .font(.largeTitle)
          .fontWeight(.bold)
          .foregroundColor(AppTheme.textPrimary)

        Text(loc("login.subtitle", "Sign in to continue"))
          .font(.subheadline)
          .foregroundColor(AppTheme.textSecondary)

        VStack(spacing: 12) {
        // Sign in with Apple button
        Button(action: {
          HapticsService.shared.mediumImpact()
          authService.signInWithApple()
        }) {
          HStack(spacing: 8) {
            Image(systemName: "applelogo")
              .font(.system(size: 18, weight: .semibold))
            Text(loc("login.apple", "Sign in with Apple"))
              .fontWeight(.semibold)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(width: 280)

        // Google Sign-In button
        Button(action: {
          HapticsService.shared.mediumImpact()
          authService.signInWithGoogle()
        }) {
          HStack(spacing: 8) {
            Text("G")
              .font(.system(size: 18, weight: .bold))
              .foregroundColor(.white)
              .frame(width: 24, height: 24)
              .background(
                Circle()
                  .fill(Color.white.opacity(0.2))
              )
            Text(loc("login.google", "Sign in with Google"))
              .fontWeight(.semibold)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(width: 280)
        }
        .padding(.top, 20)
      }
      .padding()
    }
  }
}

#Preview {
  LoginView()
    .environmentObject(
      {
        let authService = AuthenticationService()
        // For login view, we don't set preview state since it should show the login screen
        return authService
      }())
}
