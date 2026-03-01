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
  @State private var userTargetWeight: Double = 0
  @State private var userRecommendedCalories: Int = 0
  @State private var showStatistics = false
  @State private var showFeedback = false
  @State private var showAddFriends = false
  @State private var showNicknameSettings = false
  @AppStorage("user_nickname") private var userNickname: String = ""
  @AppStorage("dataDisplayMode") private var dataDisplayMode: String = "full"  // "simplified" or "full"
  #if DEBUG
  @AppStorage("use_dev_environment") private var useDevEnvironment: Bool = true
  #else
  @AppStorage("use_dev_environment") private var useDevEnvironment: Bool = false
  #endif
  @EnvironmentObject var languageService: LanguageService
  @State private var showLanguagePicker = false
  @StateObject private var themeService = ThemeService.shared

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

              Button(action: {
                HapticsService.shared.select()
                showNicknameSettings = true
              }) {
                VStack(spacing: 6) {
                  if !userNickname.isEmpty {
                    HStack(spacing: 8) {
                      Text(userNickname)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.textPrimary)
                      Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.accent)
                    }
                    if let userName = authService.userName, !userName.isEmpty {
                      Text(userName)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                    }
                  } else if let userName = authService.userName, !userName.isEmpty {
                    HStack(spacing: 8) {
                      Text(userName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.textPrimary)
                      Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.accent)
                    }
                  } else {
                    HStack(spacing: 8) {
                      Text(loc("profile.set_nickname", "Set Nickname"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.accent)
                      Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.accent)
                    }
                  }
                  Text(authService.userEmail ?? "No email")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(PlainButtonStyle())
              .accessibilityLabel(userNickname.isEmpty ? loc("profile.set_nickname", "Set Nickname") : loc("profile.edit_nickname", "Edit Nickname"))
              .accessibilityHint(loc("a11y.set_nickname", "Set a nickname for sharing with friends"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .cardContainer(padding: 16)

            // Watch me first! Section
            Button(action: {
              HapticsService.shared.select()
              showOnboarding = true
            }) {
              HStack(spacing: 12) {
                // Cat image
                if let catImage = AppMascot.cat.happyImage() {
                  Image(catImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                }

                HStack {
                  Image(systemName: "play.circle.fill")
                  Text(loc("profile.watch_me_first", "Watch me first!"))
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)

                // Dog image
                if let dogImage = AppMascot.dog.happyImage() {
                  Image(dogImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                }
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(GreenToPurpleButtonStyle())
            .accessibilityHint(loc("a11y.open_tutorial", "Revisit onboarding tutorial"))

            // Theme Section
            sectionHeader(icon: "paintpalette.fill", title: loc("profile.theme", "Theme"), color: Color.purple)
            
            VStack(spacing: 14) {
              // Preview of current mascot (5 states for clarity)
              if themeService.currentMascot != .none {
                let previews = themeService.getUniquePreviewImageNames(count: 5)
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    ForEach(previews, id: \.self) { imageName in
                      Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    Spacer(minLength: 0)
                  }
                  .padding(.vertical, 8)
                  .padding(.horizontal, 2)
                }
                .frame(maxWidth: .infinity)
              }
              
              VStack(alignment: .leading, spacing: 12) {
                Text(loc("profile.friend", "Choose Your Friend"))
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(AppTheme.textPrimary)
                
                Text(loc("profile.friend.desc", "Get custom icons, sounds, and motivational messages!"))
                  .font(.caption)
                  .foregroundColor(AppTheme.textSecondary)
                
                // Friend Picker (5 mascots centered)
                HStack(spacing: 12) {
                  ForEach(AppMascot.allCases, id: \.self) { mascot in
                    MascotButton(
                      mascot: mascot,
                      isSelected: themeService.currentMascot == mascot
                    ) {
                      HapticsService.shared.select()
                      themeService.currentMascot = mascot
                      themeService.playSound(for: "happy")
                    }
                  }
                }
                .frame(maxWidth: .infinity, alignment: .center)
              }
              
              Divider().padding(.horizontal, 8)
              
              // Sound Toggle
              Toggle(isOn: $themeService.soundEnabled) {
                HStack(spacing: 8) {
                  Image(systemName: themeService.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeService.soundEnabled ? AppTheme.accent : AppTheme.textSecondary)
                  
                  VStack(alignment: .leading, spacing: 2) {
                    Text(loc("profile.theme.sounds", "Theme Sounds"))
                      .font(.subheadline)
                      .foregroundColor(AppTheme.textPrimary)
                    
                    if themeService.currentMascot != .none {
                      Text(themeService.currentMascot == .cat ? loc("profile.theme.sounds.cat", "Meow sounds") : loc("profile.theme.sounds.dog", "Woof sounds"))
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    }
                  }
                }
              }
              .padding(.horizontal, 8)
              .tint(AppTheme.accent)
              .disabled(themeService.currentMascot == .none)
              .opacity(themeService.currentMascot == .none ? 0.5 : 1.0)
            }
            .padding(.vertical, 14)
            .cardContainer(padding: 14)

            // Health Section (first)
            sectionHeader(icon: "heart.fill", title: loc("profile.health", "Health"), color: Color.pink)
            
            if hasHealthData {
              VStack(spacing: 12) {
                healthMetricRow(
                  label: loc("health.height.label", "Height:"),
                  value: String(format: "%.0f", userHeight) + " \(loc("units.cm", "cm"))",
                  color: AppTheme.textPrimary
                )

                let currentBMI: Double = {
                  let hm = userHeight / 100.0
                  guard hm > 0, userWeight > 0 else { return 0 }
                  return userWeight / (hm * hm)
                }()
                if currentBMI > 0 {
                  healthMetricRow(
                    label: loc("health.bmi.label", "BMI:"),
                    value: String(format: "%.1f", currentBMI),
                    color: .blue
                  )
                }
                
                healthMetricRow(
                  label: loc("profile.targetweight", "Target Weight:"),
                  value: String(format: "%.1f", (userTargetWeight > 0 ? userTargetWeight : userOptimalWeight)) + " \(loc("units.kg", "kg"))",
                  color: AppTheme.success
                )
                
                healthMetricRow(
                  label: loc("profile.dailycalorie", "Daily Calorie Target:"),
                  value: "\(userRecommendedCalories) \(loc("units.kcal", "kcal"))",
                  color: AppTheme.warning
                )
                
                Button(action: {
                  HapticsService.shared.select()
                  showHealthSettings = true
                }) {
                  Text(loc("health.update.title", "Update Health Settings"))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                      RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(
                          LinearGradient(
                            colors: [
                              Color(red: 0.72, green: 0.62, blue: 0.92),
                              Color(red: 0.65, green: 0.52, blue: 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        )
                    )
                }
                .buttonStyle(PressScaleButtonStyle())
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
                
                Button(action: {
                  HapticsService.shared.select()
                  showHealthSettings = true
                }) {
                  Text(loc("health.update.title", "Setup Health Profile"))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                      RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(
                          LinearGradient(
                            colors: [
                              Color(red: 0.72, green: 0.62, blue: 0.92),
                              Color(red: 0.65, green: 0.52, blue: 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        )
                    )
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityHint(loc("a11y.setup_health", "Provide data to personalize plan"))
              }
              .cardContainer(padding: 14)
            }

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
              
              Divider().padding(.horizontal, 8)
              
              #if DEBUG
              // Dev Environment
              VStack(alignment: .leading, spacing: 8) {
                Text(loc("profile.dev_environment", "Dev Environment"))
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(AppTheme.textSecondary)
                
                Picker("Dev Environment", selection: $useDevEnvironment) {
                  Text(loc("env.production", "Production")).tag(false)
                  Text(loc("env.development", "Development")).tag(true)
                }
                .pickerStyle(.segmented)
                .background(useDevEnvironment ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                .cornerRadius(8)
                .onChange(of: useDevEnvironment) { _, newValue in
                  print("Environment changed to \(newValue ? "DEV" : "PROD")")
                  
                  // Clear caches that depend on the backend environment
                  ProductStorageService.shared.clearCache()
                  StatisticsService.shared.clearExpiredCache()
                  
                  // Clear local chess data so we don't mix environments
                  let chessKeys = [
                    "chessTotalWins", "chessOpponents", "lastChessDate",
                    "chessWinsStartOfDay", "chessOpponentsStartOfDay",
                    "chessOpponentName", "chessOpponentEmail"
                  ]
                  chessKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
                  
                  // Notify all views (including ActivitiesView) about the environment change
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(name: NSNotification.Name("EnvironmentChanged"), object: nil)
                  }
                }
              }
              .padding(.horizontal, 8)
              
              Divider().padding(.horizontal, 8)
              #endif
              
              // Save Photos to Library
              HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                  .font(.system(size: 20, weight: .semibold))
                  .foregroundStyle(
                    LinearGradient(
                      colors: [Color.purple, Color.blue],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    )
                  )
                  .frame(width: 28)
                
                Toggle(isOn: Binding<Bool>(
                  get: { AppSettingsService.shared.savePhotosToLibrary },
                  set: { AppSettingsService.shared.savePhotosToLibrary = $0 }
                )) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(loc("profile.save_photos", "Save to Photo Library"))
                      .font(.subheadline)
                      .foregroundColor(AppTheme.textPrimary)
                    Text(loc("profile.save_photos.desc", "Keep food photos as memories"))
                      .font(.caption2)
                      .foregroundColor(AppTheme.textSecondary)
                  }
                }
                .tint(
                  LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 6)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(.ultraThinMaterial)
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(
                        LinearGradient(
                          colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                      )
                  )
              )
              .padding(.horizontal, 4)
            }
            .padding(.vertical, 12)
            .cardContainer(padding: 12)

            // Account Section
            sectionHeader(icon: "person.badge.key.fill", title: loc("profile.account", "Account"), color: Color.orange)
            
            VStack(spacing: 10) {
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
                .foregroundColor(Color(red: 0.42, green: 0.0, blue: 0.05))
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                  RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(Color.white)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
              }
              .buttonStyle(PressScaleButtonStyle())
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
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(loc("common.done", "Done")) {
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
      .sheet(isPresented: $showNicknameSettings) {
        NicknameSettingsView()
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
    
    // Clear chess data (ActivitiesView AppStorage) so it doesn't persist to other accounts/environments
    let chessKeys = [
      "chessTotalWins", "chessOpponents", "lastChessDate",
      "chessWinsStartOfDay", "chessOpponentsStartOfDay",
      "chessOpponentName", "chessOpponentEmail"
    ]
    chessKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

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
    
    // Clear persisted tutorials
    KeychainHelper.shared.clearAll()

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
      userTargetWeight = userDefaults.double(forKey: "userTargetWeight")
      // Use same source as main screen (ContentView) so "Daily Calorie Target" matches everywhere
      let soft = CalorieLimitsStorageService.shared.load()?.softLimit ?? userDefaults.integer(forKey: "softLimit")
      userRecommendedCalories = soft > 0 ? soft : userDefaults.integer(forKey: "userRecommendedCalories")
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

// MARK: - Mascot Button

struct MascotButton: View {
  let mascot: AppMascot
  let isSelected: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? 
              LinearGradient(
                colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ) : 
              LinearGradient(
                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 2)
            )
          
          if mascot == .none {
            Image(systemName: "star.fill")
              .font(.system(size: 32))
              .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
          } else {
            // Show actual mascot image if available
            if let imageName = mascot.happyImage() {
              Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
              // Fallback: paw instead of emoji
              Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            }
          }
        }
        .frame(height: 70)
        
        Text(loc("profile.theme.name.\(mascot.rawValue)", mascot.displayName))
          .font(.caption)
          .fontWeight(isSelected ? .bold : .medium)
          .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
      }
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
