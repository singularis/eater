import SwiftUI

struct FullScreenPhotoData: Identifiable {
    let id = UUID()
    let image: UIImage?
    let foodName: String
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
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
    @State private var currentViewingDateString = "" // Original format dd-MM-yyyy
    @State private var showRecommendation = false
    @State private var recommendationText = ""
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    // New loading states
    @State private var isLoadingData = false
    @State private var isLoadingWeightPhoto = false
    @State private var isLoadingFoodPhoto = false
    @State private var deletingProductTime: Int64? = nil
    @State private var isFetchingData = false // Flag to prevent multiple simultaneous data fetches
    
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
    
    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 3) {
                topBarView
                statsButtonsView
                    .frame(height: 60)

                ProductListView(
                    products: products, 
                    onRefresh: refreshAction, 
                    onDelete: deleteProductWithLoading,
                    onModify: modifyProductPortion,
                    onPhotoTap: showFullScreenPhoto,
                    deletingProductTime: deletingProductTime
                )
                .padding(.top, 3)

                cameraButtonView
                    .padding(.top, 10)
            }
            .onAppear {
                loadLimitsFromUserDefaults()
                loadTodaySportCalories()
                fetchDataWithLoading()
                setupDailyRefreshTimer()
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .onDisappear {
                stopDailyRefreshTimer()
            }
            .padding()
            .alert("Set Calorie Limits", isPresented: $showLimitsAlert) {
                VStack {
                    TextField("Soft Limit", text: $tempSoftLimit)
                        .keyboardType(.numberPad)
                    TextField("Hard Limit", text: $tempHardLimit)
                        .keyboardType(.numberPad)
                }
                Button("Save Manual Limits") {
                    saveLimits()
                }
                if UserDefaults.standard.bool(forKey: "hasUserHealthData") {
                    Button("Use Health-Based Calculation") {
                        resetToHealthBasedLimits()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Set your daily calorie limits manually, or use health-based calculation if you have health data.\n\n⚠️ These are general guidelines. Consult a healthcare provider for personalized dietary advice.")
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
                    .opacity(showOnboarding ? 1 : 0)
            )
            
            LoadingOverlay(isVisible: isLoadingData, message: "Loading food data...")
            LoadingOverlay(isVisible: isLoadingFoodPhoto, message: "Analyzing food photo...")
        }
    }
        
    private var topBarView: some View {
        ZStack {
            dateDisplayView
            
            HStack {
                profileButton
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
    
    private var dateDisplayView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text(isViewingCustomDate ? currentViewingDate : dateFormatter.string(from: date))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if isViewingCustomDate {
                        Text("Custom Date")
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
                        Text("Today")
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
            Image(systemName: "info.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .background(Color.white.opacity(0.9))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
    
    private var sportButton: some View {
        Button(action: {
            sportCaloriesInput = ""
            showSportCaloriesAlert = true
        }) {
            Image(systemName: "figure.run")
                .font(.system(size: 24))
                .foregroundColor(.orange)
                .background(Color.white.opacity(0.9))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
        .alert("Sport Calories Bonus", isPresented: $showSportCaloriesAlert) {
            TextField("Calories burned (e.g., 300)", text: $sportCaloriesInput)
                .keyboardType(.numberPad)
            Button("Add to Today's Limit") {
                submitSportCalories()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter the number of calories you burned during your workout. This will be added to your daily calorie limit for today only.")
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
        .confirmationDialog("Record Weight", isPresented: $showWeightActionSheet, titleVisibility: .visible) {
            Button("Take Photo") {
                showCamera = true
            }
            Button("Manual Entry") {
                manualWeightInput = ""
                showManualWeightEntry = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how you'd like to record your weight")
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
        .alert("Enter Weight", isPresented: $showManualWeightEntry) {
            TextField("Weight (kg)", text: $manualWeightInput)
                .keyboardType(.decimalPad)
            Button("Submit") {
                submitManualWeight()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your weight in kilograms")
        }
    }
    
    private func caloriesButton(geo: GeometryProxy) -> some View {
        let adjustedSoftLimit = getAdjustedSoftLimit()
        return Text("Calories: \(adjustedSoftLimit-caloriesLeft)")
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
                Text("Tend")
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
        if let (cachedProducts, cachedCalories, cachedWeight) = ProductStorageService.shared.getCachedDataIfFresh() {
            // Update UI immediately with cached data
            self.products = cachedProducts
            self.caloriesLeft = cachedCalories
            self.personWeight = cachedWeight
            
            // Check if cache is relatively recent (less than 30 minutes)
            if !ProductStorageService.shared.isDataStale(maxAgeMinutes: 30) {
                // Cache is very fresh, no need to show loading or fetch new data
                return
            }
            
            // Cache is fresh but getting older, refresh in background without loading indicator
            isFetchingData = true
            ProductStorageService.shared.fetchAndProcessProducts(forceRefresh: true) { fetchedProducts, calories, weight in
                DispatchQueue.main.async {
                    let previousWeight = self.personWeight
                    self.products = fetchedProducts
                    self.caloriesLeft = calories
                    self.personWeight = weight
                    self.isFetchingData = false
                    
                    // Recalculate calories if weight changed and user has health data
                    let userDefaults = UserDefaults.standard
                    if userDefaults.bool(forKey: "hasUserHealthData") && abs(previousWeight - weight) > 0.1 {
                        self.recalculateCalorieLimitsFromHealthData()
                    }
                }
            }
            return
        }
        
        // No fresh cache available - try fallback to slightly stale data while loading
        if let (fallbackProducts, fallbackCalories, fallbackWeight) = ProductStorageService.shared.getCachedDataAsFallback() {
            // Show stale data immediately for better UX
            self.products = fallbackProducts
            self.caloriesLeft = fallbackCalories
            self.personWeight = fallbackWeight
            
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
                if userDefaults.bool(forKey: "hasUserHealthData") && abs(previousWeight - weight) > 0.1 {
                    self.recalculateCalorieLimitsFromHealthData()
                }
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
                if userDefaults.bool(forKey: "hasUserHealthData") && abs(previousWeight - weight) > 0.1 {
                    self.recalculateCalorieLimitsFromHealthData()
                }
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
            AlertHelper.showAlert(title: "Error", message: "Unable to modify food portion. Please sign in again.")
            return
        }
        
        GRPCService().modifyFoodRecord(time: time, userEmail: userEmail, percentage: percentage) { success in
            DispatchQueue.main.async {
                if success {
                    // Clear both caches since food was modified
                    StatisticsService.shared.clearExpiredCache()
                    ProductStorageService.shared.clearCache()
                    
                    // Show success message
                    AlertHelper.showAlert(
                        title: "Portion Updated", 
                        message: "Successfully updated '\(foodName)' to \(percentage)% portion."
                    ) {
                        // Always return to today after modifying food portion
                        self.returnToToday()
                    }
                } else {
                    // Show error message
                    AlertHelper.showAlert(
                        title: "Update Failed", 
                        message: "Failed to update the food portion. Please try again."
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
                    // No action needed if image deletion fails
                    
                    // Always return to today after deleting food
                    self.returnToToday()
                    self.deletingProductTime = nil
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
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        if let parsedDate = inputFormatter.date(from: dateString) {
            currentViewingDate = displayFormatter.string(from: parsedDate)
        } else {
            currentViewingDate = dateString
        }
        
        ProductStorageService.shared.fetchAndProcessCustomDateProducts(date: dateString) { fetchedProducts, calories, weight in
            DispatchQueue.main.async {
                let previousWeight = self.personWeight
                self.products = fetchedProducts
                self.caloriesLeft = calories
                self.personWeight = weight
                self.isLoadingData = false
                
                // Recalculate calories if weight changed and user has health data
                let userDefaults = UserDefaults.standard
                if userDefaults.bool(forKey: "hasUserHealthData") && abs(previousWeight - weight) > 0.1 {
                    self.recalculateCalorieLimitsFromHealthData()
                }
            }
        }
    }
    
    func returnToToday() {
        isViewingCustomDate = false
        currentViewingDate = ""
        currentViewingDateString = ""
        fetchDataWithLoading()
    }
    
    func showFullScreenPhoto(image: UIImage?, foodName: String) {
        fullScreenPhotoData = FullScreenPhotoData(image: image, foodName: foodName)
    }
    
    func submitManualWeight() {
        // Normalize decimal separator (replace comma with dot for proper Float parsing)
        let normalizedInput = manualWeightInput.replacingOccurrences(of: ",", with: ".")
        
        guard let weight = Float(normalizedInput), weight > 0 else {
            AlertHelper.showAlert(title: "Invalid Weight", message: "Please enter a valid weight in kilograms.")
            return
        }
        
        guard let userEmail = authService.userEmail else {
            AlertHelper.showAlert(title: "Error", message: "Unable to submit weight. Please sign in again.")
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
                    AlertHelper.showAlert(title: "Weight Recorded", message: "Your weight has been successfully recorded.")
                } else {
                    AlertHelper.showAlert(title: "Error", message: "Failed to record your weight. Please try again.")
                }
            }
        }
    }

    func submitSportCalories() {
        guard let calories = Int(sportCaloriesInput), calories > 0 else {
            AlertHelper.showAlert(title: "Invalid Calories", message: "Please enter a valid number of calories burned.")
            return
        }
        
        // Store sport calories for today only
        let todayString = getCurrentUTCDateString()
        todaySportCalories = calories
        todaySportCaloriesDate = todayString
        
        // Clear the input field
        sportCaloriesInput = ""
        
        // Show success message
        AlertHelper.showAlert(title: "Sport Calories Added", message: "Added \(calories) calories to your daily limit for today.")
    }

    // MARK: - Helper Methods

    private func getColor(for value: Int, adjustedSoftLimit: Int) -> Color {
        if value < adjustedSoftLimit {
            return .green
        } else if value < hardLimit {
            return .yellow
        } else {
            return .red
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
              newSoftLimit <= newHardLimit else {
            // Show error if invalid input
            AlertHelper.showAlert(title: "Invalid Input", message: "Please enter valid positive numbers. Soft limit must be less than or equal to hard limit.")
            return
        }
        
        softLimit = newSoftLimit
        hardLimit = newHardLimit
        
        // Save to UserDefaults and mark as manually set
        let userDefaults = UserDefaults.standard
        userDefaults.set(softLimit, forKey: "softLimit")
        userDefaults.set(hardLimit, forKey: "hardLimit")
        userDefaults.set(true, forKey: "hasManualCalorieLimits") // Mark as manually set
    }
    
    private func resetToHealthBasedLimits() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(false, forKey: "hasManualCalorieLimits") // Remove manual override
        recalculateCalorieLimitsFromHealthData() // Recalculate from health data
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
            if abs(currentWeight - weight) > 0.1 { // If weight has changed significantly
                weight = currentWeight
                userDefaults.set(weight, forKey: "userWeight") // Update stored weight
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
        hardLimit = Int(Double(recommendedCalories) * 1.15) // 15% above recommendation
        
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
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.3 : 0.7), radius: 10, x: 5, y: 5)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

#Preview {
    ContentView()
        .environmentObject({
            let authService = AuthenticationService()
            authService.setPreviewState(
                email: "preview@example.com",
                profilePictureURL: "https://lh3.googleusercontent.com/a/default-user=s120-c"
            )
            return authService
        }())
}
