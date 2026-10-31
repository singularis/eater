import SwiftUI

struct UserProfileView: View {
  var embeddedInTab: Bool = false
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
  @ObservedObject private var appSettings = AppSettingsService.shared
  @State private var showLanguagePicker = false
  @State private var remindersEnabled = NotificationService.shared.isEnabled
  @State private var showSignIn = false
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

            healthSection

            actionButton(
              icon: "person.2.fill",
              title: loc("profile.myfriends", "My friends"),
              accessibilityHint: loc("a11y.open_myfriends", "See your friends list")
            ) {
              HapticsService.shared.select()
              showMyFriends = true
            }

            actionButton(
              icon: "chart.line.uptrend.xyaxis",
              title: loc("profile.viewstats", "View Statistics"),
              accessibilityHint: loc("a11y.open_stats", "Opens your statistics dashboard")
            ) {
              HapticsService.shared.select()
              showStatistics = true
            }

            // Theme Section
            sectionHeader(icon: "paintpalette.fill", title: loc("profile.theme", "Theme"), color: Color.purple)
            
            VStack(spacing: 12) {
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
                        .appCardShadow()
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

              Divider().padding(.horizontal, 8)

              Toggle(isOn: Binding(
                get: { appSettings.vibrationEnabled },
                set: { enabled in
                  appSettings.vibrationEnabled = enabled
                  if enabled {
                    HapticsService.shared.foodQuality(rating: 80)
                  }
                }
              )) {
                HStack(spacing: 8) {
                  Image(systemName: appSettings.vibrationEnabled ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                    .font(.system(size: 16))
                    .foregroundColor(appSettings.vibrationEnabled ? AppTheme.accent : AppTheme.textSecondary)

                  VStack(alignment: .leading, spacing: 2) {
                    Text(loc("profile.vibration", "Vibration"))
                      .font(.subheadline)
                      .foregroundColor(AppTheme.textPrimary)
                    Text(loc("profile.vibration.desc", "Pleasant or unpleasant buzz based on food quality"))
                      .font(.caption2)
                      .foregroundColor(AppTheme.textSecondary)
                  }
                }
              }
              .padding(.horizontal, 8)
              .tint(AppTheme.accent)
            }
            .cardContainer(padding: 14)

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

              Toggle(isOn: Binding(
                get: { remindersEnabled },
                set: { desired in
                  NotificationService.shared.requestAuthorizationAndEnable(desired) { _ in
                    remindersEnabled = NotificationService.shared.isEnabled
                  }
                }
              )) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(loc("profile.reminders", "Reminders"))
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                  Text(loc("profile.reminders.desc", "Breakfast, lunch, and dinner while this is on"))
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                }
              }
              .padding(.horizontal, 8)
              .tint(AppTheme.accent)

              Divider().padding(.horizontal, 8)
              
              // Appearance
              VStack(alignment: .leading, spacing: 8) {
                Text(loc("profile.appearance", "Appearance"))
                  .font(.subheadline)
                  .foregroundColor(AppTheme.textPrimary)
                
                Picker("Appearance", selection: Binding<String>(
                  get: { AppSettingsService.shared.appearance.rawValue },
                  set: { AppSettingsService.shared.appearance = AppSettingsService.AppearanceMode(rawValue: $0) ?? .light }
                )) {
                  Text(loc("appearance.light", "Light")).tag(AppSettingsService.AppearanceMode.light.rawValue)
                  Text(loc("appearance.dark", "Dark")).tag(AppSettingsService.AppearanceMode.dark.rawValue)
                }
                .pickerStyle(.segmented)
              }
              .padding(.horizontal, 8)
              
              Divider().padding(.horizontal, 8)

              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(loc("profile.font_size", "Text size"))
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                  Spacer()
                  Text("\(Int((appSettings.fontScale * 100).rounded()))%")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundColor(AppTheme.textSecondary)
                }

                HStack(spacing: 12) {
                  fontScaleButton(
                    title: "A",
                    font: .subheadline.weight(.semibold),
                    label: loc("profile.font_size.smaller", "Smaller text"),
                    enabled: appSettings.fontScale > AppSettingsService.fontScaleMin + 0.001
                  ) {
                    appSettings.stepFontScale(-1)
                  }
                  Spacer(minLength: 0)
                  Button {
                    HapticsService.shared.select()
                    appSettings.resetFontScale()
                  } label: {
                    Text(loc("profile.font_size.match_phone", "Use phone size"))
                      .font(.subheadline.weight(.medium))
                      .lineLimit(1)
                      .minimumScaleFactor(0.7)
                  }
                  .buttonStyle(.plain)
                  .foregroundColor(AppTheme.accent)
                  .disabled(appSettings.followsSystemTextSize)
                  .opacity(appSettings.followsSystemTextSize ? 0.4 : 1)
                  Spacer(minLength: 0)
                  fontScaleButton(
                    title: "A",
                    font: .title2.weight(.semibold),
                    label: loc("profile.font_size.larger", "Larger text"),
                    enabled: appSettings.fontScale < AppSettingsService.fontScaleExtra - 0.001
                  ) {
                    appSettings.stepFontScale(1)
                  }
                }

                Text(loc("profile.font_size.desc", "Make text smaller or larger for your eyes"))
                  .font(.caption2)
                  .foregroundColor(AppTheme.textSecondary)

                Divider()

                Toggle(isOn: Binding(
                  get: { appSettings.extraLargeText },
                  set: { enabled in
                    HapticsService.shared.select()
                    appSettings.setExtraLargeText(enabled)
                  }
                )) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(loc("profile.font_size.extra", "Extra large"))
                      .font(.subheadline)
                      .foregroundColor(AppTheme.textPrimary)
                    Text(loc("profile.font_size.extra.desc", "Sets text to 160%"))
                      .font(.caption2)
                      .foregroundColor(AppTheme.textSecondary)
                  }
                }
                .tint(AppTheme.accent)
              }
              .padding(.horizontal, 8)
              
              Divider().padding(.horizontal, 8)
              
              #if DEBUG
              // Dev Environment
              VStack(alignment: .leading, spacing: 8) {
                Text(loc("profile.dev_environment", "Dev Environment"))
                  .font(.subheadline)
                  .foregroundColor(AppTheme.textPrimary)
                
                Picker("Dev Environment", selection: $useDevEnvironment) {
                  Text(loc("env.production", "Production")).tag(false)
                  Text(loc("env.development", "Development")).tag(true)
                }
                .pickerStyle(.segmented)
                .background(useDevEnvironment ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                .appCorner(AppTheme.tinyRadius)
                .onChange(of: useDevEnvironment) { _, newValue in
                  print("Environment changed to \(newValue ? "DEV" : "PROD")")
                  
                  // Clear caches that depend on the backend environment
                  ProductStorageService.shared.clearCache()
                  StatisticsService.shared.clearCache()
                  
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
              Toggle(isOn: Binding<Bool>(
                get: { appSettings.savePhotosToLibrary },
                set: { appSettings.savePhotosToLibrary = $0 }
              )) {
                HStack(spacing: 8) {
                  Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16))
                    .foregroundColor(
                      appSettings.savePhotosToLibrary ? AppTheme.accent : AppTheme.textSecondary)

                  VStack(alignment: .leading, spacing: 2) {
                    Text(loc("profile.save_photos", "Save to Photo Library"))
                      .font(.subheadline)
                      .foregroundColor(AppTheme.textPrimary)
                    Text(loc("profile.save_photos.desc", "Keep food photos as memories"))
                      .font(.caption2)
                      .foregroundColor(AppTheme.textSecondary)
                  }
                }
              }
              .padding(.horizontal, 8)
              .tint(AppTheme.accent)
            }
            .cardContainer(padding: 14)

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
            .buttonStyle(MascotCalloutButtonStyle())
            .accessibilityHint(loc("a11y.open_tutorial", "Revisit onboarding tutorial"))

            actionButton(
              icon: "message.fill",
              title: loc("profile.sharefeedback", "Share Feedback"),
              accessibilityHint: loc("a11y.open_feedback", "Send feedback to the team")
            ) {
              HapticsService.shared.select()
              showFeedback = true
            }

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
                .foregroundColor(AppTheme.danger)
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
      .scaledNavTitle(loc("nav.profile", "Profile"))
      .toolbar {
        if !embeddedInTab {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(loc("common.done", "Done")) {
              dismiss()
            }
            .foregroundColor(AppTheme.textPrimary)
          }
        }
      }
      .scaledNotice(
        loc("alert.delete.title", "Delete Account"),
        isPresented: $showDeleteConfirmation,
        message: loc(
          "alert.delete.message",
          "Are you sure you want to delete your account? This will immediately remove all your data and preferences from this device and sign you out."
        ),
        actions: [
          ScaledNoticeAction(title: loc("profile.delete", "Delete"), kind: .destructive) {
            deleteAccount()
          },
          ScaledNoticeAction(title: loc("common.cancel", "Cancel"), kind: .secondary),
        ]
      )
      .sheet(isPresented: $showOnboarding) {
        OnboardingView(isPresented: $showOnboarding)
          .interactiveDismissDisabled()
          .appInterfaceScale()
      }
      .sheet(isPresented: $showHealthSettings) {
        HealthSettingsView(isPresented: $showHealthSettings)
          .appInterfaceScale()
      }
      .sheet(isPresented: $showStatistics) {
        StatisticsView(isPresented: $showStatistics)
          .appInterfaceScale()
      }
      .sheet(isPresented: $showFeedback) {
        FeedbackView(isPresented: $showFeedback)
          .appInterfaceScale()
      }
      .sheet(isPresented: $showMyFriends) {
        MyFriendsView(isPresented: $showMyFriends)
          .appInterfaceScale()
      }
      .sheet(isPresented: $showNicknameSettings) {
        NicknameSettingsView()
          .environmentObject(authService)
          .appInterfaceScale()
      }
      .sheet(isPresented: $showLanguagePicker) {
        LanguageSelectionSheet(isPresented: $showLanguagePicker)
          .environmentObject(languageService)
          .appInterfaceScale()
      }
      .sheet(isPresented: $showSignIn) {
        SignInSheet()
          .environmentObject(authService)
          .appInterfaceScale()
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
    // Prefer a short first name when the user actually provided one; never show
    // anon_* / Guest / private-relay fragments (KAN-57: Health Eater fallback).
    if authService.isAnonymous {
      return AnonymousUserIdentity.defaultDisplayName
    }

    let first = userFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
    if AnonymousUserIdentity.isUsablePersonName(first) {
      return first
    }

    if let person = profilePersonName?.split(separator: " ").map(String.init).first,
      AnonymousUserIdentity.isUsablePersonName(person)
    {
      return person
    }

    let display = AnonymousUserIdentity.menuDisplayName(
      nickname: userNickname.isEmpty ? nil : userNickname,
      userName: authService.userName
    )
    if let short = display.split(separator: " ").map(String.init).first,
      AnonymousUserIdentity.isUsablePersonName(short)
    {
      return short
    }
    return display
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
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)
        Button {
          HapticsService.shared.select()
          showSignIn = true
        } label: {
          Text(loc("login.prompt.confirm", "Login Now"))
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 4)
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
  
  private func fontScaleButton(
    title: String,
    font: Font,
    label: String,
    enabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button {
      HapticsService.shared.select()
      action()
    } label: {
      Text(title)
        .font(font)
        .foregroundColor(enabled ? AppTheme.textPrimary : AppTheme.textSecondary)
        .frame(width: 44, height: 44)
        .appCircleSurface()
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.4)
    .accessibilityLabel(label)
  }

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
  
  private var healthSection: some View {
    VStack(spacing: 12) {
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
              color: AppTheme.textPrimary
            )
          }

          healthMetricRow(
            label: loc("profile.targetweight", "Target Weight:"),
            value: String(format: "%.1f", (userTargetWeight > 0 ? userTargetWeight : userOptimalWeight)) + " \(loc("units.kg", "kg"))",
            color: AppTheme.textPrimary
          )

          healthMetricRow(
            label: loc("profile.dailycalorie", "Daily Calorie Target:"),
            value: "\(userRecommendedCalories) \(loc("units.kcal", "kcal"))",
            color: AppTheme.textPrimary
          )

          healthSettingsRow
        }
        .cardContainer(padding: 14)
      } else {
        VStack(spacing: 0) {
          healthSettingsRow
        }
        .cardContainer(padding: 14)
      }
    }
  }

  private var healthSettingsRow: some View {
    Button {
      HapticsService.shared.select()
      showHealthSettings = true
    } label: {
      HStack {
        Text(loc("nav.health_settings", "Health Settings"))
          .font(.subheadline)
          .foregroundColor(AppTheme.textPrimary)
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundColor(AppTheme.textSecondary)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
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
    .padding(.horizontal, 8)
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
      .padding(.vertical, 6)
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
          RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
            .fill(isSelected ? AppTheme.primaryButtonFill : AppTheme.surface)
            .overlay(
              RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(isSelected ? AppTheme.primaryButtonFill : AppTheme.divider, lineWidth: 1)
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
