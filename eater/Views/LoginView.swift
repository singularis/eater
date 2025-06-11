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
                Button(action: {
                    authService.signInWithApple()
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                            .foregroundColor(.white)
                        Text("Sign in with Apple")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .cornerRadius(8)
                }
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
