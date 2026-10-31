import SwiftUI

struct FullScreenPhotoData: Identifiable {
  let id = UUID()
  let image: UIImage?
  let foodName: String
}

struct FixFoodNameData: Identifiable {
  let id = UUID()
  let time: Int64
  let imageId: String
  let currentName: String
  var alternativeNames: [String] = []
  var photo: UIImage? = nil
}

struct ContentView: View {
  @EnvironmentObject var authService: AuthenticationService
  @EnvironmentObject var languageService: LanguageService
  @ObservedObject private var appSettings = AppSettingsService.shared
  @Environment(\.scenePhase) var scenePhase
  @StateObject private var themeService = ThemeService.shared
  @ObservedObject private var profilePhotoStore = ProfilePhotoStore.shared
  @ObservedObject private var nav = AppNavigation.shared
  @ObservedObject private var appleHealth = AppleHealthService.shared
  @State private var products: [Product] = []
  @State private var dayFoodScore: Int? = nil
  @State private var dayFoodScoreTime: Int64 = 0
  @State private var dayFoodScoreDay: String = ""
  @State private var dayScoreLoading = false
  @State private var dayScoreFailed = false
  @State private var dayScorePollID = UUID()
  @State private var caloriesLeft: Int = 0
  @State private var personWeight: Float = 0
  @State private var date = Date()
  @State private var selectedDate = Date()
  @State private var showCamera = false
  @State private var showLimitsAlert = false
  @State private var showCaloriesLeftInfo = false
  @State private var openLimitsAfterInfo = false
  @State private var openHealthAfterInfo = false
  @State private var showHealthSettings = false
  @State private var tempSoftLimit = ""
  @State private var tempHardLimit = ""
  @State private var softLimit = 1900
  @State private var hardLimit = 2100
  @State private var showUserProfile = false
  @State private var showHealthDisclaimer = false
  @State private var showOnboarding = false
  @State private var showHealthPlan = false
  @State private var onboardingMode: OnboardingView.OnboardingMode = .initial
  @State private var showCalendarPicker = false
  @State private var isViewingCustomDate = false
  @State private var currentViewingDate = ""
  @State private var currentViewingDateString = ""  // Original format dd-MM-yyyy
  // Alcohol states
  @State private var showAlcoholCalendar = false
  @State private var alcoholIconColor: Color = .green
  @State private var lastAlcoholEventDate: Date? = nil
  @State private var showMainAppTutorial = false
  @State private var activeTutorialStep: MainAppTutorialView.TutorialStep? = nil
  #if DEBUG
  @AppStorage("use_dev_environment") private var useDevEnvironment: Bool = true
  #else
  @AppStorage("use_dev_environment") private var useDevEnvironment: Bool = false
  #endif
  
  // Activities icon color (green if any activity today, orange if not)
  private var sportIconColor: Color {
    let today = getCurrentUTCDateString()
    let hasCalories = todaySportCaloriesDate == today && todaySportCalories > 0
    let hasActivity = todayActivityDate == today
    return (hasCalories || hasActivity) ? .green : .orange
  }
  // New loading states
  @State private var isLoadingData = false
  @State private var isLoadingWeightPhoto = false
  @State private var isLoadingFoodPhoto = false
  @State private var deletingProductTime: Int64? = nil
  @State private var isFetchingData = false  // Flag to prevent multiple simultaneous data fetches

  // Tutorial pending action
  enum PendingTutorialAction {
      case none
      case alcohol
      case calendar
      case healthInfo
      case sport
      case weight
      case calories
      case typeFood
  }
  @State private var pendingTutorialAction: PendingTutorialAction = .none

  // Full-screen photo states
  @State private var fullScreenPhotoData: FullScreenPhotoData? = nil
  @State private var fixFoodNameData: FixFoodNameData? = nil

  // Weight input states
  @State private var showWeightActionSheet = false
  @State private var manualWeightInput = ""
  @State private var openWeightCameraAfterPrompt = false
  @State private var pendingWeightPhotoCheck = false  // Flag to check motivation after weight photo

  // Daily refresh states
  @State private var dailyRefreshTimer: Timer?
  @State private var lastKnownUTCDate: String = ""

  // Activities states
  @State private var showActivitiesView = false
  @State private var uiRefreshTrigger = false
  @AppStorage("todaySportCalories") private var todaySportCalories = 0
  @AppStorage("todaySportCaloriesDate") private var todaySportCaloriesDate: String = ""
  @AppStorage("todayActivityDate") private var todayActivityDate: String = ""

  // Progressive Onboarding
  @State private var showProgressiveOnboarding = false
  @State private var progressiveStep: ProgressiveOnboardingStep = .none

  // Macros (full mode)
  @State private var proteins: Double = 0
  @State private var fats: Double = 0
  @State private var carbs: Double = 0
  @State private var sugar: Double = 0
  private var hasMacrosData: Bool { (proteins + fats + carbs + sugar) > 0 }
  @State private var showMacroTargets: Bool = false

  private var localizedDateFormatter: DateFormatter {
    let df = DateFormatter()
    df.locale = Locale(identifier: languageService.currentCode)
    df.dateStyle = .medium
    df.timeStyle = .none
    return df
  }

  /// Home screen horizontal swipe:
  ///   left  → Statistics tab
  ///   right → Photo
  /// Food-row swipes claim the arbiter so card options/delete still win on cards.
  private var homeSwipeGesture: some Gesture {
    DragGesture(minimumDistance: 40)
      .onEnded { value in
        let dx = value.translation.width
        let dy = value.translation.height
        guard abs(dx) > abs(dy), abs(dx) > 70 else { return }
        guard !FoodSwipeArbiter.shared.rowSwipeActive else { return }
        HapticsService.shared.select()
        if dx < 0 {
          nav.selectedTab = .stats
        } else {
          nav.openCamera()
        }
      }
  }

