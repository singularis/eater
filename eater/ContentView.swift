import SwiftUI

struct FullScreenPhotoData: Identifiable {
  let id = UUID()
  let image: UIImage?
  let foodName: String
}

struct ContentView: View {
  @EnvironmentObject var authService: AuthenticationService
  @EnvironmentObject var languageService: LanguageService
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

  // Daily refresh states
  @State private var dailyRefreshTimer: Timer?
  @State private var lastKnownUTCDate: String = ""

  // Sport calories states
  @State private var showSportCaloriesAlert = false
  @State private var sportCaloriesInput = ""
  @State private var todaySportCalories = 0
  @AppStorage("todaySportCaloriesDate") private var todaySportCaloriesDate: String = ""

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
      Color.black
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
        if !hasSeenOnboarding {
          showOnboarding = true
        }
        fetchAlcoholStatus()
      }
      .onDisappear {
        stopDailyRefreshTimer()
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
      .overlay(
        OnboardingView(isPresented: $showOnboarding)
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
          healthInfoButton
          sportButton
        }
      }
    }
  }

  private var profileButton: some View {
    Button(action: {
      showUserProfile = true
    }) {
      ProfileImageView(
        profilePictureURL: authService.userProfilePictureURL,
        size: 30,
        fallbackIconColor: .white,
        userName: authService.userName,
        userEmail: authService.userEmail
      )
      .background(Color.gray.opacity(0.3))
      .clipShape(Circle())
      .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 3)
    }
  }

  private var alcoholButton: some View {
    Button(action: {
      showAlcoholCalendar = true
    }) {
      ZStack {
        Circle()
          .fill(Color.white.opacity(0.08))
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

        Image(systemName: "wineglass")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(alcoholIconColor)
      }
      .frame(width: 36, height: 36)
      .contentShape(Circle())
    }
    .sheet(isPresented: $showAlcoholCalendar) {
      AlcoholCalendarView(isPresented: $showAlcoholCalendar)
    }
  }

  private var dateDisplayView: some View {
    VStack(spacing: 4) {
      HStack(spacing: 8) {
        VStack(spacing: 2) {
          Text(isViewingCustomDate ? currentViewingDate : localizedDateFormatter.string(from: date))
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(.white)

          if isViewingCustomDate {
            Text(loc("date.custom", "Custom Date"))
              .font(.system(size: 10, weight: .medium, design: .rounded))
              .foregroundColor(.yellow)
          }
        }
        .onTapGesture {
          // Prevent opening calendar while loading data
          guard !isLoadingData else { return }
          selectedDate = Date()
          showCalendarPicker = true
        }

        if isViewingCustomDate {
          Button(action: returnToToday) {
            Text(loc("date.today", "Today"))
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundColor(.blue)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.white.opacity(0.9))
              .cornerRadius(8)
          }
        }
      }
    }
    .padding()
    .background(Color.black.opacity(0.8))
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.9), radius: 10, x: 0, y: 8)
  }

  private var healthInfoButton: some View {
    Button(action: {
      showHealthDisclaimer = true
    }) {
      ZStack {
        Circle()
          .fill(Color.white.opacity(0.08))
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
      .frame(width: 36, height: 36)
      .contentShape(Circle())
    }
  }

  private var sportButton: some View {
    Button(action: {
      sportCaloriesInput = ""
      showSportCaloriesAlert = true
    }) {
      ZStack {
        Circle()
          .fill(Color.white.opacity(0.08))
          .overlay(
            Circle()
              .stroke(
                LinearGradient(
                  gradient: Gradient(colors: [Color.orange.opacity(0.9), Color.orange.opacity(0.3)]
                  ),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 2
              )
          )
          .shadow(color: Color.orange.opacity(0.4), radius: 6, x: 0, y: 3)

        Image(systemName: "figure.run")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(Color.orange)
      }
      .frame(width: 36, height: 36)
      .contentShape(Circle())
    }
    .alert(loc("sport.title", "Sport Calories Bonus"), isPresented: $showSportCaloriesAlert) {
      TextField(loc("sport.placeholder", "Calories burned (e.g., 300)"), text: $sportCaloriesInput)
        .keyboardType(.numberPad)
      Button(loc("sport.add", "Add to Today's Limit")) {
        submitSportCalories()
      }
      Button(loc("common.cancel", "Cancel"), role: .cancel) {}
    } message: {
      Text(
        loc(
          "sport.msg",
          "Enter the number of calories you burned during your workout. This will be added to your daily calorie limit for today only."
        ))
    }
  }

  private var statsButtonsView: some View {
    GeometryReader { geo in
      weightButton(geo: geo)
      caloriesButton(geo: geo)
      recommendationButton(geo: geo)
    }
  }

  private func weightButton(geo: GeometryProxy) -> some View {
    Button(action: {
      showWeightActionSheet = true
    }) {
      ZStack {
        if isLoadingWeightPhoto {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
        } else {
          Text(String(format: "%.1f", personWeight))
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
        }
      }
      .padding()
      .background(Color.gray.opacity(0.8))
      .cornerRadius(16)
      .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)
    }
    .position(x: 30, y: geo.size.height / 2)
    .confirmationDialog(
      loc("weight.record.title", "Record Weight"), isPresented: $showWeightActionSheet,
      titleVisibility: .visible
    ) {
      Button(loc("weight.take_photo", "Take Photo")) {
        showCamera = true
      }
      Button(loc("weight.manual_entry", "Manual Entry")) {
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

  private func caloriesButton(geo: GeometryProxy) -> some View {
    let adjustedSoftLimit = getAdjustedSoftLimit()
    return Text("\(loc("calories.label", "Calories")): \(adjustedSoftLimit - caloriesLeft)")
      .font(.system(size: 22, weight: .semibold, design: .rounded))
      .foregroundColor(getColor(for: caloriesLeft, adjustedSoftLimit: adjustedSoftLimit))
      .padding()
      .background(Color.gray.opacity(0.8))
      .cornerRadius(16)
      .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)
      .position(x: geo.size.width / 2, y: geo.size.height / 2)
      .onTapGesture {
        tempSoftLimit = String(softLimit)
        tempHardLimit = String(hardLimit)
        showLimitsAlert = true
      }
  }

  private func recommendationButton(geo: GeometryProxy) -> some View {
    ZStack {
      if isLoadingRecommendation {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .white))
      } else {
        Text(languageService.shortTrendLabel())
          .font(.system(size: 22, weight: .semibold, design: .rounded))
          .foregroundColor(.white)
      }
    }
    .padding()
    .background(Color.gray.opacity(0.8))
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)
    .position(x: geo.size.width - 30, y: geo.size.height / 2)
    .onTapGesture {
      isLoadingRecommendation = true
      GRPCService().getRecommendation(days: 7) { recommendation in
        DispatchQueue.main.async {
          self.recommendationText = recommendation
          self.showRecommendation = true
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
    return HStack {
      Spacer(minLength: 0)
      Text(text)
        .lineLimit(1)
        .truncationMode(.tail)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .minimumScaleFactor(0.85)
        .foregroundColor(.white)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color.gray.opacity(0.8))
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 6)
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
      onPhotoSuccess: {
        fetchDataAfterFoodPhoto()
      },
      onPhotoFailure: {
        // Photo processing failed, no need to fetch data
        isLoadingFoodPhoto = false
      },
      onPhotoStarted: {
        // Photo processing started
        isLoadingFoodPhoto = true
      }
    )
    .buttonStyle(SolidDarkBlueButtonStyle())
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

    // Try to load cached data first for instant display
    if let (cachedProducts, cachedCalories, cachedWeight) = ProductStorageService.shared
      .getCachedDataIfFresh()
    {
      // Update UI immediately with cached data
      products = cachedProducts
      caloriesLeft = cachedCalories
      personWeight = cachedWeight

      // Check if cache is relatively recent (less than 30 minutes)
      if !ProductStorageService.shared.isDataStale(maxAgeMinutes: 30) {
        // Cache is very fresh, no need to show loading or fetch new data
        return
      }

      // Cache is fresh but getting older, refresh in background without loading indicator
      isFetchingData = true
      ProductStorageService.shared.fetchAndProcessProducts(forceRefresh: true) {
        fetchedProducts, calories, weight in
        DispatchQueue.main.async {
          let previousWeight = self.personWeight
          self.products = fetchedProducts
          self.caloriesLeft = calories
          self.personWeight = weight
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

    // No fresh cache available - try fallback to slightly stale data while loading
    if let (fallbackProducts, fallbackCalories, fallbackWeight) = ProductStorageService.shared
      .getCachedDataAsFallback()
    {
      // Show stale data immediately for better UX
      products = fallbackProducts
      caloriesLeft = fallbackCalories
      personWeight = fallbackWeight

      // Show a subtle loading indicator since we're using stale data
      isLoadingData = true
    } else {
      // No cached data at all, show full loading
      isLoadingData = true
    }

    // Fetch fresh data from network
    isFetchingData = true
    ProductStorageService.shared.fetchAndProcessProducts { fetchedProducts, calories, weight in
      DispatchQueue.main.async {
        let previousWeight = self.personWeight
        self.products = fetchedProducts
        self.caloriesLeft = calories
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
  }

  func fetchData() {
    // Prevent multiple simultaneous data fetches
    guard !isFetchingData else { return }

    isFetchingData = true
    // For background updates, always try cache first
    ProductStorageService.shared.fetchAndProcessProducts { fetchedProducts, calories, weight in
      DispatchQueue.main.async {
        let previousWeight = self.personWeight
        self.products = fetchedProducts
        self.caloriesLeft = calories
        self.personWeight = weight
        self.isFetchingData = false

        // Recalculate calories if weight changed and user has health data
        let userDefaults = UserDefaults.standard
        if userDefaults.bool(forKey: "hasUserHealthData"), abs(previousWeight - weight) > 0.1 {
          self.recalculateCalorieLimitsFromHealthData()
        }
        self.refreshMacrosForCurrentView()
      }
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

  func fetchDataAfterFoodPhoto() {
    // Clear today's statistics cache since new food was added
    StatisticsService.shared.clearExpiredCache()

    // Note: ProductStorageService cache is already updated by the fetchAndProcessProducts call
    // that handles the image mapping, so no need to clear it here

    // Always return to today after submitting food photo
    // This will call fetchDataWithLoading() which will show the fresh cached data with the new food item
    returnToToday()

    DispatchQueue.main.async {
      self.isLoadingFoodPhoto = false
    }
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
              foodName, percentage)
          ) {
            // Always return to today after modifying food portion
            self.returnToToday()
          }
        } else {
          // Show error message
          AlertHelper.showAlert(
            title: loc("common.update_failed", "Update Failed"),
            message: loc(
              "portion.update_failed.msg", "Failed to update the food portion. Please try again.")
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
          let imageDeleted = ImageStorageService.shared.deleteImage(forTime: time)

          self.deletingProductTime = nil
          AlertHelper.showAlert(
            title: loc("common.removed", "Removed"),
            message: loc("food.removed.msg", "Food item was removed.")
          ) {
            self.returnToToday()
          }
        } else {
          // Failed to delete product
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
    inputFormatter.dateFormat = "dd-MM-yyyy"
    let displayFormatter = DateFormatter()
    displayFormatter.locale = Locale(identifier: languageService.currentCode)
    displayFormatter.dateStyle = .medium
    displayFormatter.timeStyle = .none

    if let parsedDate = inputFormatter.date(from: dateString) {
      currentViewingDate = displayFormatter.string(from: parsedDate)
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
    currentViewingDate = ""
    currentViewingDateString = ""
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
        message: loc("weight.invalid.msg", "Please enter a valid weight in kilograms."))
      return
    }

    guard let userEmail = authService.userEmail else {
      AlertHelper.showAlert(
        title: loc("common.error", "Error"),
        message: loc("weight.need_login", "Unable to submit weight. Please sign in again."))
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

          // Always return to today after manual weight entry
          self.returnToToday()
          AlertHelper.showAlert(
            title: loc("weight.recorded.title", "Weight Recorded"),
            message: loc("weight.recorded.msg", "Your weight has been successfully recorded."))
        } else {
          AlertHelper.showAlert(
            title: loc("common.error", "Error"),
            message: loc(
              "weight.record_failed.msg", "Failed to record your weight. Please try again."))
        }
      }
    }
  }

  func submitSportCalories() {
    guard let calories = Int(sportCaloriesInput), calories > 0 else {
      AlertHelper.showAlert(
        title: loc("calories.invalid.title", "Invalid Calories"),
        message: loc("calories.invalid.msg", "Please enter a valid number of calories burned."))
      return
    }

    // Store sport calories for today only
    let todayString = getCurrentUTCDateString()
    todaySportCalories = calories
    todaySportCaloriesDate = todayString

    // Clear the input field
    sportCaloriesInput = ""

    // Show success message
    AlertHelper.showAlert(
      title: loc("calories.added.title", "Sport Calories Added"),
      message: String(
        format: loc("calories.added.msg", "Added %d calories to your daily limit for today."),
        calories))
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
    let userDefaults = UserDefaults.standard

    // Check if user has health data and recalculate if needed
    if userDefaults.bool(forKey: "hasUserHealthData") {
      recalculateCalorieLimitsFromHealthData()
    } else {
      // Use saved limits or defaults
      let savedSoftLimit = userDefaults.integer(forKey: "softLimit")
      let savedHardLimit = userDefaults.integer(forKey: "hardLimit")

      // Only use saved values if they exist (not 0)
      if savedSoftLimit > 0 {
        softLimit = savedSoftLimit
      }
      if savedHardLimit > 0 {
        hardLimit = savedHardLimit
      }
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

    // Save to UserDefaults and mark as manually set
    let userDefaults = UserDefaults.standard
    userDefaults.set(softLimit, forKey: "softLimit")
    userDefaults.set(hardLimit, forKey: "hardLimit")
    userDefaults.set(true, forKey: "hasManualCalorieLimits")  // Mark as manually set
  }

  private func resetToHealthBasedLimits() {
    let userDefaults = UserDefaults.standard
    userDefaults.set(false, forKey: "hasManualCalorieLimits")  // Remove manual override
    recalculateCalorieLimitsFromHealthData()  // Recalculate from health data
  }

  private func recalculateCalorieLimitsFromHealthData() {
    let userDefaults = UserDefaults.standard

    // Don't override manually set calorie limits
    let hasManualCalorieLimits = userDefaults.bool(forKey: "hasManualCalorieLimits")
    if hasManualCalorieLimits {
      return
    }

    let height = userDefaults.double(forKey: "userHeight")
    var weight = userDefaults.double(forKey: "userWeight")
    let age = userDefaults.integer(forKey: "userAge")
    let isMale = userDefaults.bool(forKey: "userIsMale")
    let activityLevel = userDefaults.string(forKey: "userActivityLevel") ?? "Sedentary"

    // Use current weight from the app if available and different from stored
    if personWeight > 0 {
      let currentWeight = Double(personWeight)
      if abs(currentWeight - weight) > 0.1 {  // If weight has changed significantly
        weight = currentWeight
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

    // Adjust calories based on weight goal
    let weightDifference = weight - optimalWeight
    let calorieAdjustment: Double

    if abs(weightDifference) < 2 {
      // Maintain current weight
      calorieAdjustment = 0
    } else if weightDifference > 0 {
      // Lose weight - safe deficit of 500 calories per day
      calorieAdjustment = -500
    } else {
      // Gain weight - safe surplus of 300 calories per day
      calorieAdjustment = 300
    }

    let recommendedCalories = Int(tdee + calorieAdjustment)

    // Update the calorie limits
    softLimit = recommendedCalories
    hardLimit = Int(Double(recommendedCalories) * 1.15)  // 15% above recommendation

    // Save updated values
    userDefaults.set(softLimit, forKey: "softLimit")
    userDefaults.set(hardLimit, forKey: "hardLimit")
    userDefaults.set(recommendedCalories, forKey: "userRecommendedCalories")
    userDefaults.set(optimalWeight, forKey: "userOptimalWeight")
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
    if days <= 7 {
      return .red
    } else if days <= 30 {
      return Color.yellow
    } else {
      return .green
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
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }

  private func checkForUTCDateChange() {
    let currentUTCDate = getCurrentUTCDateString()

    if currentUTCDate != lastKnownUTCDate {
      print("UTC date changed from \(lastKnownUTCDate) to \(currentUTCDate) - refreshing data")
      lastKnownUTCDate = currentUTCDate

      // Reset sport calories for the new day
      todaySportCalories = 0
      todaySportCaloriesDate = ""

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

struct SolidDarkBlueButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding()
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 25, style: .continuous)
          .fill(Color.blue.opacity(0.9))
          .shadow(
            color: .black.opacity(configuration.isPressed ? 0.3 : 0.7), radius: 10, x: 5, y: 5)
      )
      .foregroundColor(.white)
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .animation(
        .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0),
        value: configuration.isPressed)
  }
}

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
