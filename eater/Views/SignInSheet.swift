import SwiftUI

/// In-place Apple / Google sign-in so a guest can upgrade without being signed out.
struct SignInSheet: View {
  @EnvironmentObject private var authService: AuthenticationService
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)

        VStack(spacing: 16) {
          Text(loc("login.scan_prompt_message", "Please login to Google if you are ready or want to recover past food."))
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)

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

          Button(action: {
            HapticsService.shared.mediumImpact()
            authService.signInWithGoogle()
          }) {
            HStack(spacing: 8) {
              Text("G")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.2)))
              Text(loc("login.google", "Sign in with Google"))
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(PrimaryButtonStyle())

          Spacer()
        }
        .padding(20)
        .disabled(authService.isLoading)

        if authService.isLoading {
          Color.black.opacity(0.25)
            .ignoresSafeArea()
          ProgressView()
            .scaleEffect(1.3)
            .padding(28)
            .appSurface()
        }
      }
      .navigationTitle(loc("login.scan_prompt_title", "Unlock All Features"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(loc("common.not_yet", "Not Yet")) {
            dismiss()
          }
        }
      }
      .alert(
        loc("error.network.title", "Connection Error"),
        isPresented: Binding(
          get: { authService.lastAuthError != nil },
          set: { if !$0 { authService.lastAuthError = nil } }
        )
      ) {
        Button(loc("common.ok", "OK"), role: .cancel) {
          authService.lastAuthError = nil
        }
      } message: {
        Text(
          authService.lastAuthError
            ?? loc("error.network.generic", "We are sorry. Network connection. Please try later.")
        )
      }
      .onChange(of: authService.isAnonymous) { _, isAnonymous in
        if !isAnonymous {
          dismiss()
        }
      }
    }
  }
}
