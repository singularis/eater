import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    // User Profile Picture
                    ProfileImageView(
                        profilePictureURL: authService.userProfilePictureURL,
                        size: 80,
                        fallbackIconColor: .white
                    )
                    .padding(.top, 50)
                    
                    // User Email
                    VStack(spacing: 10) {
                        Text("User Email")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text(authService.userEmail ?? "No email")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    // Logout Button
                    Button(action: {
                        logout()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                            Text("Logout")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    
                    // Delete Account Button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Account")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This will immediately remove all your data and preferences from this device and sign you out.")
            }
        }
    }
    
    private func logout() {
        // Sign out user and clear local data
        authService.signOut()
        
        // Immediately dismiss the view - this will show the login view since user is no longer authenticated
        dismiss()
    }
    
    private func deleteAccount() {
        guard let email = authService.userEmail else { 
            AlertHelper.showAlert(title: "Error", message: "No user email found. Please try signing in again.")
            return 
        }
        
        // Immediately delete account and clear all user data from device
        authService.deleteAccountAndClearData()
        
        // Send delete request to server in background (fire and forget)
        GRPCService().deleteUser(email: email) { success in
            // We don't need to handle the response since user is already signed out
            if success {
                print("Account successfully deleted from server")
            } else {
                print("Failed to delete account from server, but user data already cleared locally")
            }
        }
        
        // Immediately dismiss the view - this will show the login view since user is no longer authenticated
        dismiss()
    }
}

#Preview {
    UserProfileView()
        .environmentObject({
            let authService = AuthenticationService()
            authService.setPreviewState(
                email: "preview@example.com",
                profilePictureURL: "https://lh3.googleusercontent.com/a/default-user=s120-c"
            )
            return authService
        }())
} 