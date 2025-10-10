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
      ZStack {
        AppTheme.backgroundGradient
          .edgesIgnoringSafeArea(.all)

        ScrollView {
          VStack(spacing: 20) {
            // Profile Section
            sectionHeader(icon: "person.circle.fill", title: loc("profile.header", "Profile"), color: AppTheme.accent)
            
            VStack(spacing: 12) {
              ProfileImageView(
                profilePictureURL: authService.userProfilePictureURL,
                size: 70,
                fallbackIconColor: AppTheme.textPrimary,
                userName: authService.userName,
                userEmail: authService.userEmail
              )

              if let userName = authService.userName, !userName.isEmpty {
                Text(userName)
                  .font(.title2)
                  .fontWeight(.bold)
                  .foregroundColor(AppTheme.textPrimary)
              }

              Text(authService.userEmail ?? "No email")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .cardContainer(padding: 16)

            // Actions Section
            sectionHeader(icon: "bolt.fill", title: loc("profile.actions", "Actions"), color: AppTheme.success)
            
            VStack(spacing: 10) {
              actionButton(
                icon: "chart.line.uptrend.xyaxis",
                title: loc("profile.viewstats", "View Statistics"),
                accessibilityHint: loc("a11y.open_stats", "Opens your statistics dashboard")
              ) {
                HapticsService.shared.select()
                showStatistics = true
              }
              
              actionButton(
                icon: "message.fill",
                title: loc("profile.sharefeedback", "Share Feedback"),
                accessibilityHint: loc("a11y.open_feedback", "Send feedback to the team")
              ) {
                HapticsService.shared.select()
                showFeedback = true
              }
              
              actionButton(
                icon: "person.crop.circle.badge.plus",
                title: loc("profile.addfriends", "Add Friends"),
                accessibilityHint: loc("a11y.open_addfriends", "Search and add friends")
              ) {
                HapticsService.shared.select()
                showAddFriends = true
              }
            }

            // Health Section
            sectionHeader(icon: "heart.fill", title: loc("profile.health", "Health"), color: Color.pink)
            
            if hasHealthData {
              VStack(spacing: 12) {
                healthMetricRow(
                  label: loc("health.height.label", "Height:"),
                  value: String(format: "%.0f", userHeight) + " \(loc("units.cm", "cm"))",
                  color: AppTheme.textPrimary
                )
                
                healthMetricRow(
                  label: loc("profile.targetweight", "Target Weight:"),
                  value: String(format: "%.1f", userOptimalWeight) + " \(loc("units.kg", "kg"))",
                  color: AppTheme.success
                )
                
                healthMetricRow(
                  label: loc("profile.dailycalorie", "Daily Calorie Target:"),
                  value: "\(userRecommendedCalories) \(loc("units.kcal", "kcal"))",
                  color: AppTheme.warning
                )
                
                Button(loc("health.update.title", "Update Health Settings")) {
                  HapticsService.shared.select()
                  showHealthSettings = true
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint(loc("a11y.open_health", "Edit health settings for recommendations"))
              }
              .cardContainer(padding: 14)
            } else {
              VStack(spacing: 12) {
                Text(loc("profile.personalize", "Personalize Your Experience"))
                  .font(.headline)
                  .foregroundColor(AppTheme.textPrimary)
                
                Text(loc("profile.setuphealth", "Set up your health profile to get personalized calorie recommendations"))
                  .font(.subheadline)
                  .foregroundColor(AppTheme.textSecondary)
                  .multilineTextAlignment(.center)
                
                Button(loc("health.update.title", "Setup Health Profile")) {
                  HapticsService.shared.select()
                  showHealthSettings = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint(loc("a11y.setup_health", "Provide data to personalize plan"))
              }
              .cardContainer(padding: 14)
            }

            // Preferences Section
            sectionHeader(icon: "gearshape.fill", title: loc("profile.preferences", "Preferences"), color: Color.purple)
            
            VStack(spacing: 12) {
              // Language
              preferenceRow(
                label: loc("profile.language", "Language"),
                action: {
                  HapticsService.shared.select()
                  print(
                    "[UserProfileView] Language button tapped code=\(languageService.currentCode) name=\(languageService.currentDisplayName)"
                  )
                  showLanguagePicker = true
                }
              ) {
                let flag = languageService.flagEmoji(forLanguageCode: languageService.currentCode)
                HStack(spacing: 6) {
                  Text(flag)
                  Text(languageService.currentDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                  Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                }
              }
              .sheet(isPresented: $showLanguagePicker) {
                LanguageSelectionSheet(isPresented: $showLanguagePicker)
                  .environmentObject(languageService)
              }
              
              Divider().padding(.horizontal, 8)
              
              // Appearance
              VStack(alignment: .leading, spacing: 8) {
                Text(loc("profile.appearance", "Appearance"))
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(AppTheme.textSecondary)
                
                Picker("Appearance", selection: Binding<String>(
                  get: { AppSettingsService.shared.appearance.rawValue },
                  set: { AppSettingsService.shared.appearance = AppSettingsService.AppearanceMode(rawValue: $0) ?? .system }
                )) {
                  Text(loc("appearance.system", "System")).tag(AppSettingsService.AppearanceMode.system.rawValue)
                  Text(loc("appearance.light", "Light")).tag(AppSettingsService.AppearanceMode.light.rawValue)
                  Text(loc("appearance.dark", "Dark")).tag(AppSettingsService.AppearanceMode.dark.rawValue)
                }
                .pickerStyle(.segmented)
              }
              .padding(.horizontal, 8)
              
              Divider().padding(.horizontal, 8)
              
              // Reduce Motion
              Toggle(isOn: Binding<Bool>(
                get: { AppSettingsService.shared.reduceMotion },
                set: { AppSettingsService.shared.reduceMotion = $0 }
              )) {
                Text(loc("profile.reduce_motion", "Reduce Motion"))
                  .font(.subheadline)
              }
              .padding(.horizontal, 8)
              
              Divider().padding(.horizontal, 8)
              
              // Data Mode
              VStack(alignment: .leading, spacing: 8) {
                Text(loc("profile.datamode", "Data Mode"))
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(AppTheme.textSecondary)
                
                Picker("Data Mode", selection: $dataDisplayMode) {
                  Text(loc("common.simplified", "Simplified")).tag("simplified")
                  Text(loc("common.full", "Full")).tag("full")
                }
                .pickerStyle(.segmented)
              }
              .padding(.horizontal, 8)
            }
            .padding(.vertical, 12)
            .cardContainer(padding: 12)

            // Account Section
            sectionHeader(icon: "person.badge.key.fill", title: loc("profile.account", "Account"), color: Color.orange)
            
            VStack(spacing: 10) {
              Button(action: {
                HapticsService.shared.select()
                showOnboarding = true
              }) {
                HStack {
                  Image(systemName: "book.fill")
                  Text(loc("profile.tutorial", "Tutorial"))
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(PrimaryButtonStyle())
              .accessibilityHint(loc("a11y.open_tutorial", "Revisit onboarding tutorial"))

              Button(action: {
                HapticsService.shared.warning()
                logout()
              }) {
                HStack {
                  Image(systemName: "arrow.right.square.fill")
                  Text(loc("profile.logout", "Logout"))
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(SecondaryButtonStyle())
              .accessibilityHint(loc("a11y.logout", "Signs you out of the app"))

              Button(action: {
                HapticsService.shared.error()
                showDeleteConfirmation = true
              }) {
                HStack {
                  Image(systemName: "trash.fill")
                  Text(loc("profile.delete", "Delete Account"))
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(DestructiveButtonStyle())
              .accessibilityHint(loc("a11y.delete_account", "Permanently delete your account"))
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
      }
      .navigationTitle(loc("nav.profile", "Profile"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(loc("common.close", "Close")) {
            dismiss()
          }
          .foregroundColor(AppTheme.textPrimary)
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
  
  // MARK: - Helper Views
  
  private func sectionHeader(icon: String, title: String, color: Color) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(color)
      
      Text(title)
        .font(.title3)
        .fontWeight(.bold)
        .foregroundColor(AppTheme.textPrimary)
      
      Spacer()
    }
    .padding(.horizontal, 4)
    .padding(.top, 8)
  }
  
  private func actionButton(icon: String, title: String, accessibilityHint: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 16, weight: .semibold))
          .frame(width: 24)
        Text(title)
          .fontWeight(.semibold)
        Spacer()
      }
      .font(.subheadline)
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(PrimaryButtonStyle())
    .accessibilityHint(accessibilityHint)
  }
  
  private func healthMetricRow(label: String, value: String, color: Color) -> some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundColor(AppTheme.textSecondary)
      Spacer()
      Text(value)
        .font(.subheadline)
        .fontWeight(.bold)
        .foregroundColor(color)
    }
    .padding(.horizontal, 4)
  }
  
  private func preferenceRow<Content: View>(label: String, action: @escaping () -> Void, @ViewBuilder trailing: () -> Content) -> some View {
    Button(action: action) {
      HStack {
        Text(label)
          .font(.subheadline)
          .foregroundColor(AppTheme.textPrimary)
        Spacer()
        trailing()
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
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
