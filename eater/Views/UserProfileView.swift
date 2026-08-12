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
  @State private var showMyFriends = false
  @State private var showNicknameSettings = false
  @AppStorage("user_nickname") private var userNickname: String = ""
  @AppStorage("user_first_name") private var userFirstName: String = ""
  @AppStorage("user_last_name") private var userLastName: String = ""
  @AppStorage("user_profile_picture_id") private var userProfilePictureId: String = ""
  @ObservedObject private var profilePhotoStore = ProfilePhotoStore.shared
  #if DEBUG
  @AppStorage("use_dev_environment") private var useDevEnvironment: Bool = true
  #else
  @AppStorage("use_dev_environment") private var useDevEnvironment: Bool = false
  #endif
  @EnvironmentObject var languageService: LanguageService
  @State private var showLanguagePicker = false
  @ObservedObject private var themeService = ThemeService.shared
  /// Defer heavy mascot artwork so menu buttons appear immediately.
  @State private var loadMascotArtwork = false

  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient
          .edgesIgnoringSafeArea(.all)

        ScrollView {
          LazyVStack(spacing: 20) {
            profileHeader

            // Statistics at top of menu (before Watch me first)
            actionButton(
              icon: "chart.line.uptrend.xyaxis",
              title: loc("profile.viewstats", "View Statistics"),
              accessibilityHint: loc("a11y.open_stats", "Opens your statistics dashboard")
            ) {
              HapticsService.shared.select()
              showStatistics = true
            }

            // Watch me first! Section
            Button(action: {
              HapticsService.shared.select()
              showOnboarding = true
            }) {
              HStack(spacing: 12) {
                if loadMascotArtwork, let catImage = AppMascot.cat.happyImage() {
                  Image(catImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                  Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                }

                HStack {
                  Image(systemName: "play.circle.fill")
                  Text(loc("profile.watch_me_first", "Watch me first!"))
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)

                if loadMascotArtwork, let dogImage = AppMascot.dog.happyImage() {
                  Image(dogImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                  Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                }
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(GreenToPurpleButtonStyle())
            .accessibilityHint(loc("a11y.open_tutorial", "Revisit onboarding tutorial"))

            // Theme Section
            sectionHeader(icon: "paintpalette.fill", title: loc("profile.theme", "Theme"), color: Color.purple)
            
            VStack(spacing: 14) {
              // Preview of current mascot (deferred until menu is interactive)
              if loadMascotArtwork, themeService.currentMascot != .none {
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
                icon: "message.fill",
                title: loc("profile.sharefeedback", "Share Feedback"),
                accessibilityHint: loc("a11y.open_feedback", "Send feedback to the team")
              ) {
                HapticsService.shared.select()
                showFeedback = true
              }
              
              actionButton(
                icon: "person.2.fill",
                title: loc("profile.myfriends", "My friends"),
                accessibilityHint: loc("a11y.open_myfriends", "See your friends list")
              ) {
                HapticsService.shared.select()
                showMyFriends = true
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
              Text(appVersionLabel)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)

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
      .sheet(isPresented: $showMyFriends) {
        MyFriendsView(isPresented: $showMyFriends)
      }
      .sheet(isPresented: $showNicknameSettings) {
        NicknameSettingsView()
          .environmentObject(authService)
      }
      .sheet(isPresented: $showLanguagePicker) {
        LanguageSelectionSheet(isPresented: $showLanguagePicker)
          .environmentObject(languageService)
      }
      .onChange(of: showHealthSettings) { _, newValue in
        if !newValue {  // Sheet was dismissed
          loadHealthData()
        }
      }
      .onChange(of: showNicknameSettings) { _, newValue in
        if !newValue {
          refreshProfileFromServer()
        }
      }
      .onAppear {
        loadHealthData()
        refreshProfileFromServer()
        // Let buttons paint first, then load mascot bitmaps.
        DispatchQueue.main.async {
          loadMascotArtwork = true
        }
      }
      // Avoid remounting the entire view while sheets are transitioning
      // Removing id(languageService.currentCode) prevents presentation conflicts
    }
  }

  private static let greetingLilac = Color(red: 0.72, green: 0.66, blue: 0.88)
  private static let nicknameApricot = LinearGradient(
    colors: [
      Color(red: 1.00, green: 0.84, blue: 0.70),
      Color(red: 1.00, green: 0.70, blue: 0.52),
    ],
    startPoint: .leading,
    endPoint: .trailing
  )

  private var greetingFirstName: String {
    let first = userFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !first.isEmpty { return first }
    if let person = profilePersonName?.split(separator: " ").first, !person.isEmpty {
      return String(person)
    }
    if AnonymousUserIdentity.hasUsableNickname(userNickname) {
      return userNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let name = authService.userName?.split(separator: " ").first, !name.isEmpty {
      return String(name)
    }
    return AnonymousUserIdentity.defaultDisplayName
  }

  private var profileHeader: some View {
    VStack(alignment: .center, spacing: 8) {
      HStack(alignment: .center, spacing: 12) {
        profileAvatar(size: 48)
        Text(loc("profile.header", "Profile"))
          .font(.title3)
          .fontWeight(.bold)
          .foregroundColor(AppTheme.textPrimary)
        Spacer()
      }

      if authService.isAnonymous {
        Text(String(format: loc("profile.hi", "Hi, %@!"), greetingFirstName))
          .font(.title3)
          .fontWeight(.semibold)
          .foregroundColor(Self.greetingLilac)
        Text(loc("profile.trial_usage.hint", "Sign in to save your progress"))
          .font(.caption2)
          .foregroundColor(AppTheme.textSecondary)
      } else {
        Button(action: {
          HapticsService.shared.select()
          showNicknameSettings = true
        }) {
          VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 6) {
              Text(String(format: loc("profile.hi", "Hi, %@!"), greetingFirstName))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Self.greetingLilac)
              Image(systemName: "pencil.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.accent)
            }

            if AnonymousUserIdentity.hasUsableNickname(userNickname) {
              Text(userNickname.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Self.nicknameApricot)
            }

            if let email = AnonymousUserIdentity.menuEmailSubtitle(email: authService.userEmail) {
              Text(email)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
            }
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(
          userNickname.isEmpty
            ? loc("profile.set_nickname", "Set Nickname")
            : loc("profile.edit_nickname", "Edit Profile")
        )
        .accessibilityHint(loc("a11y.set_nickname", "Set a nickname for sharing with friends"))
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 4)
    .padding(.top, 4)
    .padding(.bottom, 4)
  }

  private func profileAvatar(size: CGFloat) -> some View {
    ZStack(alignment: .bottomTrailing) {
      if let customPhoto = profilePhotoStore.image {
        Image(uiImage: customPhoto)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: size, height: size)
          .clipShape(Circle())
      } else {
        ProfileImageView(
          profilePictureURL: authService.isAnonymous ? nil : authService.userProfilePictureURL,
          size: size,
          fallbackIconColor: authService.isAnonymous ? AppTheme.trialUsage : AppTheme.textPrimary,
          userName: authService.isAnonymous ? nil : profilePersonName ?? authService.userName,
          userEmail: authService.isAnonymous ? nil : authService.userEmail
        )
      }

      if !authService.isAnonymous {
        Image(systemName: "pencil.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(AppTheme.accent)
          .background(Circle().fill(AppTheme.surface).padding(-1))
          .offset(x: 2, y: 2)
          .onTapGesture {
            HapticsService.shared.select()
            showNicknameSettings = true
          }
      }
    }
  }

  private var profilePersonName: String? {
    let parts = [userFirstName, userLastName]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let joined = parts.joined(separator: " ")
    return joined.isEmpty ? nil : joined
  }

  private func refreshProfileFromServer() {
    guard !authService.isAnonymous else { return }
    GRPCService().fetchProfile { profile in
      DispatchQueue.main.async {
        guard let profile else {
          loadCustomProfilePhotoIfNeeded()
          return
        }
        if let nick = profile.nickname, !nick.isEmpty {
          userNickname = nick
        }
        if let first = profile.firstName, !first.isEmpty {
          userFirstName = first
        }
        if let last = profile.lastName, !last.isEmpty {
          userLastName = last
        }
        if let pictureId = profile.profilePictureId, !pictureId.isEmpty {
          userProfilePictureId = pictureId
        }
        if let personName = profilePersonName, !personName.isEmpty {
          authService.userName = personName
          UserDefaults.standard.set(personName, forKey: "user_name")
        }
        loadCustomProfilePhotoIfNeeded()
      }
    }
  }

  private func loadCustomProfilePhotoIfNeeded() {
    if profilePhotoStore.image == nil,
      let disk = ImageStorageService.shared.loadCachedImage(forImageId: userProfilePictureId)
    {
      ProfilePhotoStore.shared.setLocal(disk)
    }
    guard !userProfilePictureId.isEmpty else { return }
    FoodPhotoService.shared.fetchPhoto(imageId: userProfilePictureId) { image in
      guard let image else { return }
      DispatchQueue.main.async {
        ProfilePhotoStore.shared.setFromServer(image, imageId: userProfilePictureId)
      }
    }
  }

  private var appVersionLabel: String {
    let version =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    let number = build.isEmpty ? version : "\(version) (\(build))"
    if useDevEnvironment {
      return loc("profile.app_version", "Version") + " \(number) beta"
    }
    return loc("profile.app_version", "Version") + " \(number)"
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
          } else if let imageName = mascot.happyImage() {
            Image(imageName)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 50, height: 50)
              .clipShape(Circle())
          } else {
            Image(systemName: "pawprint.circle.fill")
              .font(.system(size: 32))
              .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
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
