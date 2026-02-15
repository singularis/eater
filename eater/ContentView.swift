import SwiftUI

struct FullScreenPhotoData: Identifiable {
  let id = UUID()
  let image: UIImage?
  let foodName: String
}

struct ContentView: View {
  @EnvironmentObject var authService: AuthenticationService
  @EnvironmentObject var languageService: LanguageService
  @Environment(\.scenePhase) var scenePhase
  @StateObject private var themeService = ThemeService.shared
  @State private var products: [Product] = []
  @State private var caloriesLeft: Int = 0
  @State private var personWeight: Float = 0
  @State private var date = Date()
  @State private var selectedDate = Date()
  @State private var showCamera = false
  @State private var isLoadingRecommendation = false
  @State private var showLimitsAlert = false
  @State private var tempSoftLimit = ""
  @State private var tempHardLimit = ""
  @State private var softLimit = 1900
  @State private var hardLimit = 2100
  @State private var showUserProfile = false
  @State private var showHealthDisclaimer = false
  @State private var showOnboarding = false
  @State private var onboardingMode: OnboardingView.OnboardingMode = .initial
  @State private var showCalendarPicker = false
  @State private var isViewingCustomDate = false
  @State private var currentViewingDate = ""
  @State private var currentViewingDateString = ""  // Original format dd-MM-yyyy
  @State private var showRecommendation = false
  @State private var recommendationText = ""
  // Alcohol states
  @State private var showAlcoholCalendar = false
  @State private var alcoholIconColor: Color = .green
  @State private var lastAlcoholEventDate: Date? = nil
  @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
  @AppStorage("dataDisplayMode") private var dataDisplayMode: String = "simplified"
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

  // Full-screen photo states
  @State private var fullScreenPhotoData: FullScreenPhotoData? = nil

  // Weight input states
  @State private var showWeightActionSheet = false
  @State private var showManualWeightEntry = false
  @State private var manualWeightInput = ""
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

  private var localizedDateFormatter: DateFormatter {
    let df = DateFormatter()
    df.locale = Locale(identifier: languageService.currentCode)
    df.dateStyle = .medium
    df.timeStyle = .none
    return df
  }

