import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

struct LoginView: View {
  @EnvironmentObject private var authService: AuthenticationService
  // Read so the view re-renders when the phone switches light/dark;
  // AppTheme resolves its colors from the current trait collection.
  @Environment(\.colorScheme) private var systemColorScheme
  @State private var showAppInfo = false
  @State private var appeared = false

  var body: some View {
    let _ = systemColorScheme
    ZStack {
      AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)

      ScrollView(showsIndicators: false) {
        VStack(spacing: 16) {
          header
          featureHighlights
          actionButtons
          trustFooter
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
      }

      if authService.isLoading {
        Color.black.opacity(0.25)
          .edgesIgnoringSafeArea(.all)
        ProgressView()
          .scaleEffect(1.3)
          .padding(28)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
      }
    }
    .sheet(isPresented: $showAppInfo) {
      AppInfoView()
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
    .onAppear {
      if AppSettingsService.shared.reduceMotion {
        appeared = true
      } else {
        withAnimation(.easeOut(duration: 0.5)) { appeared = true }
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(AppTheme.surface)
          .overlay(
            Circle()
              .stroke(
                LinearGradient(
                  colors: [AppTheme.accent.opacity(0.9), Color.purple.opacity(0.6)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 2.5
              )
          )
          .shadow(color: AppTheme.accent.opacity(0.35), radius: 14, x: 0, y: 6)

        Image(systemName: "fork.knife")
          .font(.system(size: 34, weight: .semibold))
          .foregroundColor(AppTheme.accent)
      }
      .frame(width: 84, height: 84)

      Text(loc("login.welcome", "Welcome to Eateria"))
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.center)

      Text(loc("login.tagline", "Snap a photo. Know exactly what you eat."))
        .font(.subheadline)
        .foregroundColor(AppTheme.textSecondary)
        .multilineTextAlignment(.center)
    }
  }

  // MARK: - Features

  private var featureHighlights: some View {
    VStack(alignment: .leading, spacing: 14) {
      LoginFeatureRow(
        icon: "camera.viewfinder",
        tint: AppTheme.accent,
        text: loc("login.feature.scan", "AI recognizes your meal from a single photo")
      )
      LoginFeatureRow(
        icon: "chart.line.uptrend.xyaxis",
        tint: AppTheme.success,
        text: loc("login.feature.insights", "Track calories, macros, weight and activity")
      )
      LoginFeatureRow(
        icon: "lock.shield.fill",
        tint: Color.purple,
        text: loc("login.feature.privacy", "Your data is encrypted and never sold")
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardContainer(padding: 16)
  }

  // MARK: - Actions

  private var actionButtons: some View {
    VStack(spacing: 12) {
      // Hero CTA: zero-friction entry, so it leads the stack.
      Button(action: {
        HapticsService.shared.mediumImpact()
        authService.signInAnonymously()
      }) {
        VStack(spacing: 3) {
          HStack(spacing: 8) {
            Image(systemName: "sparkles")
              .font(.system(size: 18, weight: .semibold))
            Text(loc("login.let_me_try", "Let Me Try"))
              .font(.headline)
          }
          Text(loc("login.try.badge", "Free • No account needed"))
            .font(.caption)
            .opacity(0.92)
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(GreenButtonStyle())

      Text(loc("login.try_description", "You can authenticate later to use cross-device share features."))
        .font(.caption)
        .multilineTextAlignment(.center)
        .foregroundColor(AppTheme.textSecondary)

      HStack(spacing: 10) {
        Rectangle().fill(AppTheme.divider).frame(height: 1)
        Text(loc("login.or", "or sign in"))
          .font(.caption.weight(.medium))
          .foregroundColor(AppTheme.textSecondary)
          .fixedSize()
        Rectangle().fill(AppTheme.divider).frame(height: 1)
      }
      .padding(.vertical, 2)

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

      Button(action: {
        HapticsService.shared.select()
        showAppInfo = true
      }) {
        HStack(spacing: 8) {
          Image(systemName: "info.circle")
            .font(.system(size: 17, weight: .semibold))
          Text(loc("login.more_info", "What is Eateria?"))
            .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(SecondaryButtonStyle())
    }
    .disabled(authService.isLoading)
  }

  // MARK: - Trust footer

  private var trustFooter: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(AppTheme.success)
      Text(
        loc(
          "login.trust.footer",
          "Secure sign-in with Apple or Google. No ads, no spam, and we never sell your data."
        )
      )
      .font(.caption)
      .foregroundColor(AppTheme.textSecondary)
      .fixedSize(horizontal: false, vertical: true)
      .multilineTextAlignment(.leading)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct LoginFeatureRow: View {
  let icon: String
  let tint: Color
  let text: String

  @Environment(\.colorScheme) private var environmentColorScheme

  var body: some View {
    let _ = environmentColorScheme
    HStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(tint.opacity(0.15))
        Image(systemName: icon)
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(tint)
      }
      .frame(width: 40, height: 40)

      Text(text)
        .font(.subheadline)
        .foregroundColor(AppTheme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
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
