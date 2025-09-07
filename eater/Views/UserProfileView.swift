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
  @State private var showFeedback = false
  @State private var showAddFriends = false
  @AppStorage("dataDisplayMode") private var dataDisplayMode: String = "simplified"  // "simplified" or "full"
  @EnvironmentObject var languageService: LanguageService
  @State private var showLanguagePicker = false

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
                    Text(loc("profile.name", "Name"))
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
                  Text(loc("profile.email", "Email"))
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
                  Text(loc("profile.viewstats", "View Statistics"))
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

              // Feedback Button
              Button(action: {
                showFeedback = true
              }) {
                HStack {
                  Image(systemName: "message.fill")
                  Text(loc("profile.sharefeedback", "Share Feedback"))
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
              }

              // Add Friends Button
              Button(action: {
                showAddFriends = true
              }) {
                HStack {
                  Image(systemName: "person.crop.circle.badge.plus")
                  Text(loc("profile.addfriends", "Add Friends"))
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.purple)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
              }

              // Health Data Section
              if hasHealthData {
                VStack(spacing: 10) {
                  Text(loc("profile.healthprofile", "Your Health Profile"))
                    .font(geometry.size.height < 700 ? .title3 : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                  VStack(spacing: 8) {
                    HStack {
                      Text(loc("health.height.label", "Height:"))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                      Spacer()
                      Text("\(userHeight, specifier: "%.0f") \(loc("units.cm", "cm"))")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal)

                    HStack {
                      Text(loc("profile.targetweight", "Target Weight:"))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                      Spacer()
                      Text("\(userOptimalWeight, specifier: "%.1f") \(loc("units.kg", "kg"))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal)

                    HStack {
                      Text(loc("profile.dailycalorie", "Daily Calorie Target:"))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                      Spacer()
                      Text("\(userRecommendedCalories) \(loc("units.kcal", "kcal"))")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal)
                  }
                  .padding(12)
                  .background(Color.gray.opacity(0.2))
                  .cornerRadius(10)

                  Button(loc("health.update.title", "Update Health Settings")) {
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
                  Text(loc("profile.personalize", "Personalize Your Experience"))
                    .font(geometry.size.height < 700 ? .title3 : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                  Text(
                    loc(
                      "profile.setuphealth",
                      "Set up your health profile to get personalized calorie recommendations")
                  )
                  .font(.subheadline)
                  .foregroundColor(.gray)
                  .multilineTextAlignment(.center)

                  Button(loc("health.update.title", "Setup Health Profile")) {
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
                // Language Picker
                VStack(alignment: .leading, spacing: 8) {
                  Text(loc("profile.language", "Language"))
                    .font(.caption)
                    .foregroundColor(.gray)
                  Button(action: {
                    print(
                      "[UserProfileView] Language button tapped code=\(languageService.currentCode) name=\(languageService.currentDisplayName)"
                    )
                    showLanguagePicker = true
                  }) {
                    let flag = languageService.flagEmoji(
                      forLanguageCode: languageService.currentCode)
                    HStack {
                      Text(flag)
                      Text(languageService.currentDisplayName)
                        .fontWeight(.semibold)
                      Spacer()
                      Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                  }
                }
                .padding(.vertical, 8)
                .sheet(isPresented: $showLanguagePicker) {
                  LanguageSelectionSheet(isPresented: $showLanguagePicker)
                    .environmentObject(languageService)
                }

                // Data Display Mode Toggle
                VStack(alignment: .leading, spacing: 8) {
                  Text(loc("profile.datamode", "Data Mode"))
                    .font(.caption)
                    .foregroundColor(.gray)
                  Picker("Data Mode", selection: $dataDisplayMode) {
                    Text(loc("common.simplified", "Simplified")).tag("simplified")
                    Text(loc("common.full", "Full")).tag("full")
                  }
                  .font(.system(size: 18, weight: .semibold, design: .rounded))
                  .controlSize(.large)
                  .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.vertical, 8)

                // Tutorial Button
                Button(action: {
                  showOnboarding = true
                }) {
                  HStack {
                    Image(systemName: "book.fill")
                    Text(loc("profile.tutorial", "Tutorial"))
                      .fontWeight(.semibold)
                  }
                  .font(.subheadline)
                  .foregroundColor(.white)
                  .padding(.vertical, 12)
                  .frame(maxWidth: .infinity)
                  .background(Color.orange)
                  .cornerRadius(8)
                  .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }

                // Logout Button
                Button(action: {
                  logout()
                }) {
                  HStack {
                    Image(systemName: "arrow.right.square.fill")
                    Text(loc("profile.logout", "Logout"))
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
                    Text(loc("profile.delete", "Delete Account"))
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
      .navigationTitle(loc("nav.profile", "Profile"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(loc("common.close", "Close")) {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
      .alert(loc("alert.delete.title", "Delete Account"), isPresented: $showDeleteConfirmation) {
        Button(loc("common.cancel", "Cancel"), role: .cancel) {}
        Button(loc("profile.delete", "Delete"), role: .destructive) {
          deleteAccount()
        }
      } message: {
        Text(
          loc(
            "alert.delete.message",
            "Are you sure you want to delete your account? This will immediately remove all your data and preferences from this device and sign you out."
          ))
      }
      .sheet(isPresented: $showOnboarding) {
        OnboardingView(isPresented: $showOnboarding)
          .interactiveDismissDisabled()
      }
      .sheet(isPresented: $showHealthSettings) {
        HealthSettingsView(isPresented: $showHealthSettings)
      }
      .sheet(isPresented: $showStatistics) {
        StatisticsView(isPresented: $showStatistics)
      }
      .sheet(isPresented: $showFeedback) {
        FeedbackView(isPresented: $showFeedback)
      }
      .sheet(isPresented: $showAddFriends) {
        AddFriendsView(isPresented: $showAddFriends)
      }
      .onChange(of: showHealthSettings) { _, newValue in
        if !newValue {  // Sheet was dismissed
          loadHealthData()
        }
      }
      .onAppear {
        loadHealthData()
      }
      // Avoid remounting the entire view while sheets are transitioning
      // Removing id(languageService.currentCode) prevents presentation conflicts
    }
  }

  private func logout() {
    // Clear statistics cache before logging out
    StatisticsService.shared.clearCache()

    // Sign out user and clear local data
    authService.signOut()

    // Immediately dismiss the view - this will show the login view since user is no longer authenticated
    dismiss()
  }

  private func deleteAccount() {
    guard let email = authService.userEmail else {
      AlertHelper.showAlert(
        title: "Error", message: "No user email found. Please try signing in again.")
      return
    }

    // Clear statistics cache before deleting account
    StatisticsService.shared.clearCache()

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
    .environmentObject(
      {
        let authService = AuthenticationService()
        authService.setPreviewState(
          email: "preview@example.com",
          profilePictureURL: "https://lh3.googleusercontent.com/a/default-user=s120-c"
        )
        return authService
      }())
}
