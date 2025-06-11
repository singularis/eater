import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showOnboarding = false
    @State private var showHealthSettings = false
    @State private var showHealthDataAlert = false
    @State private var hasHealthData = false
    @State private var userHeight: Double = 0
    @State private var userWeight: Double = 0
    @State private var userAge: Int = 0
    @State private var userOptimalWeight: Double = 0
    @State private var userRecommendedCalories: Int = 0
    
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
                    
                    // User Information
                    VStack(spacing: 15) {
                        // User Name
                        if let userName = authService.userName, !userName.isEmpty {
                            VStack(spacing: 8) {
                                Text("Name")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                Text(userName)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue.opacity(0.3))
                                    .cornerRadius(10)
                            }
                        }
                        
                        // User Email
                        VStack(spacing: 8) {
                            Text("Email")
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
                    }
                    
                    // Health Data Section
                    if hasHealthData {
                        VStack(spacing: 15) {
                            Text("Your Health Profile")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Height:")
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(userHeight, specifier: "%.0f") cm")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal)
                                
                                HStack {
                                    Text("Target Weight:")
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(userOptimalWeight, specifier: "%.1f") kg")
                                        .foregroundColor(.green)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal)
                                
                                HStack {
                                    Text("Daily Calorie Target:")
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(userRecommendedCalories) kcal")
                                        .foregroundColor(.orange)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                            
                            Button("Update Health Settings") {
                                showHealthSettings = true
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                        }
                    } else {
                        VStack(spacing: 15) {
                            Text("Personalize Your Experience")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Set up your health profile to get personalized calorie recommendations")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Button("Setup Health Profile") {
                                showHealthSettings = true
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                        }
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
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .sheet(isPresented: $showHealthSettings) {
                HealthSettingsView(isPresented: $showHealthSettings)
            }
            .onChange(of: showHealthSettings) { _, newValue in
                if !newValue { // Sheet was dismissed
                    loadHealthData()
                }
            }
            .onAppear {
                loadHealthData()
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
    
    private func loadHealthData() {
        let userDefaults = UserDefaults.standard
        hasHealthData = userDefaults.bool(forKey: "hasUserHealthData")
        
        if hasHealthData {
            userHeight = userDefaults.double(forKey: "userHeight")
            userWeight = userDefaults.double(forKey: "userWeight")
            userAge = userDefaults.integer(forKey: "userAge")
            userOptimalWeight = userDefaults.double(forKey: "userOptimalWeight")
            userRecommendedCalories = userDefaults.integer(forKey: "userRecommendedCalories")
        }
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