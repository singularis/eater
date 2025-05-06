import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

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
            
            GoogleSignInButton(scheme: .dark, style: .wide, state: .normal) {
                authService.signInWithGoogle()
            }
            .frame(width: 280, height: 50)
            .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationService())
}
