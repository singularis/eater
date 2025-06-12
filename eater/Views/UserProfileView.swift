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
    @State private var showStatistics = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        VStack(spacing: geometry.size.height < 700 ? 15 : 25) {
                            // User Profile Picture
                            ProfileImageView(
                                profilePictureURL: authService.userProfilePictureURL,
                                size: geometry.size.height < 700 ? 60 : 80,
                                fallbackIconColor: .white,
                                userName: authService.userName,
                                userEmail: authService.userEmail
                            )
                            
                            // User Information
                            VStack(spacing: geometry.size.height < 700 ? 8 : 15) {
                                // User Name
                                if let userName = authService.userName, !userName.isEmpty {
                                    VStack(spacing: 5) {
                                        Text("Name")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        Text(userName)
                                            .font(geometry.size.height < 700 ? .title2 : .title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, geometry.size.height < 700 ? 8 : 12)
                                            .background(Color.blue.opacity(0.3))
                                            .cornerRadius(8)
                                    }
                                }
                                
                                // User Email
                                VStack(spacing: 5) {
                                    Text("Email")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Text(authService.userEmail ?? "No email")
                                        .font(geometry.size.height < 700 ? .body : .title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, geometry.size.height < 700 ? 8 : 12)
                                        .background(Color.gray.opacity(0.3))
                                        .cornerRadius(8)
                                }
                            }
                            
                            // Statistics Button
                            Button(action: {
                                showStatistics = true
                            }) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                    Text("View Statistics")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                            }
                            
                            // Health Data Section
                            if hasHealthData {
                                VStack(spacing: 10) {
                                    Text("Your Health Profile")
                                        .font(geometry.size.height < 700 ? .title3 : .title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    VStack(spacing: 8) {
                                        HStack {
                                            Text("Height:")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("\(userHeight, specifier: "%.0f") cm")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal)
                                        
                                        HStack {
                                            Text("Target Weight:")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("\(userOptimalWeight, specifier: "%.1f") kg")
                                                .font(.subheadline)
                                                .foregroundColor(.green)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal)
                                        
                                        HStack {
                                            Text("Daily Calorie Target:")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text("\(userRecommendedCalories) kcal")
                                                .font(.subheadline)
                                                .foregroundColor(.orange)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding(12)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                                    
                                    Button("Update Health Settings") {
                                        showHealthSettings = true
                                    }
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(8)
                                }
                            } else {
                                VStack(spacing: 10) {
                                    Text("Personalize Your Experience")
                                        .font(geometry.size.height < 700 ? .title3 : .title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("Set up your health profile to get personalized calorie recommendations")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("Setup Health Profile") {
                                        showHealthSettings = true
                                    }
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(8)
                                }
                            }
                            
                            // Button Section
                            VStack(spacing: 12) {
                                // Logout Button
                                Button(action: {
                                    logout()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.right.square.fill")
                                        Text("Logout")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.yellow)
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
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
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                }
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
            .sheet(isPresented: $showStatistics) {
                StatisticsView(isPresented: $showStatistics)
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