  var body: some View {
    ZStack {
      AppTheme.backgroundGradient
        .edgesIgnoringSafeArea(.all)

      VStack(spacing: 2) {
        topBarView
        statsButtonsView
          .frame(height: 60)
        // Macros line (only in Full mode and when we have data)
        if dataDisplayMode == "full" && hasMacrosData {
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
            StatisticsService.shared.clearExpiredCache()
            ProductStorageService.shared.clearCache()
            self.returnToToday()
          }
        )
        .padding(.top, 0)

        cameraButtonView
          .padding(.top, 10)
      }
      .onAppear {
        loadLimitsFromUserDefaults()
        loadTodaySportCalories()
        fetchDataWithLoading()
        refreshMacrosForCurrentView()
        setupDailyRefreshTimer()
        setupActivityCaloriesObserver()
        if !hasSeenOnboarding {
          onboardingMode = .initial
          showOnboarding = true
        } else if AppSettingsService.shared.shouldShowHealthOnboarding {
            onboardingMode = .health
            showOnboarding = true
        } else if AppSettingsService.shared.shouldShowSocialOnboarding {
            onboardingMode = .social
            showOnboarding = true
        }
        fetchAlcoholStatus()
      }
      .onDisappear {
        stopDailyRefreshTimer()
      }
      .onChange(of: todaySportCalories) { _ in
        // Force UI refresh when sport calories change
        uiRefreshTrigger.toggle()
      }
      .onChange(of: todayActivityDate) { _ in
        // Force UI refresh when activity date changes
        uiRefreshTrigger.toggle()
      }
      .onChange(of: scenePhase) { newPhase in
        if newPhase == .inactive || newPhase == .background {
          if isViewingCustomDate {
             returnToToday()
          }
        }
      }
      .padding()
      .alert(loc("limits.title", "Set Calorie Limits"), isPresented: $showLimitsAlert) {
        VStack {
          TextField(loc("limits.soft", "Soft Limit"), text: $tempSoftLimit)
            .keyboardType(.numberPad)
          TextField(loc("limits.hard", "Hard Limit"), text: $tempHardLimit)
            .keyboardType(.numberPad)
        }
        Button(loc("limits.save_manual", "Save Manual Limits")) {
          saveLimits()
        }
        if UserDefaults.standard.bool(forKey: "hasUserHealthData") {
          Button(loc("limits.use_health", "Use Health-Based Calculation")) {
            resetToHealthBasedLimits()
          }
        }
        Button(loc("common.cancel", "Cancel"), role: .cancel) {}
      } message: {
        Text(
          loc(
            "limits.msg",
            "Set your daily calorie limits manually, or use health-based calculation if you have health data.\n\n⚠️ These are general guidelines. Consult a healthcare provider for personalized dietary advice."
          ))
      }
      .sheet(isPresented: $showUserProfile) {
        UserProfileView()
          .environmentObject(authService)
      }
      .sheet(isPresented: $showHealthDisclaimer) {
        HealthDisclaimerView()
      }
      .sheet(isPresented: $showRecommendation) {
        RecommendationView(recommendationText: recommendationText)
      }
      .sheet(isPresented: $showCalendarPicker) {
        CalendarDatePickerView(
          selectedDate: $selectedDate,
          isPresented: $showCalendarPicker,
          onDateSelected: { dateString in
            fetchCustomDateData(dateString: dateString)
          }
        )
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
      }
      .sheet(isPresented: $showProgressiveOnboarding) {
        ProgressiveOnboardingView(step: progressiveStep, isPresented: $showProgressiveOnboarding) {
          withAnimation {
            showProgressiveOnboarding = false
          }
          // Increment level based on step completed
          if progressiveStep == .demographics { AppSettingsService.shared.progressiveOnboardingLevel = 1 }
          else if progressiveStep == .measurements { AppSettingsService.shared.progressiveOnboardingLevel = 2 }
          else if progressiveStep == .activity { AppSettingsService.shared.progressiveOnboardingLevel = 3 }
          else if progressiveStep == .notifications { AppSettingsService.shared.progressiveOnboardingLevel = 4 }
        }
        .environmentObject(languageService)
      }
      .overlay(
        OnboardingView(isPresented: $showOnboarding, mode: onboardingMode)
          .environmentObject(languageService)
          .opacity(showOnboarding ? 1 : 0)
      )

      LoadingOverlay(isVisible: isLoadingData, message: loc("loading.food", "Loading food data..."))
      LoadingOverlay(
        isVisible: isLoadingFoodPhoto, message: loc("loading.photo", "Analyzing food photo..."))
    }
    .id(languageService.currentCode)
  }

  private var topBarView: some View {
    ZStack {
      dateDisplayView

      HStack {
        HStack(spacing: 24) {
          profileButton
          alcoholButton
        }
        Spacer()
        HStack(spacing: 24) {
          if useDevEnvironment {
            Text("DEV")
              .font(.system(size: 10, weight: .heavy))
              .foregroundColor(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.red)
              .cornerRadius(4)
          }
          healthInfoButton
          sportButton
        }
      }
    }
  }

  private var profileButton: some View {
    return Button(action: {
      HapticsService.shared.lightImpact()
      showUserProfile = true
    }) {
      ZStack {
        Circle()
          .fill(AppTheme.surface)
          .overlay(
            Circle()
              .stroke(
                LinearGradient(
                  gradient: Gradient(colors: [Color(red: 0.4, green: 0.5, blue: 1.0).opacity(0.9), Color(red: 0.4, green: 0.5, blue: 1.0).opacity(0.3)]),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 2
              )
          )
          .shadow(color: Color(red: 0.4, green: 0.5, blue: 1.0).opacity(0.4), radius: 6, x: 0, y: 3)

        ProfileImageView(
          profilePictureURL: authService.userProfilePictureURL,
          size: 30,
          fallbackIconColor: AppTheme.textPrimary,
          userName: authService.userName,
          userEmail: authService.userEmail
        )
        .clipShape(Circle())
      }
      .frame(width: 44, height: 44)
      .contentShape(Circle())
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var alcoholButton: some View {
    Button(action: {
      HapticsService.shared.select()
      showAlcoholCalendar = true
    }) {
      ZStack {
        Circle()
          .fill(AppTheme.surface)
          .overlay(
            Circle()
              .stroke(
                LinearGradient(
                  gradient: Gradient(colors: [
                    alcoholIconColor.opacity(0.9), alcoholIconColor.opacity(0.3),
                  ]),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 2
              )
          )
          .shadow(color: alcoholIconColor.opacity(0.4), radius: 6, x: 0, y: 3)

        Image(systemName: themeService.icon(for: "wineglass"))
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(alcoholIconColor)
      }
      .frame(width: 44, height: 44)
      .contentShape(Circle())
    }
    .buttonStyle(PressScaleButtonStyle())
    .sheet(isPresented: $showAlcoholCalendar) {
      AlcoholCalendarView(isPresented: $showAlcoholCalendar)
    }
  }

  private var dateDisplayView: some View {
    let shadow = AppTheme.cardShadow
    return VStack(spacing: 4) {
      HStack(spacing: 8) {
        VStack(spacing: 2) {
          Text(isViewingCustomDate ? currentViewingDate : localizedDateFormatter.string(from: date))
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)

          if isViewingCustomDate {
            Text(loc("date.custom", "Custom Date"))
              .font(.system(size: 10, weight: .medium, design: .rounded))
              .foregroundColor(AppTheme.warning)
          }
        }
        .onTapGesture {
          // Prevent opening calendar while loading data
          guard !isLoadingData else { return }
          HapticsService.shared.select()
          selectedDate = Date()
          showCalendarPicker = true
        }

        if isViewingCustomDate {
          Button(action: returnToToday) {
            Text(loc("date.today", "Today"))
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundColor(Color.black.opacity(0.9))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(AppTheme.accent.opacity(0.9))
              .cornerRadius(AppTheme.smallRadius)
          }
          .simultaneousGesture(TapGesture().onEnded { HapticsService.shared.select() })
        }
      }
    }
    .padding()
    .background(AppTheme.surfaceAlt)
    .cornerRadius(AppTheme.cornerRadius)
    .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
  }

  private var healthInfoButton: some View {
    Button(action: {
      HapticsService.shared.select()
      showHealthDisclaimer = true
    }) {
      ZStack {
        Circle()
          .fill(AppTheme.surface)
          .overlay(
            Circle()
              .stroke(
                LinearGradient(
                  gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.blue.opacity(0.3)]),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 2
              )
          )
          .shadow(color: Color.blue.opacity(0.4), radius: 6, x: 0, y: 3)

        Image(systemName: "info.circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(Color.blue)
      }
      .frame(width: 44, height: 44)
      .contentShape(Circle())
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var sportButton: some View {
    Button(action: {
      HapticsService.shared.select()
      showActivitiesView = true
    }) {
      ZStack {
        Circle()
          .fill(AppTheme.surface)
          .overlay(
            Circle()
              .stroke(
                LinearGradient(
                  gradient: Gradient(colors: [sportIconColor.opacity(0.9), sportIconColor.opacity(0.3)]
                  ),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 2
              )
          )
          .shadow(color: sportIconColor.opacity(0.4), radius: 6, x: 0, y: 3)

        Image(systemName: themeService.icon(for: "figure.run"))
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(sportIconColor)
      }
      .frame(width: 44, height: 44)
      .contentShape(Circle())
    }
    .buttonStyle(PressScaleButtonStyle())
    .id("sport-\(todayActivityDate)-\(todaySportCalories)-\(uiRefreshTrigger)")
    .sheet(isPresented: $showActivitiesView) {
      ActivitiesView()
    }
  }

  private var statsButtonsView: some View {
    HStack(spacing: 12) {
      weightButton
      caloriesButton
      recommendationButton
    }
    .frame(maxWidth: .infinity)
  }

  private var weightButton: some View {
    let shadow = AppTheme.cardShadow
    return Button(action: {
      HapticsService.shared.select()
      showWeightActionSheet = true
    }) {
      ZStack {
        if isLoadingWeightPhoto {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.textPrimary))
        } else {
          Text(String(format: "%.1f", personWeight))
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(8)
      .background(AppTheme.surface)
      .cornerRadius(AppTheme.cornerRadius)
      .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    .confirmationDialog(
      loc("weight.record.title", "Record Weight"), isPresented: $showWeightActionSheet,
      titleVisibility: .visible
    ) {
      Button(loc("weight.take_photo", "Take Photo")) {
        HapticsService.shared.select()
        showCamera = true
      }
      Button(loc("weight.manual_entry", "Manual Entry")) {
        HapticsService.shared.select()
        manualWeightInput = ""
        showManualWeightEntry = true
      }
      Button(loc("common.cancel", "Cancel"), role: .cancel) {}
    } message: {
      Text(loc("weight.record.msg", "Choose how you'd like to record your weight"))
    }
    .sheet(isPresented: $showCamera) {
      WeightCameraView(
        onPhotoSuccess: {
          // Clear both caches since weight was updated
          StatisticsService.shared.clearExpiredCache()
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
    }
    .alert(loc("weight.enter.title", "Enter Weight"), isPresented: $showManualWeightEntry) {
      TextField(loc("weight.enter.placeholder", "Weight (kg)"), text: $manualWeightInput)
        .keyboardType(.decimalPad)
      Button(loc("common.save", "Submit")) {
        submitManualWeight()
      }
      Button(loc("common.cancel", "Cancel"), role: .cancel) {}
    } message: {
      Text(loc("weight.enter.msg", "Enter your weight in kilograms"))
    }
  }

  private var caloriesButton: some View {
    let adjustedSoftLimit = getAdjustedSoftLimit()
    let shadow = AppTheme.cardShadow
    return Button(action: {
      HapticsService.shared.select()
      tempSoftLimit = String(softLimit)
      tempHardLimit = String(hardLimit)
      showLimitsAlert = true
    }) {
      HStack(spacing: 4) {
        Image(systemName: themeService.icon(for: "flame.fill"))
          .font(.system(size: 20))
        Text("\(adjustedSoftLimit - caloriesLeft)")
          .font(.system(size: 22, weight: .semibold, design: .rounded))
      }
      .foregroundColor(getColor(for: caloriesLeft, adjustedSoftLimit: adjustedSoftLimit))
      .frame(maxWidth: .infinity)
      .padding(8)
      .background(AppTheme.surface)
      .cornerRadius(AppTheme.cornerRadius)
      .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    .id("calories-\(todaySportCalories)-\(todaySportCaloriesDate)-\(uiRefreshTrigger)")
  }

  private var recommendationButton: some View {
    let shadow = AppTheme.cardShadow
    return ZStack {
      if isLoadingRecommendation {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.textPrimary))
      } else {
        Text(languageService.shortRecommendationLabel())
          .font(.system(size: 22, weight: .semibold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(8)
    .background(AppTheme.surface)
    .cornerRadius(AppTheme.cornerRadius)
    .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    .onTapGesture {
      HapticsService.shared.select()
      isLoadingRecommendation = true
      GRPCService().getRecommendation(days: 7, languageCode: languageService.currentCode) { recommendation in
        DispatchQueue.main.async {
          if recommendation.isEmpty {
            self.recommendationText = loc(
              "rec.fallback",
              "We couldn't customize your advice right now, but here are some general wellness tips:\n\nConsistent habits build a healthy lifestyle. Start by incorporating more whole foods like vegetables, fruits, nuts, and legumes into your meals. These provide essential fiber and nutrients that processed food often lacks.\n\nTry to limit added sugars and heavily processed snacks, opting instead for natural sweetness from fruit. Staying hydrated is often overlooked but crucial for metabolism and energy.\n\nPhysical activity is the perfect partner to nutrition. Even a daily 30-minute walk can make a significant difference. Lastly, quality sleep is when your body repairs itself—prioritize it just as you do your meals.\n\n⚠️ Disclaimer: This guide is for informational purposes only and is not a substitute for professional medical advice."
            )
          } else {
            self.recommendationText = recommendation
          }
          self.showRecommendation = true
          HapticsService.shared.success()
          self.isLoadingRecommendation = false
          // Return to today after getting recommendation
          if self.isViewingCustomDate {
            self.returnToToday()
          }
        }
      }
    }
  }

  private var macrosLineView: some View {
    let text = formattedMacrosLine()
    let shadow = AppTheme.cardShadow
    return HStack {
      Spacer(minLength: 0)
      Text(text)
        .lineLimit(1)
        .truncationMode(.tail)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .minimumScaleFactor(0.85)
        .foregroundColor(AppTheme.textPrimary)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(AppTheme.surface)
    .cornerRadius(AppTheme.cornerRadius)
    .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    .padding(.horizontal, -6)
    .padding(.top, 6)
  }

  private func formattedMacrosLine() -> String {
    func fmt1(_ v: Double) -> String { String(format: "%.1f", v) }
    let pro = loc("macro.pro", "PRO")
    let fat = loc("macro.fat", "FAT")
    let car = loc("macro.car", "CAR")
    let sug = loc("macro.sug", "SUG")
    let grams = loc("units.g", "g")
    return pro + " " + fmt1(proteins) + grams + " • " + fat + " " + fmt1(fats) + grams + " • " + car
      + " " + fmt1(carbs) + grams + " • " + sug + " " + fmt1(sugar) + grams
  }

  private var cameraButtonView: some View {
    CameraButtonView(
      isLoadingFoodPhoto: isLoadingFoodPhoto,
      selectedDate: selectedDate,
      isViewingCustomDate: isViewingCustomDate,
      onPhotoSuccess: {
        // Increment scan count
        AppSettingsService.shared.foodScannedCount += 1
        
        // Trigger subsequent onboarding phases if needed
        if AppSettingsService.shared.shouldShowHealthOnboarding {
            onboardingMode = .health
            showOnboarding = true
        } else if AppSettingsService.shared.shouldShowSocialOnboarding {
            onboardingMode = .social
            showOnboarding = true
        }
        
        // Original logic
        fetchDataAfterFoodPhoto()
      },
      onPhotoFailure: {
        // Photo processing failed, no need to fetch data
        HapticsService.shared.error()
        isLoadingFoodPhoto = false
      },
      onPhotoStarted: {
        // Photo processing started
        HapticsService.shared.mediumImpact()
        isLoadingFoodPhoto = true
      },
      onReturnToToday: {
        returnToToday()
      }
    )
    .buttonStyle(PrimaryButtonStyle())
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

  // MARK: - Data Fetching Methods

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
      refreshMacrosForCurrentView()
    }

    // Check if we're viewing a custom date - if so, fetch that specific date
    if isViewingCustomDate && !currentViewingDateString.isEmpty {
      ProductStorageService.shared.fetchAndProcessCustomDateProducts(date: currentViewingDateString) { 
        (fetchedProducts, calories, weight) in
        DispatchQueue.main.async {
          let previousWeight = self.personWeight
          self.products = FoodExtrasStore.shared.apply(to: fetchedProducts)
          FoodPhotoService.shared.prefetchPhotos(for: fetchedProducts)
          self.caloriesLeft = calories + FoodExtrasStore.shared.totalExtrasCalories(for: self.products)
          self.personWeight = weight
          self.isLoadingData = false
          self.isFetchingData = false

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
    ProductStorageService.shared.fetchAndProcessProducts(forceRefresh: true) { (fetchedProducts, calories, weight) in
      DispatchQueue.main.async {
        let previousWeight = self.personWeight
        self.products = FoodExtrasStore.shared.apply(to: fetchedProducts)
        FoodPhotoService.shared.prefetchPhotos(for: fetchedProducts)
        self.caloriesLeft = calories + FoodExtrasStore.shared.totalExtrasCalories(for: self.products)
        self.personWeight = weight
        self.isLoadingData = false
        self.isFetchingData = false

        // Check for weight photo motivation message
        if self.pendingWeightPhotoCheck && weight > 0 {
          self.pendingWeightPhotoCheck = false
          
          // Check if user lost weight and show motivational message
          if let weightLossGrams = WeightMotivationService.shared.checkAndUpdateForMotivation(newWeight: weight) {
            // User lost weight! Show motivational message
            let motivation = WeightMotivationService.shared.getMotivationalMessage(
              weightLossGrams: weightLossGrams,
              languageCode: self.languageService.currentCode
            )
            AlertHelper.showAlert(
              title: motivation.title,
              message: motivation.message,
              haptic: .success)
          } else {
            // No weight loss detected, show standard message
            AlertHelper.showAlert(
              title: loc("weight.recorded.title", "Weight Recorded"),
              message: loc("weight.recorded.msg", "Your weight has been successfully recorded."),
              haptic: .success)
          }
        }

        // Recalculate calories if weight changed and user has health data
        let userDefaults = UserDefaults.standard
        if userDefaults.bool(forKey: "hasUserHealthData"), abs(previousWeight - weight) > 0.1 {
          self.recalculateCalorieLimitsFromHealthData()
          self.checkWeightGoalMilestones(previousWeight: previousWeight, newWeight: weight)
        }
        self.refreshMacrosForCurrentView()
      }
    }
  }

  func fetchData() {
    // Prevent multiple simultaneous data fetches
    guard !isFetchingData else { return }

    isFetchingData = true
    // For background updates, always try cache first
    ProductStorageService.shared.fetchAndProcessProducts { fetchedProducts, calories, weight in
      DispatchQueue.main.async {
        let previousWeight = self.personWeight
        self.products = FoodExtrasStore.shared.apply(to: fetchedProducts)
        self.caloriesLeft = calories + FoodExtrasStore.shared.totalExtrasCalories(for: self.products)
        self.personWeight = weight
        self.isFetchingData = false

        // Recalculate calories if weight changed and user has health data
        let userDefaults = UserDefaults.standard
        if userDefaults.bool(forKey: "hasUserHealthData"), abs(previousWeight - weight) > 0.1 {
          self.recalculateCalorieLimitsFromHealthData()
          self.checkWeightGoalMilestones(previousWeight: previousWeight, newWeight: weight)
        }
        self.refreshMacrosForCurrentView()
      }
    }
  }

  private func checkWeightGoalMilestones(previousWeight: Float, newWeight: Float) {
    let userDefaults = UserDefaults.standard
    let target = userDefaults.double(forKey: "userTargetWeight")
    let mode = userDefaults.string(forKey: "userGoalMode") ?? "maintain"
    guard target > 0 else { return }

    // Avoid spamming: at most once per UTC day
    let today = getCurrentUTCDateString()
    let lastShown = userDefaults.string(forKey: "goalMilestoneLastShownDate") ?? ""
    if lastShown == today { return }

    let tol = 0.2
    let w = Double(newWeight)
    let prev = Double(previousWeight)

    func offerMaintenance() {
      userDefaults.set("maintain", forKey: "userGoalMode")
      userDefaults.set(0, forKey: "userGoalMonths")
      userDefaults.set(w, forKey: "userTargetWeight")
      self.recalculateCalorieLimitsFromHealthData()
      userDefaults.set(today, forKey: "goalMilestoneLastShownDate")
      AlertHelper.showAlert(
        title: loc("goal.maintain.enabled.title", "Maintenance enabled"),
        message: loc("goal.maintain.enabled.msg", "Great! We'll help you maintain your weight with ongoing tracking."),
        haptic: .success
      )
    }

    if mode == "lose" {
      if w <= target + tol {
        userDefaults.set(today, forKey: "goalMilestoneLastShownDate")
        AlertHelper.showCelebration(
          title: loc("goal.reached.title", "You did it!"),
          message: loc("goal.reached.msg", "Congratulations — you reached your target weight!"),
          primaryTitle: loc("goal.maintain.cta", "Switch to maintenance"),
          primaryAction: offerMaintenance,
          secondaryTitle: loc("common.close", "Close"),
          secondaryAction: nil
        )
      } else if w > prev + 0.2 {
        userDefaults.set(today, forKey: "goalMilestoneLastShownDate")
        AlertHelper.showAlert(
          title: loc("goal.motivation.title", "Keep going"),
          message: loc(
            "goal.motivation.msg",
            "Small ups and downs are normal. You're still on your path — keep tracking and we'll adjust your plan."
          ),
          haptic: .select
        )
      }
    } else if mode == "gain" {
      if w >= target - tol {
        userDefaults.set(today, forKey: "goalMilestoneLastShownDate")
        AlertHelper.showCelebration(
          title: loc("goal.reached.title", "You did it!"),
          message: loc("goal.reached.msg", "Congratulations — you reached your target weight!"),
          primaryTitle: loc("goal.maintain.cta", "Switch to maintenance"),
          primaryAction: offerMaintenance,
          secondaryTitle: loc("common.close", "Close"),
          secondaryAction: nil
        )
      } else if w < prev - 0.2 {
        userDefaults.set(today, forKey: "goalMilestoneLastShownDate")
        AlertHelper.showAlert(
          title: loc("goal.motivation.title", "Keep going"),
          message: loc(
            "goal.motivation.msg",
            "Small ups and downs are normal. You're still on your path — keep tracking and we'll adjust your plan."
          ),
          haptic: .select
        )
      }
    } else {
      // maintain / activityOnly: no milestone popups for now
    }
  }

  func deleteProduct(time: Int64) {
    GRPCService().deleteFood(time: Int64(time)) { success in
      DispatchQueue.main.async {
        if success {
          self.fetchData()
        } else {
          // Failed to delete product
        }
      }
    }
  }

  func checkProgressiveOnboarding() {
    let count = AppSettingsService.shared.foodSharedCount
    let level = AppSettingsService.shared.progressiveOnboardingLevel
    let hasHealthData = UserDefaults.standard.bool(forKey: "hasUserHealthData")
    
    var nextStep: ProgressiveOnboardingStep = .none
    var shouldTrigger = false
    
    // If user already has health data, skip to notifications at count 5
    if hasHealthData {
      if count >= 5 && level < 4 {
        nextStep = .notifications
        shouldTrigger = true
      }
    } else {
      // Logic: 1->Demographics, 2->Measurements, 3->Activity, 5->Notifications
      if count >= 1 && level < 1 {
        nextStep = .demographics
        shouldTrigger = true
      } else if count >= 2 && level < 2 {
        nextStep = .measurements
        shouldTrigger = true
      } else if count >= 3 && level < 3 {
        nextStep = .activity
        shouldTrigger = true
      } else if count >= 5 && level < 4 {
        nextStep = .notifications
        shouldTrigger = true
      }
    }
    
    if shouldTrigger {
       DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          self.progressiveStep = nextStep
          self.showProgressiveOnboarding = true
       }
    }
  }

  func fetchDataAfterFoodPhoto() {
    HapticsService.shared.success()
    AppSettingsService.shared.foodSharedCount += 1
    
    // Clear today's statistics cache since new food was added
    StatisticsService.shared.clearExpiredCache()

    // Note: ProductStorageService cache is already updated by the fetchAndProcessProducts call
    // that handles the image mapping, so no need to clear it here

    // If viewing a custom/past date, stay on that date and refresh it
    // If on today, just refresh today
    if isViewingCustomDate {
      // Stay on the selected past date and refresh it
      ProductStorageService.shared.clearCache() // Clear cache to force fresh data
      fetchDataWithLoading() // This will fetch data for the currently selected date
      
      // After 30 seconds, ask user if they want to go back to Today

      DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
        // Only prompt if still viewing the custom date
        guard self.isViewingCustomDate else { return }

        AlertHelper.showConfirmation(
          title: loc("backdating.return_today.title", "Food Logged"),
          message: loc("backdating.return_today.msg", "Your food was recorded for the selected past date. Would you like to return to Today?"),
          actions: [
            UIAlertAction(title: loc("backdating.return_today.stay", "Stay Here"), style: .cancel),
            UIAlertAction(title: loc("backdating.return_today.return", "Return to Today"), style: .default) { _ in
              self.returnToToday()
            }
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
    // Repurposed as "Try manually" – user can manually fix dish name.
    guard let userEmail = authService.userEmail else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc(
          "portion.modify.need_login", "Unable to update. Please sign in again."))
      return
    }

    // Find current product to prefill the text field with existing name
    guard let product = products.first(where: { $0.time == time }) else {
      return
    }

    AlertHelper.showTextInputAlert(
      title: loc("manual_food.title", "Fix food name"),
      message: loc(
        "manual_food.msg",
        "Enter the correct dish name. This will replace the current name in your log."
      ),
      placeholder: product.name,
      initialText: product.name,
      confirmTitle: loc("common.save", "Save")
    ) { newName in
      // Re-analyze the existing photo using the user-provided dish name,
      // so calories/grams/health rating update (not just the title).
      GRPCService().modifyFoodRecord(
        time: time,
        userEmail: userEmail,
        percentage: 100,
        isTryAgain: true,
        imageId: imageId,
        manualFoodName: newName
      ) { success in
        DispatchQueue.main.async {
          if success {
            // Clear caches and refresh so updated nutrition/health comes from backend
            StatisticsService.shared.clearExpiredCache()
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
    }
  }
  
  func addSugarToProduct(time: Int64, foodName: String) {
    guard let userEmail = authService.userEmail else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc("portion.modify.need_login", "Unable to add sugar. Please sign in again."))
      return
    }
    
    // Add 1 teaspoon of sugar (1 tsp = ~5g, ~20 calories)
    GRPCService().modifyFoodRecord(
      time: time,
      userEmail: userEmail,
      percentage: 100,
      addedSugarTsp: 1.0
    ) { success in
      DispatchQueue.main.async {
        if success {
          // Optimistically update UI + local store so sugar icon and calories/grams update immediately
          FoodExtrasStore.shared.addSugar(time: time, tsp: 1)
          let updated = FoodExtrasStore.shared.apply(to: self.products)
          self.products = updated
          self.caloriesLeft += 20

          // Clear caches and refresh
          StatisticsService.shared.clearExpiredCache()
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
        extras: updatedExtras
      )
    }

    // Adjust top calories (calories consumed) by this extra's calories
    if let def = FoodExtrasStore.definitions[extraKey] {
      self.caloriesLeft += def.calories
    }

    // Persist updated view state into cache for fast reload UX
    ProductStorageService.shared.saveProducts(self.products, calories: self.caloriesLeft, weight: self.personWeight)
  }

  func modifyProductPortion(time: Int64, foodName: String, percentage: Int32) {
    guard let userEmail = authService.userEmail else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc(
          "portion.modify.need_login", "Unable to modify food portion. Please sign in again."))
      return
    }

    GRPCService().modifyFoodRecord(time: time, userEmail: userEmail, percentage: percentage) {
      success in
      DispatchQueue.main.async {
        if success {
          // Clear both caches since food was modified
          StatisticsService.shared.clearExpiredCache()
          ProductStorageService.shared.clearCache()

          // Show success message
          AlertHelper.showAlert(
            title: loc("portion.updated.title", "Portion Updated"),
            message: String(
              format: loc("portion.updated.msg", "Successfully updated '%@' to %d%% portion."),
            foodName, percentage),
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
          StatisticsService.shared.clearExpiredCache()
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

    ProductStorageService.shared.fetchAndProcessCustomDateProducts(date: dateString) {
      fetchedProducts, calories, weight in
      DispatchQueue.main.async {
        let previousWeight = self.personWeight
        self.products = fetchedProducts
        self.caloriesLeft = calories
        self.personWeight = weight
        self.isLoadingData = false

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

  func submitManualWeight() {
    // Normalize decimal separator (replace comma with dot for proper Float parsing)
    let normalizedInput = manualWeightInput.replacingOccurrences(of: ",", with: ".")

    guard let weight = Float(normalizedInput), weight > 0 else {
      AlertHelper.showAlert(
        title: loc("weight.invalid.title", "Invalid Weight"),
        message: loc("weight.invalid.msg", "Please enter a valid weight in kilograms."),
        haptic: .error)
      return
    }

    guard let userEmail = authService.userEmail else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc("weight.need_login", "Unable to submit weight. Please sign in again."),
        haptic: .error)
      return
    }

    isLoadingWeightPhoto = true

    GRPCService().sendManualWeight(weight: weight, userEmail: userEmail) { success in
      DispatchQueue.main.async {
        self.isLoadingWeightPhoto = false

        if success {
          // Clear both caches since weight was updated
          StatisticsService.shared.clearExpiredCache()
          ProductStorageService.shared.clearCache()

          // Check if user lost weight and show motivational message
          if let weightLossGrams = WeightMotivationService.shared.checkAndUpdateForMotivation(newWeight: weight) {
            // User lost weight! Show motivational message
            let motivation = WeightMotivationService.shared.getMotivationalMessage(
              weightLossGrams: weightLossGrams,
              languageCode: self.languageService.currentCode
            )
            
            // Always return to today after manual weight entry
            self.returnToToday()
            AlertHelper.showAlert(
              title: motivation.title,
              message: motivation.message,
              haptic: .success)
          } else {
            // No weight loss detected, show standard message
            // Always return to today after manual weight entry
            self.returnToToday()
            AlertHelper.showAlert(
              title: loc("weight.recorded.title", "Weight Recorded"),
              message: loc("weight.recorded.msg", "Your weight has been successfully recorded."),
              haptic: .success)
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

  private func saveLimits() {
    guard let newSoftLimit = Int(tempSoftLimit),
      let newHardLimit = Int(tempHardLimit),
      newSoftLimit > 0,
      newHardLimit > 0,
      newSoftLimit <= newHardLimit
    else {
      // Show error if invalid input
      AlertHelper.showAlert(
        title: loc("limits.invalid_input_title", "Invalid Input"),
        message: loc(
          "limits.invalid_input_msg",
          "Please enter valid positive numbers. Soft limit must be less than or equal to hard limit."
        ))
      return
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
  }

  private func recalculateCalorieLimitsFromHealthData() {
    let userDefaults = UserDefaults.standard

    // Don't override manually set calorie limits
    let hasManualCalorieLimits = CalorieLimitsStorageService.shared.load()?.hasManualCalorieLimits
      ?? userDefaults.bool(forKey: "hasManualCalorieLimits")
    if hasManualCalorieLimits {
      return
    }

    let height = userDefaults.double(forKey: "userHeight")
    var weight = userDefaults.double(forKey: "userWeight")
    let age = userDefaults.integer(forKey: "userAge")
    let isMale = userDefaults.bool(forKey: "userIsMale")
    let activityLevel = userDefaults.string(forKey: "userActivityLevel") ?? "Sedentary"
    let targetWeight = userDefaults.double(forKey: "userTargetWeight")
    let goalMode = userDefaults.string(forKey: "userGoalMode") ?? "maintain"
    let goalMonths = userDefaults.integer(forKey: "userGoalMonths")

    // Use current weight from the app if available and different from stored
    if personWeight > 0 {
      let currentWeight = Double(personWeight)
      if abs(currentWeight - weight) > 0.1 {  // If weight has changed significantly
        weight = (currentWeight * 10).rounded() / 10
        userDefaults.set(weight, forKey: "userWeight")  // Update stored weight
      }
    }

    guard height > 0, weight > 0, age > 0 else { return }

    // Calculate optimal weight using BMI (21.5 - middle of healthy range)
    let heightInMeters = height / 100.0
    let optimalWeight = 21.5 * heightInMeters * heightInMeters

    // Calculate BMR using Mifflin-St Jeor Equation
    let bmr: Double
    if isMale {
      bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
    }

    // Activity multipliers
    let activityMultiplier: Double
    switch activityLevel {
    case "Sedentary":
      activityMultiplier = 1.2
    case "Lightly Active":
      activityMultiplier = 1.375
    case "Moderately Active":
      activityMultiplier = 1.55
    case "Very Active":
      activityMultiplier = 1.725
    case "Extremely Active":
      activityMultiplier = 1.9
    default:
      activityMultiplier = 1.2
    }

    // Calculate TDEE (Total Daily Energy Expenditure)
    let tdee = bmr * activityMultiplier

    // Adjust calories based on user goal (target weight + period), fallback to optimal weight behavior.
    var recommendedCalories: Int
    let minCalories = isMale ? 1500 : 1200

    if targetWeight > 0, (goalMode == "lose" || goalMode == "gain"), goalMonths >= 2 {
      let diffKg = targetWeight - weight  // negative = lose, positive = gain

      // Enforce healthy minimum pacing (same rules as HealthSettingsView)
      let absDiff = abs(diffKg)
      let minMonths: Int
      if absDiff <= 5.0 {
        minMonths = 2
      } else if absDiff <= 10.0 {
        minMonths = 4
      } else {
        minMonths = 6
      }

      let months = max(goalMonths, minMonths)
      let days = Double(months) * 30.4
      let dailyDelta = (diffKg * 7700.0) / days
      recommendedCalories = max(Int(tdee + dailyDelta), minCalories)
    } else if goalMode == "activityOnly" || goalMode == "maintain" {
      recommendedCalories = Int(tdee)
    } else if targetWeight > 0 {
      // Target set but no mode/period - default maintain for small diffs, else 4 months
      let diffKg = targetWeight - weight
      if abs(diffKg) <= 1.0 {
        recommendedCalories = Int(tdee)
      } else {
        // Use a healthy minimum: 2 months up to 5kg, 4 months up to 10kg, 6 months above.
        let absDiff = abs(diffKg)
        let months: Double
        if absDiff <= 5.0 {
          months = 2.0
        } else if absDiff <= 10.0 {
          months = 4.0
        } else {
          months = 6.0
        }
        let days = months * 30.4
        let dailyDelta = (diffKg * 7700.0) / days
        recommendedCalories = max(Int(tdee + dailyDelta), minCalories)
      }
    } else {
      // Legacy fallback: compare to optimal weight
      let weightDifference = weight - optimalWeight
      let calorieAdjustment: Double
      if abs(weightDifference) < 2 {
        calorieAdjustment = 0
      } else if weightDifference > 0 {
        calorieAdjustment = -500
      } else {
        calorieAdjustment = 300
      }
      recommendedCalories = max(Int(tdee + calorieAdjustment), minCalories)
      userDefaults.set(optimalWeight, forKey: "userTargetWeight")
      userDefaults.set("lose", forKey: "userGoalMode")
      userDefaults.set(4, forKey: "userGoalMonths")
    }

    // Update the calorie limits
    softLimit = recommendedCalories
    hardLimit = Int(Double(recommendedCalories) * 1.15)  // 15% above recommendation

    // Save updated values (file + UserDefaults mirror)
    CalorieLimitsStorageService.shared.save(
      .init(softLimit: softLimit, hardLimit: hardLimit, hasManualCalorieLimits: false))
    userDefaults.set(softLimit, forKey: "softLimit")
    userDefaults.set(hardLimit, forKey: "hardLimit")
    userDefaults.set(recommendedCalories, forKey: "userRecommendedCalories")
    // Keep legacy key for UI compatibility, but prefer userTargetWeight
    userDefaults.set(userDefaults.double(forKey: "userTargetWeight") > 0 ? userDefaults.double(forKey: "userTargetWeight") : optimalWeight, forKey: "userOptimalWeight")
  }

  private func getAdjustedSoftLimit() -> Int {
    let todayString = getCurrentUTCDateString()

    // Check if sport calories were added for today
    if todaySportCaloriesDate == todayString && todaySportCalories > 0 {
      return softLimit + todaySportCalories
    }

    return softLimit
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
        StatisticsService.shared.clearExpiredCache()

        // Fetch fresh data for the new day (this will use loading indicator since cache was cleared)
        fetchDataWithLoading()
      }

      // Reschedule notifications for the new local day
      NotificationService.shared.handleDayChangeIfNeeded()
    }
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