  var body: some View {
    ZStack {
      AppTheme.backgroundGradient
        .edgesIgnoringSafeArea(.all)

      // Main screen is not inside a page TabView, so horizontal swipes
      // are ours (Statistics / Camera) instead of a competing pager.
      VStack(spacing: homeRowGap) {
        topBarView
        if authService.isAnonymous {
          guestLoginInvite
        }
        statsButtonsView
        if hasMacrosData {
          macrosLineView
        }

        ProductListView(
          products: products,
          onRefresh: refreshAction,
          onDelete: deleteProductWithLoading,
          onModify: modifyProductPortion,
          onTryAgain: tryAgainProduct,
          onAddSugar: addSugarToProduct,
          onAddDrinkExtra: addExtraToProduct,
          onAddFoodExtra: addExtraToProduct,
          onPhotoTap: showFullScreenPhoto,
          deletingProductTime: deletingProductTime,
          onShareSuccess: {
            StatisticsService.shared.invalidateDay(
              currentViewingDateString.isEmpty ? nil : currentViewingDateString)
            ProductStorageService.shared.clearCache()
            self.returnToToday()
          }
        )
        .padding(.top, 0)
      }
      .contentShape(Rectangle())
      .simultaneousGesture(homeSwipeGesture)
      .onAppear {
        loadLimitsFromUserDefaults()
        loadTodaySportCalories()
        if personWeight == 0 {
          let w = UserDefaults.standard.double(forKey: "userWeight")
          if w > 0 { personWeight = Float(w) }
        }
        fetchDataWithLoading()
        refreshDayFoodScore()
        refreshMacrosForCurrentView()
        setupDailyRefreshTimer()
        setupActivityCaloriesObserver()

        // Tutorial once per account (survives logout / reinstall of session)
        if !AppSettingsService.shared.hasCompletedInitialOnboarding(for: authService.userEmail) {
          onboardingMode = .initial
          showOnboarding = true
        } else if AppSettingsService.shared.shouldShowHealthOnboarding(for: authService.userEmail) {
          showHealthPlan = true
        } else if AppSettingsService.shared.shouldShowSocialOnboarding(for: authService.userEmail) {
            onboardingMode = .social
            showOnboarding = true
        }

        fetchAlcoholStatus()
        syncMealNav()
        appleHealth.startObserving()
      }
      .task(id: "\(currentActivitiesDateISO())-\(appleHealth.activityEnabled)") {
        await appleHealth.refresh(dayISO: currentActivitiesDateISO())
      }
      .onDisappear {
        stopDailyRefreshTimer()
      }
      .onChange(of: todaySportCalories) {
        // Force UI refresh when sport calories change
        uiRefreshTrigger.toggle()
      }
      .onChange(of: todayActivityDate) {
        uiRefreshTrigger.toggle()
      }
      .onChange(of: nav.returnToTodayToken) { _, _ in
        if isViewingCustomDate {
          returnToToday()
        }
      }
      .onChange(of: nav.photoSuccessToken) { _, _ in
        handlePhotoLogged()
      }
      .onChange(of: nav.accountMergedToken) { _, _ in
        returnToToday()
        refreshDayFoodScore()
      }
      .onChange(of: products) { _, _ in
        syncMealNav()
      }
      .onChange(of: isViewingCustomDate) { _, _ in
        syncMealNav()
      }
      .onChange(of: selectedDate) { _, _ in
        syncMealNav()
      }
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          AppSettingsService.shared.followSystemTextSize()
          NotificationService.shared.rescheduleIfEnabled()
          Task { await appleHealth.refresh(dayISO: currentActivitiesDateISO()) }
        }
        if newPhase == .inactive || newPhase == .background {
          if isViewingCustomDate {
             returnToToday()
          }
        }
      }
      .padding()
      .sheet(isPresented: $showCaloriesLeftInfo, onDismiss: {
        if openLimitsAfterInfo {
          openLimitsAfterInfo = false
          tempSoftLimit = String(softLimit)
          tempHardLimit = String(hardLimit)
          DispatchQueue.main.async { showLimitsAlert = true }
        } else if openHealthAfterInfo {
          openHealthAfterInfo = false
          DispatchQueue.main.async { showHealthSettings = true }
        }
      }) {
        CaloriesLeftSheet(
          remaining: caloriesRemaining,
          onSetLimits: { openLimitsAfterInfo = true },
          onCalculateLimits: { openHealthAfterInfo = true }
        )
      }
      .sheet(isPresented: $showHealthSettings, onDismiss: {
        let w = UserDefaults.standard.double(forKey: "userWeight")
        if w > 0 { personWeight = Float(w) }
        loadLimitsFromUserDefaults()
      }) {
        HealthSettingsView(isPresented: $showHealthSettings)
          .appInterfaceScale()
      }
      .sheet(isPresented: $showLimitsAlert) {
        CalorieLimitsEditView(
          softLimitText: $tempSoftLimit,
          hardLimitText: $tempHardLimit,
          hasHealthData: UserDefaults.standard.bool(forKey: "hasUserHealthData"),
          onSave: saveLimits,
          onUseHealth: resetToHealthBasedLimits
        )
        .appInterfaceScale()
      }
      .sheet(isPresented: $showUserProfile) {
        UserProfileView()
          .environmentObject(authService)
          .appInterfaceScale()
      }
      .onChange(of: showUserProfile) { _, isVisible in
        if !isVisible {
          let w = UserDefaults.standard.double(forKey: "userWeight")
          if w > 0 { personWeight = Float(w) }
          loadLimitsFromUserDefaults()
        }
      }
      .sheet(isPresented: $showHealthDisclaimer) {
        HealthDisclaimerView(
          todayHealthScore: dayFoodScore.map { ($0, healthScoreColor($0)) },
          dayISO: scoreDayISO(),
          newestDishTime: products.map(\.time).max() ?? 0,
          userEmail: authService.userEmail ?? "",
          scoreFailed: dayScoreFailed
        )
        .appInterfaceScale()
      }
      .onChange(of: currentViewingDateString) { _, _ in
        refreshDayFoodScore()
      }
      .onChange(of: isViewingCustomDate) { _, _ in
        refreshDayFoodScore()
      }
      .onChange(of: productTimes) { _, _ in
        refreshDayFoodScore()
      }
      .sheet(item: $fixFoodNameData) { data in
        FixFoodNameView(
          currentName: data.currentName,
          imageId: data.imageId,
          alternativeNames: data.alternativeNames,
          photo: data.photo,
          languageCode: languageService.currentCode,
          onSave: { newName in
            fixFoodNameData = nil
            submitManualFoodName(time: data.time, imageId: data.imageId, newName: newName)
          },
          onCancel: {
            fixFoodNameData = nil
          }
        )
        .appInterfaceScale()
      }
      // Statistics overlays Home when the user swipes left
      .sheet(isPresented: $showCalendarPicker) {
        CalendarDatePickerView(
          selectedDate: $selectedDate,
          isPresented: $showCalendarPicker,
          onDateSelected: { dateString in
            fetchCustomDateData(dateString: dateString)
          }
        )
        .appInterfaceScale()
      }
      .sheet(item: $fullScreenPhotoData) { photoData in
        FullScreenPhotoView(
          image: photoData.image,
          foodName: photoData.foodName,
          isPresented: .constant(true)
        ) {
          // Custom dismiss action
          fullScreenPhotoData = nil
        }
        .appInterfaceScale()
      }
      .sheet(isPresented: $showHealthPlan, onDismiss: {
        AppSettingsService.shared.markHealthOnboardingSeen(for: authService.userEmail)
        if AppSettingsService.shared.progressiveOnboardingLevel < 3 {
          AppSettingsService.shared.progressiveOnboardingLevel = 3
        }
      }) {
        HealthSettingsView(isPresented: $showHealthPlan)
          .appInterfaceScale()
      }
      .sheet(isPresented: $showProgressiveOnboarding) {
        ProgressiveOnboardingView(step: progressiveStep, isPresented: $showProgressiveOnboarding) {
          withAnimation {
            showProgressiveOnboarding = false
          }
          // Increment level based on step completed
          if progressiveStep == .notifications { AppSettingsService.shared.progressiveOnboardingLevel = 4 }
        }
        .environmentObject(languageService)
        .appInterfaceScale()
      }
      LoadingOverlay(isVisible: isLoadingData, message: loc("loading.food", "Loading food data..."))
      LoadingOverlay(
        isVisible: isLoadingFoodPhoto || nav.isLoadingFoodPhoto,
        message: loc("loading.photo", "Analyzing food photo..."))
    }
    .background {
      Color.clear
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
          nav.tryPresentAnonymousLoginPrompt()
        }) {
          OnboardingView(isPresented: $showOnboarding, mode: onboardingMode)
            .environmentObject(languageService)
            .interactiveDismissDisabled()
            .appInterfaceScale()
        }
    }
    .fullScreenCover(isPresented: $showMainAppTutorial) {
        MainAppTutorialView(isPresented: $showMainAppTutorial)
            .environmentObject(languageService)
            .appInterfaceScale()
    }
    .sheet(item: $activeTutorialStep, onDismiss: {
        let action = pendingTutorialAction
        pendingTutorialAction = .none
        guard action != .none else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          executeAction(action)
        }
    }) { step in
        MainAppTutorialView(isPresented: Binding(
            get: { activeTutorialStep != nil },
            set: { if !$0 { activeTutorialStep = nil } }
        ), specificStep: step)
            .environmentObject(languageService)
            .appInterfaceScale()
    }
    .id(languageService.currentCode)
  }

  /// Once text is large, weight and type shrink so calories left can stay full size.
  private var largeTextLayout: Bool { appSettings.largeTextLayout }

  /// Extra large is 160%. Icons shift sideways and sit closer so the date can scale on row 1.
  private var extraLargeText: Bool { appSettings.extraLargeText }

  /// 0 at 80%, 1 at 160%. Alcohol slides left and the score slides right as this grows.
  private var scaleTravel: CGFloat {
    let t = (appSettings.fontScale - 0.80) / 0.80
    return CGFloat(min(1, max(0, t)))
  }

  // Home grid tokens. All sizes are before the window scale, so they grow with the slider once.
  // Every control in the top two rows shares one height, one corner, and one gap.

  /// Height of header circles, the date chip, and the stat tiles.
  /// Shrinks a little at high scale so four circles and the date still fit one row.
  private var homeControlHeight: CGFloat { 44 - scaleTravel * 10 }
  private var homeCornerRadius: CGFloat { AppTheme.smallRadius }
  /// Vertical gap between home rows.
  private var homeRowGap: CGFloat { 8 }

  private var headerIconSide: CGFloat { homeControlHeight }
  /// Pairs pull together as text grows, so alcohol and the score slide toward the edges.
  private var headerIconSpacing: CGFloat { 24 - scaleTravel * 20 }
  private var headerSideGap: CGFloat { 4 }
  private var headerGlyph: CGFloat { headerIconSide * 18 / 44 }
  private var headerPhoto: CGFloat { headerIconSide * 30 / 44 }
  private var headerRing: CGFloat { headerIconSide - 8 }
  private var dateFontSize: CGFloat { 15 }

  private var dateFullText: String {
    isViewingCustomDate ? currentViewingDate : localizedDateFormatter.string(from: date)
  }

  private var dateShortText: String {
    let df = DateFormatter()
    df.locale = Locale(identifier: languageService.currentCode)
    df.setLocalizedDateFormatFromTemplate("dMMM")
    return df.string(from: isViewingCustomDate ? selectedDate : date)
  }

  /// Both icon groups get equal-width sides, so the date stays centered at any scale.
  private var topBarView: some View {
    HStack(spacing: headerSideGap) {
      HStack(spacing: headerIconSpacing) {
        profileButton
        alcoholButton
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      dateDisplayView
        .layoutPriority(1)
      HStack(spacing: headerIconSpacing) {
        #if DEBUG
        if useDevEnvironment {
          Text("DEV")
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red)
            .cornerRadius(4)
        }
        #endif
        healthInfoButton
        sportButton
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  private var guestLoginInvite: some View {
    Button {
      HapticsService.shared.select()
      nav.showInPlaceLogin = true
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "person.crop.circle.badge.plus")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(AppTheme.primaryButtonFill)
        VStack(alignment: .leading, spacing: 2) {
          Text(loc("login.scan_prompt_title", "Unlock All Features"))
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.textPrimary)
          Text(loc("login.prompt.confirm", "Login Now"))
            .font(.caption.weight(.medium))
            .foregroundColor(AppTheme.primaryButtonFill)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(AppTheme.textSecondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .appSurface(cornerRadius: homeCornerRadius)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityHint(loc("login.scan_prompt_message", "Please login to Google if you are ready or want to recover past food."))
  }

  private var profileButton: some View {
    return Button(action: {
      HapticsService.shared.lightImpact()
      showUserProfile = true
    }) {
      ZStack {
        ProfileImageView(
          localImage: authService.isAnonymous ? nil : profilePhotoStore.image,
          profilePictureURL: authService.isAnonymous ? nil : authService.userProfilePictureURL,
          size: headerPhoto,
          fallbackIconColor: authService.isAnonymous ? AppTheme.trialUsage : AppTheme.textPrimary,
          userName: authService.isAnonymous ? nil : authService.userName,
          userEmail: authService.isAnonymous ? nil : authService.userEmail
        )
        .clipShape(Circle())
      }
      .frame(width: headerIconSide, height: headerIconSide)
      .appCircleSurface()
      .contentShape(Circle())
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var alcoholButton: some View {
    Button(action: {
      checkTutorial(key: "hasSeenAlcoholTutorial", action: .alcohol)
    }) {
      ZStack {
        Image(systemName: themeService.icon(for: "wineglass"))
          .font(.system(size: headerGlyph, weight: .semibold))
          .foregroundColor(alcoholIconColor)
      }
      .frame(width: headerIconSide, height: headerIconSide)
      .appCircleSurface()
      .contentShape(Circle())
    }
    .buttonStyle(PressScaleButtonStyle())
    .sheet(isPresented: $showAlcoholCalendar) {
      AlcoholCalendarView(isPresented: $showAlcoholCalendar)
        .appInterfaceScale()
    }
  }

  /// Full date when it fits, "25 Oct" when it does not, then the short date scaled down.
  private var dateDisplayView: some View {
    ViewThatFits(in: .horizontal) {
      dateChip(dateFullText, shrink: false)
      dateChip(dateShortText, shrink: false)
      dateChip(dateShortText, shrink: true)
    }
  }

  private func dateChip(_ title: String, shrink: Bool) -> some View {
    HStack(spacing: 6) {
      VStack(spacing: 0) {
        Text(title)
          .font(.system(size: dateFontSize, weight: .bold, design: .rounded))
          .foregroundColor(isViewingCustomDate ? AppTheme.warning : AppTheme.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(shrink ? 0.75 : 1)

        if isViewingCustomDate {
          Text(loc("date.custom", "Custom Date"))
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.warning)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
      }
      .onTapGesture {
        // Prevent opening calendar while loading data
        guard !isLoadingData else { return }
        checkTutorial(key: "hasSeenCalendarTutorial", action: .calendar)
      }

      if isViewingCustomDate {
        Button(action: returnToToday) {
          Text(loc("date.today", "Today"))
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(Color.black.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppTheme.accent.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: homeCornerRadius / 2, style: .continuous))
        }
        .simultaneousGesture(TapGesture().onEnded { HapticsService.shared.select() })
      }
    }
    .padding(.horizontal, 10)
    .frame(height: homeControlHeight)
    .appSurface(cornerRadius: homeCornerRadius)
  }

  private var productTimes: [Int64] {
    products.map(\.time)
  }

  /// Local yyyy-MM-dd for the day on screen. Today does not use the UTC formatter.
  private func scoreDayISO() -> String {
    if isViewingCustomDate, !currentViewingDateString.isEmpty {
      let parts = currentViewingDateString.split(separator: "-")
      if parts.count == 3, parts[0].count == 2, parts[1].count == 2, parts[2].count == 4 {
        return "\(parts[2])-\(parts[1])-\(parts[0])"
      }
      return getISODateString(for: selectedDate)
    }
    return getISODateString(for: Date())
  }

  private func refreshDayFoodScore() {
    let day = scoreDayISO()
    let pollID = UUID()
    dayScorePollID = pollID
    dayScoreFailed = false
    dayScoreLoading = dayFoodScore == nil || dayFoodScoreDay != day
    if dayFoodScoreDay != day {
      dayFoodScore = nil
      dayFoodScoreTime = 0
      dayFoodScoreDay = day
      dayScoreLoading = true
    }
    let newest = products.map(\.time).max() ?? 0
    requestDayFoodScore(day: day, newest: newest, pollID: pollID, delays: [2, 4, 8])
  }

  private func requestDayFoodScore(day: String, newest: Int64, pollID: UUID, delays: [Double]) {
    GRPCService().getFoodScore(userName: authService.userEmail ?? "", day: day) { result in
      guard pollID == self.dayScorePollID, self.scoreDayISO() == day else { return }
      let newestNow = self.products.map(\.time).max() ?? newest
      var stored = self.dayFoodScoreTime
      if let result {
        if result.hasScore {
          self.dayFoodScore = result.score
          self.dayFoodScoreTime = result.dishTime
          stored = result.dishTime
        } else {
          self.dayFoodScore = nil
          self.dayFoodScoreTime = 0
          stored = 0
        }
      }
      let stillWaiting = newestNow > stored
      if stillWaiting, let delay = delays.first {
        self.dayScoreLoading = self.dayFoodScore == nil
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          guard pollID == self.dayScorePollID, self.scoreDayISO() == day else { return }
          let latest = self.products.map(\.time).max() ?? newestNow
          self.requestDayFoodScore(day: day, newest: latest, pollID: pollID, delays: Array(delays.dropFirst()))
        }
      } else {
        self.dayScoreLoading = false
        self.dayScoreFailed = self.dayFoodScore == nil && newestNow > 0
      }
    }
  }

  private func healthScoreColor(_ rating: Int) -> Color {
    switch rating {
    case 0..<40: return Color(red: 1.0, green: 0.0, blue: 0.0)
    case 40..<60: return Color(red: 1.0, green: 0.6, blue: 0.0)
    case 60..<80: return Color(red: 0.85, green: 0.7, blue: 0.0)
    case 80..<95: return Color(red: 0.5, green: 0.9, blue: 0.3)
    case 95...100: return Color(red: 0.0, green: 1.0, blue: 0.0)
    default: return Color.gray
    }
  }

  private var healthInfoButton: some View {
    Button(action: {
      checkTutorial(key: "hasSeenHealthScoreTutorial", action: .healthInfo)
    }) {
      ZStack {
        if let score = dayFoodScore {
          let color = healthScoreColor(score)
          ZStack {
            Circle()
              .stroke(color.opacity(0.25), lineWidth: 3)
            Circle()
              .trim(from: 0, to: CGFloat(score) / 100.0)
              .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
              .rotationEffect(.degrees(-90))
            Text("\(score)")
              .font(.system(size: headerRing * 14 / 36, weight: .bold, design: .rounded))
              .foregroundColor(color)
              .minimumScaleFactor(0.7)
          }
          .frame(width: headerRing, height: headerRing)
        } else if dayScoreLoading {
          ProgressView()
            .controlSize(.regular)
            .frame(width: headerRing, height: headerRing)
        } else {
          Text("-")
            .font(.system(size: headerGlyph, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
        }
      }
      .frame(width: headerIconSide, height: headerIconSide)
      .appCircleSurface()
      .contentShape(Circle())
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var sportButton: some View {
    Button(action: {
      checkTutorial(key: "hasSeenSportTutorial", action: .sport)
    }) {
      ZStack {
        Image(systemName: themeService.icon(for: "figure.run"))
          .font(.system(size: headerGlyph, weight: .semibold))
          .foregroundColor(sportIconColor)
      }
      .frame(width: headerIconSide, height: headerIconSide)
      .appCircleSurface()
      .contentShape(Circle())
    }
    .buttonStyle(PressScaleButtonStyle())
    .id("sport-\(todayActivityDate)-\(todaySportCalories)-\(uiRefreshTrigger)")
    .sheet(isPresented: $showActivitiesView) {
      ActivitiesView(dateISO: currentActivitiesDateISO())
        .appInterfaceScale()
    }
  }

  private var caloriesRemaining: Int {
    getAdjustedSoftLimit() - caloriesLeft
  }

  /// Shared row. Sizes are before the window scale, so text grows with the slider exactly once.
  private var statNumberSize: CGFloat { 22 }
  private var statLabelSize: CGFloat { 18 }
  private var statIconSize: CGFloat { 16 }
  private var statIconGap: CGFloat { 3 }
  private var statPadV: CGFloat { 4 }
  private var statPadH: CGFloat { largeTextLayout ? 3 : 6 }
  private var statRowHeight: CGFloat { homeControlHeight }
  private var statGap: CGFloat { largeTextLayout ? 5 : 12 }

  /// Rounded semibold glyphs are about 0.6 em wide.
  private func statTextWidth(_ text: String, size: CGFloat) -> CGFloat {
    CGFloat(text.count) * size * 0.6
  }

  /// Weight and Type share one width so calories always sits in the exact center.
  /// Each width comes from its text plus a thin pad, then the leftover is shared.
  /// If the row is short, all three shrink together and the text scales down to fit.
  private var statsButtonsView: some View {
    let weightNeed = statTextWidth(String(format: "%.1f", personWeight), size: statNumberSize)
      + statPadH * 2
    let caloriesNeed = statTextWidth("\(caloriesRemaining)", size: statNumberSize)
      + statIconSize + statIconGap + statPadH * 2
    let typeNeed = statTextWidth(loc("type_food.button", "Type"), size: statLabelSize)
      + statIconSize + statIconGap + statPadH * 2
    let sideNeed = max(weightNeed, typeNeed)
    return GeometryReader { proxy in
      let available = proxy.size.width - statGap * 2
      let needed = sideNeed * 2 + caloriesNeed
      let fits = needed <= available
      let extra = fits ? (available - needed) / 3 : 0
      let squeeze = fits ? 1 : available / needed
      let side = sideNeed * squeeze + extra
      HStack(spacing: statGap) {
        weightButton.frame(width: side, height: statRowHeight)
        caloriesButton.frame(width: caloriesNeed * squeeze + extra, height: statRowHeight)
        typeButton.frame(width: side, height: statRowHeight)
      }
      .frame(width: proxy.size.width)
    }
    .frame(height: statRowHeight)
    .frame(maxWidth: .infinity)
  }

  private var weightButton: some View {
    Button(action: {
      checkTutorial(key: "hasSeenWeightTutorial", action: .weight)
    }) {
      ZStack {
        if isLoadingWeightPhoto {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.textPrimary))
        } else {
          Text(String(format: "%.1f", personWeight))
            .font(.system(size: statNumberSize, weight: .semibold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
        }
      }
      .padding(.horizontal, statPadH)
      .padding(.vertical, statPadV)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .appSurface(cornerRadius: homeCornerRadius)
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $showWeightActionSheet, onDismiss: {
      guard openWeightCameraAfterPrompt else { return }
      openWeightCameraAfterPrompt = false
      DispatchQueue.main.async { showCamera = true }
    }) {
      WeightPromptSheet(
        weightText: $manualWeightInput,
        onPhoto: { openWeightCameraAfterPrompt = true },
        onSubmit: submitManualWeight
      )
    }
    .sheet(isPresented: $showCamera) {
      WeightCameraView(
        onPhotoSuccess: {
          // Clear both caches since weight was updated
          StatisticsService.shared.invalidateDay()
          ProductStorageService.shared.clearCache()
          ProductStorageService.shared.clearCache()

          // Set flag to check for motivation message after data refresh
          pendingWeightPhotoCheck = true
          
          // Always return to today after weight photo
          returnToToday()
          isLoadingWeightPhoto = false
        },
        onPhotoFailure: {
          isLoadingWeightPhoto = false
        },
        onPhotoStarted: {
          isLoadingWeightPhoto = true
        }
      )
      .appInterfaceScale()
    }
  }

  private var caloriesButton: some View {
    let remaining = caloriesRemaining
    let calorieColor: Color =
      remaining <= -1
      ? AppTheme.danger
      : getColor(for: caloriesLeft, adjustedSoftLimit: getAdjustedSoftLimit())
    return Button(action: {
      checkTutorial(key: "hasSeenCaloriesTutorial", action: .calories)
    }) {
      calorieLabel(remaining)
        .foregroundColor(calorieColor)
        .padding(.horizontal, statPadH)
        .padding(.vertical, statPadV)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(cornerRadius: homeCornerRadius)
    }
    .buttonStyle(.plain)
    .id("calories-\(todaySportCalories)-\(todaySportCaloriesDate)-\(uiRefreshTrigger)")
  }

  /// Flame and number stay on one line, centered in the shared row.
  private func calorieLabel(_ remaining: Int) -> some View {
    HStack(spacing: statIconGap) {
      Spacer(minLength: 0)
      Image(systemName: themeService.icon(for: "flame.fill"))
        .font(.system(size: statIconSize))
      Text("\(remaining)")
        .font(.system(size: statNumberSize, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.65)
      Spacer(minLength: 0)
    }
  }

  private var typeButton: some View {
    Button(action: {
      checkTutorial(key: "hasSeenTypeGuide", action: .typeFood)
    }) {
      HStack(spacing: statIconGap) {
        Spacer(minLength: 0)
        Image(systemName: themeService.icon(for: "square.and.pencil"))
          .font(.system(size: statIconSize, weight: .semibold))
        Text(loc("type_food.button", "Type"))
          .font(.system(size: statLabelSize, weight: .semibold, design: .rounded))
          .lineLimit(1)
          .minimumScaleFactor(0.65)
        Spacer(minLength: 0)
      }
      .foregroundColor(AppTheme.textPrimary)
      .padding(.horizontal, statPadH)
      .padding(.vertical, statPadV)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .appSurface(cornerRadius: homeCornerRadius)
    }
    .buttonStyle(.plain)
  }

  /// Daily macro targets (g) from calorie target: protein 20%, fat 30%, carbs 50%, sugar max 40g.
  /// Custom goals from settings override the default split when present.
  private func macroTargetsFromDailyKcal(_ kcal: Int) -> (protein: Double, fat: Double, carbs: Double, sugarMax: Double) {
    let defaultTargets: (protein: Double, fat: Double, carbs: Double, sugarMax: Double) = {
      guard kcal > 0 else { return (80, 53, 200, 40) }
      let k = Double(kcal)
      return ((k * 0.20) / 4.0, (k * 0.30) / 9.0, (k * 0.50) / 4.0, 40.0)
    }()
    guard let saved = CalorieLimitsStorageService.shared.load() else { return defaultTargets }
    return (
      saved.customProteinGoal ?? defaultTargets.protein,
      saved.customFatGoal ?? defaultTargets.fat,
      saved.customCarbsGoal ?? defaultTargets.carbs,
      defaultTargets.sugarMax
    )
  }

  private var hasCustomMacroGoals: Bool {
    guard let saved = CalorieLimitsStorageService.shared.load() else { return false }
    return saved.customProteinGoal != nil || saved.customFatGoal != nil
      || saved.customCarbsGoal != nil
  }

  private func saveMacroGoals(protein: Double, fat: Double, carbs: Double) {
    var limits =
      CalorieLimitsStorageService.shared.load()
      ?? .init(softLimit: softLimit, hardLimit: hardLimit, hasManualCalorieLimits: false)
    limits.customProteinGoal = protein
    limits.customFatGoal = fat
    limits.customCarbsGoal = carbs
    CalorieLimitsStorageService.shared.save(limits)
    uiRefreshTrigger.toggle()

    GRPCService().updateMacroGoals(
      proteinTargetGrams: protein, fatTargetGrams: fat, carbsTargetGrams: carbs
    ) { _ in }
  }

  private func resetMacroGoalsToRecommended() {
    guard var limits = CalorieLimitsStorageService.shared.load() else { return }
    limits.customProteinGoal = nil
    limits.customFatGoal = nil
    limits.customCarbsGoal = nil
    CalorieLimitsStorageService.shared.save(limits, preserveCustomMacros: false)
    uiRefreshTrigger.toggle()
  }

  private var macrosLineView: some View {
    let targets = macroTargetsFromDailyKcal(softLimit)
    func fmt(_ v: Double) -> String { String(format: "%.1f", v) }
    func pct(_ value: Double, _ target: Double) -> String {
      guard target > 0 else { return "–" }
      return "\(Int((value / target * 100.0).rounded()))%"
    }
    // Green zones (ranges) for macros
    let proteinLower = targets.protein * 0.8
    let fatLower = targets.fat * 0.8
    let fatUpper = targets.fat * 1.2
    let carbLower = targets.carbs * 0.8
    let sugarLower = 40.0
    let sugarUpper = 50.0
    let grams = loc("units.g", "g")
    let proLabel = loc("macro.pro", "PRO")
    let fatLabel = loc("macro.fat", "FAT")
    let carLabel = loc("macro.car", "CAR")
    let sugLabel = loc("macro.sug", "SUG")
    // Colors with ranges:
    // - Protein: < 80% target = yellow, >= 80% = green (no red for excess)
    let proColor: Color =
      proteins >= proteinLower ? AppTheme.success : AppTheme.warning
    // - Fat: < 80% target = yellow, 80–120% = green, > 120% = red
    let fatColor: Color =
      fats < fatLower ? AppTheme.warning
      : (fats <= fatUpper ? AppTheme.success : AppTheme.danger)
    // - Carbs: < 80% target = yellow, >= 80% = green
    let carColor: Color =
      carbs >= carbLower ? AppTheme.success : AppTheme.warning
    // - Sugar: < 40g = green, 40–49.9g = orange, >= 50g = red
    let sugColor: Color =
      sugar >= sugarUpper ? AppTheme.danger
      : (sugar >= sugarLower ? AppTheme.warning : AppTheme.success)

    func column(_ percent: String, _ label: String, _ amount: String, _ color: Color) -> some View {
      VStack(spacing: 1) {
        if largeTextLayout {
          Text(label + " " + percent)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
          Text(amount)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
        } else {
          Text(percent)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(color.opacity(0.9))
          Text(label + " " + amount)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
      }
    }

    return Button(action: {
      HapticsService.shared.select()
      showMacroTargets = true
    }) {
      HStack(alignment: .bottom, spacing: 6) {
        Spacer(minLength: 0)
        column(pct(proteins, targets.protein), proLabel, fmt(proteins) + grams, proColor)
        Text("•").foregroundColor(AppTheme.textSecondary)
        column(pct(fats, targets.fat), fatLabel, fmt(fats) + grams, fatColor)
        Text("•").foregroundColor(AppTheme.textSecondary)
        column(pct(carbs, targets.carbs), carLabel, fmt(carbs) + grams, carColor)
        Text("•").foregroundColor(AppTheme.textSecondary)
        column(pct(sugar, targets.sugarMax), sugLabel, fmt(sugar) + grams, sugColor)
        Spacer(minLength: 0)
      }
      .font(.system(size: 16, weight: .semibold, design: .rounded))
      .frame(maxWidth: .infinity)
      .padding(.horizontal, largeTextLayout ? 6 : 12)
      .padding(.vertical, 6)
      .appSurface(cornerRadius: homeCornerRadius)
    }
    .id(
      "macros-\(Int(targets.protein))-\(Int(targets.fat))-\(Int(targets.carbs))-\(uiRefreshTrigger)"
    )
    .buttonStyle(PlainButtonStyle())
    .sheet(isPresented: $showMacroTargets) {
      MacroGoalsEditView(
        initialTargets: macroTargetsFromDailyKcal(softLimit),
        hasCustomGoals: hasCustomMacroGoals,
        onSave: { protein, fat, carbs in
          saveMacroGoals(protein: protein, fat: fat, carbs: carbs)
          showMacroTargets = false
        },
        onResetToRecommended: {
          resetMacroGoalsToRecommended()
          showMacroTargets = false
        },
        onCancel: {
          showMacroTargets = false
        }
      )
      .appInterfaceScale()
    }
  }

  private var refreshAction: () -> Void {
    {
      // User-initiated refresh should force a network call and return to today
      guard !isFetchingData else { return }

      // Clear cache to force fresh data
      ProductStorageService.shared.clearCache()

      // Always return to today when user pulls to refresh
      returnToToday()
    }
  }

  // MARK: - Tutorial Checker
  
  private func checkTutorial(key: String, action: PendingTutorialAction) {
      if KeychainHelper.shared.getBool(key) {
          executeAction(action)
      } else {
          HapticsService.shared.select()
          pendingTutorialAction = action
          if let step = MainAppTutorialView.steps.first(where: { $0.key == key }) {
              activeTutorialStep = step
          } else {
              executeAction(action)
              pendingTutorialAction = .none
          }
      }
  }

  private func executeAction(_ action: PendingTutorialAction) {
      switch action {
      case .alcohol:
          HapticsService.shared.select()
          showAlcoholCalendar = true
      case .calendar:
          HapticsService.shared.select()
          selectedDate = Date()
          showCalendarPicker = true
      case .healthInfo:
          HapticsService.shared.select()
          showHealthDisclaimer = true
      case .sport:
          HapticsService.shared.select()
          showActivitiesView = true
      case .weight:
          HapticsService.shared.select()
          showWeightActionSheet = true
      case .calories:
          HapticsService.shared.select()
          showCaloriesLeftInfo = true
      case .typeFood:
          HapticsService.shared.select()
          syncMealNav()
          nav.openTypeFood()
      case .none:
          break
      }
  }

  // MARK: - Data Fetching Methods

  private func syncMealNav() {
    nav.mealsToday = products.count
    nav.mealRemaining = mealPlannerRemaining
    nav.selectedDate = selectedDate
    nav.isViewingCustomDate = isViewingCustomDate
  }

  private func handlePhotoLogged() {
    if AppSettingsService.shared.shouldShowHealthOnboarding(for: authService.userEmail) {
      showHealthPlan = true
    } else if AppSettingsService.shared.shouldShowSocialOnboarding(for: authService.userEmail) {
      onboardingMode = .social
      showOnboarding = true
    }
    fetchDataAfterFoodPhoto()
  }

  func fetchDataWithLoading() {
    // Prevent multiple simultaneous data fetches
    guard !isFetchingData else { return }

    // Always show loading on start
    isLoadingData = true
    isFetchingData = true

    // Try to load cached data first for instant display
    let (cachedProducts, cachedCalories, cachedWeight) = ProductStorageService.shared.loadProducts()
    if !cachedProducts.isEmpty || cachedCalories > 0 || cachedWeight > 0 {
      products = FoodExtrasStore.shared.apply(to: cachedProducts)
      caloriesLeft = cachedCalories + FoodExtrasStore.shared.totalExtrasCalories(for: products)
      personWeight = cachedWeight
      if cachedWeight > 0 {
        UserDefaults.standard.set(Double(cachedWeight), forKey: "userWeight")
      }
      refreshMacrosForCurrentView()
    }

    // Check if we're viewing a custom date - if so, fetch that specific date
    if isViewingCustomDate && !currentViewingDateString.isEmpty {
      ProductStorageService.shared.fetchAndProcessCustomDateProducts(date: currentViewingDateString) { 
        (fetchedProducts, calories, weight, success) in
        DispatchQueue.main.async {
          self.isLoadingData = false
          self.isFetchingData = false
          guard success else { return }

          let previousWeight = self.personWeight
          FoodExtrasStore.shared.clearSugar(for: fetchedProducts.map(\.time))
          self.products = FoodExtrasStore.shared.apply(to: fetchedProducts)
          FoodPhotoService.shared.prefetchPhotos(for: fetchedProducts)
          self.caloriesLeft = calories + FoodExtrasStore.shared.totalExtrasCalories(for: self.products)
          self.personWeight = weight
          // Custom date: do not overwrite userWeight (current weight is for today)

          // Recalculate calories if weight changed and user has health data
          let userDefaults = UserDefaults.standard
          if userDefaults.bool(forKey: "hasUserHealthData"), abs(previousWeight - weight) > 0.1 {
            self.recalculateCalorieLimitsFromHealthData()
          }
          self.refreshMacrosForCurrentView()
        }
      }
      return
    }

    // Fetch fresh data from network (for today)
    // FORCE refresh so we actually use the network and show the loading state
    ProductStorageService.shared.fetchAndProcessProducts(forceRefresh: true) { (fetchedProducts, calories, weight, success) in
      DispatchQueue.main.async {
        self.isLoadingData = false
        self.isFetchingData = false
        guard success else { return }

        let previousWeight = self.personWeight
        FoodExtrasStore.shared.clearSugar(for: fetchedProducts.map(\.time))
        self.products = FoodExtrasStore.shared.apply(to: fetchedProducts)
        FoodPhotoService.shared.prefetchPhotos(for: fetchedProducts)
        self.caloriesLeft = calories + FoodExtrasStore.shared.totalExtrasCalories(for: self.products)
        self.personWeight = weight
        if weight > 0 {
          UserDefaults.standard.set(Double(weight), forKey: "userWeight")
        }

        if self.pendingWeightPhotoCheck && weight > 0 {
          self.pendingWeightPhotoCheck = false

          if !self.checkWeightGoalReached(newWeight: weight) {
            if let weightLossGrams = WeightMotivationService.shared.checkAndUpdateForMotivation(newWeight: weight) {
              let motivation = WeightMotivationService.shared.getMotivationalMessage(
                weightLossGrams: weightLossGrams,
                languageCode: self.languageService.currentCode
              )
              AlertHelper.showAlert(
                title: motivation.title,
                message: motivation.message,
                haptic: .success)
            } else {
              AlertHelper.showAlert(
                title: loc("weight.recorded.title", "Weight Recorded"),
                message: loc("weight.recorded.msg", "Your weight has been successfully recorded."),
                haptic: .success)
            }
          }
        }

        let userDefaults = UserDefaults.standard
        if userDefaults.bool(forKey: "hasUserHealthData"), abs(previousWeight - weight) > 0.1 {
          self.recalculateCalorieLimitsFromHealthData()
        }
        self.refreshMacrosForCurrentView()
      }
    }
  }

  @discardableResult
  private func checkWeightGoalReached(newWeight: Float) -> Bool {
    let userDefaults = UserDefaults.standard
    let target = userDefaults.double(forKey: "userTargetWeight")
    let mode = userDefaults.string(forKey: "userGoalMode") ?? "maintain"
    guard target > 0 else { return false }
    guard userDefaults.bool(forKey: "hasUserHealthData") else { return false }
    guard mode == "lose" || mode == "gain" else { return false }

    let w = Double(newWeight)
    guard w >= 20 else { return false }

    let tol = 0.2
    guard abs(w - target) <= tol else { return false }

    let celebratedTarget = userDefaults.double(forKey: "goalCelebratedTargetKg")
    if celebratedTarget > 0, abs(celebratedTarget - target) < 0.05 { return false }

    let today = getCurrentUTCDateString()

    func offerMaintenance() {
      userDefaults.set("maintain", forKey: "userGoalMode")
      userDefaults.set(0, forKey: "userGoalMonths")
      userDefaults.set(today, forKey: "goalMilestoneLastShownDate")
      self.recalculateCalorieLimitsFromHealthData()
      let calories = userDefaults.integer(forKey: "userRecommendedCalories")
      GRPCService().updateGoal(
        targetWeight: target,
        goalMode: "maintain",
        goalMonths: 0,
        recommendedCalories: calories
      ) { _ in }
      AlertHelper.showAlert(
        title: loc("goal.maintain.enabled.title", "Maintenance enabled"),
        message: loc("goal.maintain.enabled.msg", "Great! We'll help you maintain your weight with ongoing tracking."),
        haptic: .success
      )
    }

    userDefaults.set(today, forKey: "goalMilestoneLastShownDate")
    userDefaults.set(target, forKey: "goalCelebratedTargetKg")
    AlertHelper.showCelebration(
      title: loc("goal.reached.title", "You did it!"),
      message: loc("goal.reached.msg", "Congratulations — you reached your target weight!"),
      primaryTitle: loc("goal.maintain.cta", "Switch to maintenance"),
      primaryAction: offerMaintenance,
      secondaryTitle: loc("common.close", "Close"),
      secondaryAction: nil
    )
    return true
  }

  func checkProgressiveOnboarding() {
    guard !showOnboarding, !showHealthPlan else { return }
    let count = AppSettingsService.shared.foodSharedCount
    let level = AppSettingsService.shared.progressiveOnboardingLevel
    let hasHealthData = UserDefaults.standard.bool(forKey: "hasUserHealthData")

    if !hasHealthData && count >= 1 && level < 3 {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        guard !self.showOnboarding else { return }
        self.showHealthPlan = true
      }
      return
    }

    if count >= 5 && level < 4 {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        guard !self.showOnboarding, !self.showHealthPlan else { return }
        self.progressiveStep = .notifications
        self.showProgressiveOnboarding = true
      }
    }
  }

  func fetchDataAfterFoodPhoto() {
    HapticsService.shared.success()
    AppSettingsService.shared.foodSharedCount += 1
    
    // Clear today's statistics cache since new food was added
    StatisticsService.shared.invalidateDay(
      currentViewingDateString.isEmpty ? nil : currentViewingDateString)

    // Note: ProductStorageService cache is already updated by the fetchAndProcessProducts call
    // that handles the image mapping, so no need to clear it here

    // If viewing a custom/past date, stay on that date and refresh it
    // If on today, just refresh today
    if isViewingCustomDate {
      // Stay on the selected past date and refresh it
      ProductStorageService.shared.clearCache() // Clear cache to force fresh data
      fetchDataWithLoading() // This will fetch data for the currently selected date
      
      // After the camera closes, ask whether to stay on the past day or go back to Today.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        guard self.isViewingCustomDate else { return }
        AlertHelper.showConfirmation(
          title: loc("backdating.return_today.title", "Food Logged"),
          message: loc("backdating.return_today.msg", "Your food was recorded for the selected past date. Would you like to return to Today?"),
          actions: [
            ScaledNoticeAction(title: loc("backdating.return_today.return", "Return to Today")) {
              self.returnToToday()
            },
            ScaledNoticeAction(title: loc("backdating.return_today.stay", "Stay Here"), kind: .secondary),
          ]
        )
      }
    } else {
      // On today - just refresh
      returnToToday()
    }

    DispatchQueue.main.async {
      self.isLoadingFoodPhoto = false
      self.checkProgressiveOnboarding()
    }
  }

  func tryAgainProduct(time: Int64, imageId: String) {
    // "Try manually" – user can fix the dish name, optionally from LLM suggestions.
    guard authService.userEmail != nil else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc(
          "portion.modify.need_login", "Unable to update. Please sign in again."))
      return
    }

    guard let product = products.first(where: { $0.time == time }) else {
      return
    }

    fixFoodNameData = FixFoodNameData(
      time: time,
      imageId: imageId,
      currentName: product.name,
      alternativeNames: product.alternativeNames,
      photo: imageId.isEmpty || imageId.hasPrefix(FixFoodNameView.stockPhotoPrefix)
        ? nil : product.image
    )
  }

  private func submitManualFoodName(time: Int64, imageId: String, newName: String) {
    guard let userEmail = authService.userEmail else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc(
          "portion.modify.need_login", "Unable to update. Please sign in again."))
      return
    }

    self.deletingProductTime = time
    let handleResult: (Bool) -> Void = { success in
      DispatchQueue.main.async {
        self.deletingProductTime = nil
        if success {
          ProductStorageService.shared.removeHealthLevel(time: time)
          StatisticsService.shared.invalidateDay(
            currentViewingDateString.isEmpty ? nil : currentViewingDateString)
          ProductStorageService.shared.clearCache()
          AlertHelper.showAlert(
            title: loc("manual_food.success.title", "Updated"),
            message: String(
              format: loc(
                "manual_food.success.msg", "Updated '%@'."), newName),
            haptic: .success
          ) {
            self.returnToToday()
          }
        } else {
          HapticsService.shared.error()
          AlertHelper.showAlert(
            title: loc("common.error", "Error"),
            message: loc(
              "manual_food.error",
              "Failed to update. Please try again.")
          )
        }
      }
    }
    if imageId.isEmpty {
      GRPCService().renameFood(
        time: time, userEmail: userEmail, newName: newName, completion: handleResult)
    } else {
      GRPCService().modifyFoodRecord(
        time: time,
        userEmail: userEmail,
        percentage: 100,
        isTryManually: true,
        imageId: imageId,
        manualFoodName: newName,
        completion: handleResult
      )
    }
  }
  
  func addSugarToProduct(time: Int64, foodName: String) {
    guard let userEmail = authService.userEmail else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc("portion.modify.need_login", "Unable to add sugar. Please sign in again."))
      return
    }
    
    self.deletingProductTime = time
    // Add 1 teaspoon of sugar (1 tsp = ~5g, ~20 calories)
    GRPCService().modifyFoodRecord(
      time: time,
      userEmail: userEmail,
      percentage: 100,
      addedSugarTsp: 1.0
    ) { success in
      DispatchQueue.main.async {
        self.deletingProductTime = nil
        if success {
          // Optimistically update UI + local store so sugar icon and calories/grams update immediately
          FoodExtrasStore.shared.addSugar(time: time, tsp: 1)
          let updated = FoodExtrasStore.shared.apply(to: self.products)
          self.products = updated
          self.caloriesLeft += 20

          // Clear caches and refresh
          StatisticsService.shared.invalidateDay(
            currentViewingDateString.isEmpty ? nil : currentViewingDateString)
          ProductStorageService.shared.clearCache()
          
          AlertHelper.showAlert(
            title: loc("portion.sugar_added.title", "Sugar Added"),
            message: String(
              format: loc("portion.sugar_added.msg", "Added 1 tsp sugar (+20 cal) to '%@'"),
              foodName),
            haptic: .success
          ) {
            self.returnToToday()
          }
        } else {
          HapticsService.shared.error()
        }
      }
    }
  }

  /// Local-only extras (lemon/honey/soy/wasabi/pepper) – updates dish calories/grams and top calories immediately.
  func addExtraToProduct(time: Int64, foodName: String, extraKey: String) {
    FoodExtrasStore.shared.addExtra(time: time, extraKey: extraKey)

    // Apply to UI model
    let updatedExtras = FoodExtrasStore.shared.extras(for: time)
    self.products = self.products.map { item in
      guard item.time == time else { return item }
      return Product(
        time: item.time,
        name: item.name,
        calories: item.calories,
        weight: item.weight,
        ingredients: item.ingredients,
        healthRating: item.healthRating,
        imageId: item.imageId,
        addedSugarTsp: item.addedSugarTsp,
        extras: updatedExtras,
        proteins: item.proteins,
        fats: item.fats,
        carbohydrates: item.carbohydrates,
        sugar: item.sugar,
        alternativeNames: item.alternativeNames
      )
    }

    // Adjust top calories (calories consumed) by this extra's calories
    if let def = FoodExtrasStore.definitions[extraKey] {
      self.caloriesLeft += def.calories
    }

    // Persist updated view state into cache for fast reload UX
    ProductStorageService.shared.saveProducts(self.products, calories: self.caloriesLeft, weight: self.personWeight)
  }

  func modifyProductPortion(time: Int64, foodName: String, percentage: Int32, requestedGrams: Double? = nil) {
    guard let userEmail = authService.userEmail else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc(
          "portion.modify.need_login", "Unable to modify food portion. Please sign in again."))
      return
    }

    self.deletingProductTime = time
    GRPCService().modifyFoodRecord(time: time, userEmail: userEmail, percentage: percentage) {
      success in
      DispatchQueue.main.async {
        self.deletingProductTime = nil
        if success {
          FoodExtrasStore.shared.scaleSugar(time: time, percentage: Int(percentage))
          // Clear both caches since food was modified
          StatisticsService.shared.invalidateDay(
            currentViewingDateString.isEmpty ? nil : currentViewingDateString)
          ProductStorageService.shared.clearCache()

          // Show success message
          let alertMsg: String
          if let grams = requestedGrams {
             alertMsg = String(
               format: loc("portion.updated.msg.grams", "Successfully updated '%@' to %g g."),
               foodName, grams)
          } else {
             alertMsg = String(
               format: loc("portion.updated.msg", "Successfully updated '%@' to %d%% portion."),
               foodName, percentage)
          }

          AlertHelper.showAlert(
            title: loc("portion.updated.title", "Portion Updated"),
            message: alertMsg,
          haptic: .success
          ) {
            // Always return to today after modifying food portion
            self.returnToToday()
          }
        } else {
          // Show error message
          AlertHelper.showAlert(
            title: loc("common.update_failed", "Update Failed"),
            message: loc(
            "portion.update_failed.msg", "Failed to update the food portion. Please try again."),
          haptic: .error
          )
        }
      }
    }
  }

  func deleteProductWithLoading(time: Int64) {
    deletingProductTime = time
    GRPCService().deleteFood(time: Int64(time)) { success in
      DispatchQueue.main.async {
        if success {
          // Clear both caches since food was deleted
          StatisticsService.shared.invalidateDay(
            currentViewingDateString.isEmpty ? nil : currentViewingDateString)
          ProductStorageService.shared.clearCache()

          // Delete the local image as well
          _ = ImageStorageService.shared.deleteImage(forTime: time)

          self.deletingProductTime = nil
          AlertHelper.showAlert(
            title: loc("common.removed", "Removed"),
          message: loc("food.removed.msg", "Food item was removed."),
          haptic: .success
          ) {
            self.returnToToday()
          }
        } else {
          // Failed to delete product
        HapticsService.shared.error()
          self.deletingProductTime = nil
        }
      }
    }
  }

  func fetchCustomDateData(dateString: String) {
    // Dismiss calendar immediately when date is selected
    showCalendarPicker = false

    isLoadingData = true
    isViewingCustomDate = true
    currentViewingDateString = dateString

    // Convert dateString to display format
    let inputFormatter = DateFormatter()
    inputFormatter.locale = Locale(identifier: "en_US_POSIX")
    inputFormatter.calendar = Calendar(identifier: .gregorian)
    inputFormatter.dateFormat = "dd-MM-yyyy"
    let displayFormatter = DateFormatter()
    displayFormatter.locale = Locale(identifier: languageService.currentCode)
    displayFormatter.dateStyle = .medium
    displayFormatter.timeStyle = .none

    if let parsedDate = inputFormatter.date(from: dateString) {
      currentViewingDate = displayFormatter.string(from: parsedDate)
      self.selectedDate = parsedDate
    } else {
      currentViewingDate = dateString
    }
    syncMealNav()

    ProductStorageService.shared.fetchAndProcessCustomDateProducts(date: dateString) {
      fetchedProducts, calories, weight, success in
      DispatchQueue.main.async {
        self.isLoadingData = false
        guard success else { return }

        let previousWeight = self.personWeight
        self.products = fetchedProducts
        self.caloriesLeft = calories
        self.personWeight = weight

        // Recalculate calories if weight changed and user has health data
        let userDefaults = UserDefaults.standard
        if userDefaults.bool(forKey: "hasUserHealthData"), abs(previousWeight - weight) > 0.1 {
          self.recalculateCalorieLimitsFromHealthData()
        }
        self.refreshMacrosForCurrentView()
      }
    }
  }

  func returnToToday() {
    isViewingCustomDate = false
    currentViewingDateString = ""
    
    // Set the viewing date to "Today" or formatted current date
    let todayFormatter = DateFormatter()
    todayFormatter.locale = Locale(identifier: languageService.currentCode)
    todayFormatter.dateStyle = .medium
    todayFormatter.timeStyle = .none
    currentViewingDate = todayFormatter.string(from: Date())
    
    fetchDataWithLoading()
    refreshMacrosForCurrentView()
  }

  func showFullScreenPhoto(image: UIImage?, foodName: String) {
    fullScreenPhotoData = FullScreenPhotoData(image: image, foodName: foodName)
  }

  @discardableResult
  func submitManualWeight() -> Bool {
    // Normalize decimal separator (replace comma with dot for proper Float parsing)
    let normalizedInput = manualWeightInput.replacingOccurrences(of: ",", with: ".")

    guard let weight = Float(normalizedInput), weight > 0 else {
      AlertHelper.showAlert(
        title: loc("weight.invalid.title", "Invalid Weight"),
        message: loc("weight.invalid.msg", "Please enter a valid weight in kilograms."),
        haptic: .error)
      return false
    }

    guard let userEmail = authService.userEmail else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc("weight.need_login", "Unable to submit weight. Please sign in again."),
        haptic: .error)
      return false
    }

    isLoadingWeightPhoto = true

    GRPCService().sendManualWeight(weight: weight, userEmail: userEmail) { success in
      DispatchQueue.main.async {
        self.isLoadingWeightPhoto = false

        if success {
          self.personWeight = weight
          UserDefaults.standard.set(Double(weight), forKey: "userWeight")
          // Clear both caches since weight was updated
          StatisticsService.shared.invalidateDay()
          ProductStorageService.shared.clearCache()

          self.returnToToday()

          if !self.checkWeightGoalReached(newWeight: weight) {
            if let weightLossGrams = WeightMotivationService.shared.checkAndUpdateForMotivation(newWeight: weight) {
              let motivation = WeightMotivationService.shared.getMotivationalMessage(
                weightLossGrams: weightLossGrams,
                languageCode: self.languageService.currentCode
              )
              AlertHelper.showAlert(
                title: motivation.title,
                message: motivation.message,
                haptic: .success)
            } else {
              AlertHelper.showAlert(
                title: loc("weight.recorded.title", "Weight Recorded"),
                message: loc("weight.recorded.msg", "Your weight has been successfully recorded."),
                haptic: .success)
            }
          }
        } else {
          AlertHelper.showAlert(
            title: loc("common.error", "Error"),
            message: loc(
              "weight.record_failed.msg", "Failed to record your weight. Please try again."),
            haptic: .error)
        }
      }
    }
    return true
  }

  func setupActivityCaloriesObserver() {
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("ActivityCaloriesAdded"),
      object: nil,
      queue: .main
    ) { notification in
      if let userInfo = notification.userInfo,
         let calories = userInfo["calories"] as? Int {
        let todayString = getCurrentUTCDateString()
        
        // If it's a new day, reset; otherwise add to existing
        if self.todaySportCaloriesDate == todayString {
          self.todaySportCalories += calories  // ADD to today's total
        } else {
          self.todaySportCalories = calories   // New day, set fresh
        }
        
        self.todaySportCaloriesDate = todayString
        self.todayActivityDate = todayString
      }
    }
    
    // When activity is added for a date (today or past), refresh limit if we're viewing that date
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("ActivityCaloriesAddedForDate"),
      object: nil,
      queue: .main
    ) { notification in
      guard let dateISO = notification.userInfo?["dateISO"] as? String else { return }
      if dateISO == self.currentActivitiesDateISO() {
        self.uiRefreshTrigger.toggle()
      }
    }
    
    // Observer for chess games
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("ChessGameRecorded"),
      object: nil,
      queue: .main
    ) { _ in
      // Ensure todayActivityDate is set to today
      let todayString = getCurrentUTCDateString()
      self.todayActivityDate = todayString
      
      // Force UI refresh after chess game
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.uiRefreshTrigger.toggle()
      }
    }
  }

  // MARK: - Helper Methods

  private func getColor(for value: Int, adjustedSoftLimit: Int) -> Color {
    if value < adjustedSoftLimit {
      return Color(red: 0.2, green: 0.7, blue: 0.3)  // Softer, more pleasant green
    } else if value < hardLimit {
      return Color(red: 0.9, green: 0.6, blue: 0.1)  // Warm amber instead of bright yellow
    } else {
      return Color(red: 0.8, green: 0.4, blue: 0.2)  // Warm orange-red instead of harsh red
    }
  }

  private func loadLimitsFromUserDefaults() {
    // Prefer file-backed storage for persistence across sessions independent of memory pressure
    if let stored = CalorieLimitsStorageService.shared.load() {
      softLimit = stored.softLimit > 0 ? stored.softLimit : softLimit
      hardLimit = stored.hardLimit > 0 ? stored.hardLimit : hardLimit
      // Mirror the manual flag into UserDefaults for backward compatibility with existing checks
      UserDefaults.standard.set(stored.hasManualCalorieLimits, forKey: "hasManualCalorieLimits")
    } else {
      // Fallback to existing UserDefaults values if present (legacy)
      let userDefaults = UserDefaults.standard
      let savedSoftLimit = userDefaults.integer(forKey: "softLimit")
      let savedHardLimit = userDefaults.integer(forKey: "hardLimit")
      if savedSoftLimit > 0 { softLimit = savedSoftLimit }
      if savedHardLimit > 0 { hardLimit = savedHardLimit }
    }

    // If health data exists and user has NOT manually overridden, recalc health-based
    let hasHealth = UserDefaults.standard.bool(forKey: "hasUserHealthData")
    let hasManual = CalorieLimitsStorageService.shared.load()?.hasManualCalorieLimits
      ?? UserDefaults.standard.bool(forKey: "hasManualCalorieLimits")
    if hasHealth && !hasManual {
      recalculateCalorieLimitsFromHealthData()
    }
  }

  @discardableResult
  private func saveLimits() -> Bool {
    guard let newSoftLimit = Int(tempSoftLimit),
      let newHardLimit = Int(tempHardLimit),
      newSoftLimit > 0,
      newHardLimit > 0,
      newSoftLimit <= newHardLimit
    else {
      return false
    }

    softLimit = newSoftLimit
    hardLimit = newHardLimit

    // Persist to file and mirror to UserDefaults for legacy consumers
    let limits = CalorieLimitsStorageService.Limits(
      softLimit: softLimit, hardLimit: hardLimit, hasManualCalorieLimits: true)
    CalorieLimitsStorageService.shared.save(limits)
    let userDefaults = UserDefaults.standard
    userDefaults.set(softLimit, forKey: "softLimit")
    userDefaults.set(hardLimit, forKey: "hardLimit")
    userDefaults.set(true, forKey: "hasManualCalorieLimits")
    return true
  }

  private func resetToHealthBasedLimits() {
    let userDefaults = UserDefaults.standard
    userDefaults.set(false, forKey: "hasManualCalorieLimits")  // Remove manual override
    // Also update file-backed store to reflect no manual override
    let existing = CalorieLimitsStorageService.shared.load()
    let limits = CalorieLimitsStorageService.Limits(
      softLimit: existing?.softLimit ?? softLimit,
      hardLimit: existing?.hardLimit ?? hardLimit,
      hasManualCalorieLimits: false
    )
    CalorieLimitsStorageService.shared.save(limits)
    recalculateCalorieLimitsFromHealthData()  // Recalculate from health data
    uiRefreshTrigger.toggle()  // Force UI to reflect new limits
  }

  private func recalculateCalorieLimitsFromHealthData() {
    let userDefaults = UserDefaults.standard

    // Don't override manually set calorie limits
    let hasManualCalorieLimits = CalorieLimitsStorageService.shared.load()?.hasManualCalorieLimits
      ?? userDefaults.bool(forKey: "hasManualCalorieLimits")
    if hasManualCalorieLimits {
      return
    }

    // Use current weight from the app if available and different from stored
    if personWeight > 0 {
      let currentWeight = (Double(personWeight) * 10).rounded() / 10
      if abs(currentWeight - userDefaults.double(forKey: "userWeight")) > 0.1 {
        userDefaults.set(currentWeight, forKey: "userWeight")
      }
    }

    guard let body = HealthPlanCalculator.storedBody(userDefaults) else {
      // Fallback: apply last saved health recommendation if available
      let saved = userDefaults.integer(forKey: "userRecommendedCalories")
      if saved > 0 {
        HealthPlanCalculator.applyLimits(calories: saved, userDefaults)
        softLimit = saved
        hardLimit = Int(Double(saved) * HealthPlanCalculator.hardLimitFactor)
      }
      return
    }

    let plan = HealthPlanCalculator.storedPlan(body: body, userDefaults)
    HealthPlanCalculator.applyLimits(calories: plan.calories, userDefaults)
    userDefaults.set(plan.calories, forKey: "userRecommendedCalories")
    softLimit = plan.calories
    hardLimit = Int(Double(plan.calories) * HealthPlanCalculator.hardLimitFactor)
    let target = userDefaults.double(forKey: "userTargetWeight")
    userDefaults.set(
      target > 0 ? target : HealthPlanCalculator.optimalWeight(heightCm: body.heightCm),
      forKey: "userOptimalWeight")
  }

  /// Activity calories for the currently viewed date (today or custom). Used to add to daily limit.
  /// Logged activities and Apple Health often describe the same workout, so the larger one wins.
  private func activityCaloriesForViewedDate() -> Int {
    max(loggedActivityCaloriesForViewedDate(), appleHealth.bonusKcal(dayISO: currentActivitiesDateISO()))
  }

  private func loggedActivityCaloriesForViewedDate() -> Int {
    if isViewingCustomDate, !currentViewingDateString.isEmpty {
      let parts = currentViewingDateString.split(separator: "-")
      if parts.count == 3, parts[0].count == 2, parts[1].count == 2, parts[2].count == 4 {
        let dateISO = "\(parts[2])-\(parts[1])-\(parts[0])"
        return UserDefaults.standard.integer(forKey: "activity_summary_total_\(dateISO)")
      }
    }
    let todayString = getCurrentUTCDateString()
    if todaySportCaloriesDate == todayString, todaySportCalories > 0 {
      return todaySportCalories
    }
    return 0
  }

  private func getAdjustedSoftLimit() -> Int {
    return softLimit + activityCaloriesForViewedDate()
  }

  private var mealPlannerRemaining: MealPlannerRemaining {
    let budget = getAdjustedSoftLimit()
    let targets = macroTargetsFromDailyKcal(budget)
    return MealPlannerRemaining(
      kcal: budget - caloriesLeft,
      protein: max(0, targets.protein - proteins),
      carbs: max(0, targets.carbs - carbs),
      fats: max(0, targets.fat - fats),
      sugar: max(0, targets.sugarMax - sugar)
    )
  }

  private func loadTodaySportCalories() {
    let todayString = getCurrentUTCDateString()

    // Check if we have sport calories stored for today
    if todaySportCaloriesDate == todayString {
      // Sport calories are already loaded and valid for today
      return
    }

    // If it's a new day, reset sport calories
    if todaySportCaloriesDate != todayString {
      todaySportCalories = 0
      todaySportCaloriesDate = ""
    }
  }

  private func refreshMacrosForCurrentView() {
    if isViewingCustomDate, !currentViewingDateString.isEmpty {
      GRPCService().fetchStatisticsData(date: currentViewingDateString) { dailyStats in
        DispatchQueue.main.async {
          if let stats = dailyStats {
            self.proteins = stats.proteins
            self.fats = stats.fats
            self.carbs = stats.carbohydrates
            self.sugar = stats.sugar
          } else {
            self.proteins = 0
            self.fats = 0
            self.carbs = 0
            self.sugar = 0
          }
        }
      }
    } else {
      GRPCService().fetchTodayStatistics { dailyStats in
        DispatchQueue.main.async {
          if let stats = dailyStats {
            self.proteins = stats.proteins
            self.fats = stats.fats
            self.carbs = stats.carbohydrates
            self.sugar = stats.sugar
          } else {
            self.proteins = 0
            self.fats = 0
            self.carbs = 0
            self.sugar = 0
          }
        }
      }
    }
  }

  // MARK: - Alcohol Helpers

  private func fetchAlcoholStatus() {
    GRPCService().fetchAlcoholLatest { resp in
      DispatchQueue.main.async {
        updateAlcoholIconColor(fromLatest: resp)
      }
    }
  }

  private func updateAlcoholIconColor(fromLatest resp: Eater_GetAlcoholLatestResponse?) {
    guard let resp = resp else {
      alcoholIconColor = .green
      return
    }
    // If any drink today, set lastAlcoholEventDate to today
    if resp.todaySummary.totalDrinks > 0 {
      lastAlcoholEventDate = Date()
      alcoholIconColor = .red
      return
    }
    // Otherwise, try to infer recentness via range of last 30 days
    let cal = Calendar.current
    let end = Date()
    guard let start = cal.date(byAdding: .day, value: -30, to: end) else {
      alcoholIconColor = .green
      return
    }
    let fmt = DateFormatter()
    fmt.dateFormat = "dd-MM-yyyy"
    let startStr = fmt.string(from: start)
    let endStr = fmt.string(from: end)
    GRPCService().fetchAlcoholRange(startDateDDMMYYYY: startStr, endDateDDMMYYYY: endStr) {
      rangeResp in
      DispatchQueue.main.async {
        if let rangeResp = rangeResp, let last = mostRecentAlcoholDate(events: rangeResp.events) {
          lastAlcoholEventDate = last
          alcoholIconColor = colorForLastAlcoholDate(last)
        } else {
          lastAlcoholEventDate = nil
          alcoholIconColor = .green
        }
      }
    }
  }

  private func mostRecentAlcoholDate(events: [Eater_AlcoholEvent]) -> Date? {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    var latest: Date? = nil
    for e in events {
      if let d = fmt.date(from: e.date) {
        if latest == nil || d > latest! { latest = d }
      }
    }
    return latest
  }

  private func colorForLastAlcoholDate(_ last: Date) -> Color {
    let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 999
    if days == 0 {
      return .red      // Today - red warning
    } else if days == 1 {
      return .yellow   // Yesterday - yellow caution
    } else {
      return .green    // 2+ days ago - green (good recovery)
    }
  }

  // MARK: - Daily Refresh Methods

  private func setupDailyRefreshTimer() {
    // Initialize the last known UTC date
    lastKnownUTCDate = getCurrentUTCDateString()

    // Set up timer to check for UTC date changes every 5 minutes instead of 30 seconds
    // This is much more efficient and still catches date changes promptly
    dailyRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in
      self.checkForUTCDateChange()
    }
  }

  private func stopDailyRefreshTimer() {
    dailyRefreshTimer?.invalidate()
    dailyRefreshTimer = nil
  }

  private func getCurrentUTCDateString() -> String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    formatter.dateFormat = "dd-MM-yyyy"
    return formatter.string(from: Date())
  }

  private func checkForUTCDateChange() {
    let currentUTCDate = getCurrentUTCDateString()

    if currentUTCDate != lastKnownUTCDate {
      print("UTC date changed from \(lastKnownUTCDate) to \(currentUTCDate) - refreshing data")
      lastKnownUTCDate = currentUTCDate

      // Reset activities for the new day
      todaySportCalories = 0
      todaySportCaloriesDate = ""
      todayActivityDate = ""

      // Only refresh if we're viewing today's data (not a custom date)
      if !isViewingCustomDate {
        // Clear both ProductStorageService and StatisticsService caches for the new day
        ProductStorageService.shared.clearCache()
        StatisticsService.shared.invalidateDay()

        // Fetch fresh data for the new day (this will use loading indicator since cache was cleared)
        fetchDataWithLoading()
      }

      // Reschedule notifications for the new local day
      NotificationService.shared.handleDayChangeIfNeeded()
    }
  }

  // MARK: - Activities date helpers

  /// ISO date (yyyy-MM-dd, UTC) for "today".
  private func getCurrentISODateString() -> String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }

  /// ISO date string (yyyy-MM-dd) for the calendar day the user selected (local day, not UTC).
  /// This way 17.02 in the calendar stays 2026-02-17 for API, not shifted to 16.02 by timezone.
  private func getISODateString(for date: Date) -> String {
    let cal = Calendar.current
    let comps = cal.dateComponents([.year, .month, .day], from: date)
    guard let y = comps.year, let m = comps.month, let d = comps.day else {
      let f = DateFormatter()
      f.timeZone = TimeZone(abbreviation: "UTC")
      f.dateFormat = "yyyy-MM-dd"
      return f.string(from: date)
    }
    return String(format: "%04d-%02d-%02d", y, m, d)
  }

  /// Date that ActivitiesView should use:
  /// - if viewing Today → today's YYYY-MM-DD
  /// - if calendar selected a custom date → that date's YYYY-MM-DD (from same string as main screen).
  private func currentActivitiesDateISO() -> String {
    if isViewingCustomDate, !currentViewingDateString.isEmpty {
      // Use the exact date string we show (dd-MM-yyyy) so Activities match the main screen day
      let parts = currentViewingDateString.split(separator: "-")
      if parts.count == 3, parts[0].count == 2, parts[1].count == 2, parts[2].count == 4 {
        return "\(parts[2])-\(parts[1])-\(parts[0])" // yyyy-MM-dd
      }
      return getISODateString(for: selectedDate)
    }
    return getCurrentISODateString()
  }
}

// Removed legacy SolidDarkBlueButtonStyle; unified button styles live in DesignSystem

// removed legacy dateFormatter; using localizedDateFormatter bound to app language

#Preview {
  ContentView()
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
