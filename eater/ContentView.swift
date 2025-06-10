import SwiftUI

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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    // New loading states
    @State private var isLoadingData = false
    @State private var isLoadingWeightPhoto = false
    @State private var isLoadingFoodPhoto = false
    @State private var deletingProductTime: Int64? = nil
    
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
                    deletingProductTime: deletingProductTime
                )
                .padding(.top, 3)

                cameraButtonView
                    .padding(.top, 10)
            }
            .onAppear {
                loadLimitsFromUserDefaults()
                fetchDataWithLoading()
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .padding()
            .alert("Set Calorie Limits", isPresented: $showLimitsAlert) {
                VStack {
                    TextField("Soft Limit", text: $tempSoftLimit)
                        .keyboardType(.numberPad)
                    TextField("Hard Limit", text: $tempHardLimit)
                        .keyboardType(.numberPad)
                }
                Button("Save") {
                    saveLimits()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Set your daily calorie soft limit (yellow warning) and hard limit (red warning).\n\n⚠️ These are general guidelines. Consult a healthcare provider for personalized dietary advice. Tap the info button for sources and disclaimers.")
            }
            .sheet(isPresented: $showUserProfile) {
                UserProfileView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showHealthDisclaimer) {
                HealthDisclaimerView()
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
            .overlay(
                OnboardingView(isPresented: $showOnboarding)
                    .opacity(showOnboarding ? 1 : 0)
            )
            
            LoadingOverlay(isVisible: isLoadingData, message: "Loading food data...")
            LoadingOverlay(isVisible: isLoadingFoodPhoto, message: "Analyzing food photo...")
        }
    }
    
    // MARK: - View Components
    
    private var topBarView: some View {
        HStack {
            profileButton
            Spacer()
            dateDisplayView
            Spacer()
            healthInfoButton
        }
    }
    
    private var profileButton: some View {
        Button(action: {
            showUserProfile = true
        }) {
            ProfileImageView(
                profilePictureURL: authService.userProfilePictureURL,
                size: 30,
                fallbackIconColor: .white
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
    
    private var statsButtonsView: some View {
        GeometryReader { geo in
            weightButton(geo: geo)
            caloriesButton(geo: geo)
            recommendationButton(geo: geo)
        }
    }
    
    private func weightButton(geo: GeometryProxy) -> some View {
        Button(action: {
            showCamera = true
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
        .sheet(isPresented: $showCamera) {
            WeightCameraView(
                onPhotoSuccess: {
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
    }
    
    private func caloriesButton(geo: GeometryProxy) -> some View {
        Text("Calories: \(softLimit-caloriesLeft)")
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundColor(getColor(for: caloriesLeft))
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
                    AlertHelper.showHealthRecommendation(recommendation: recommendation)
                    isLoadingRecommendation = false
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
            // Always return to today when user pulls to refresh
            returnToToday()
        }
    }

    // MARK: - Data Fetching Methods

    func fetchDataWithLoading() {
        isLoadingData = true
        ProductStorageService.shared.fetchAndProcessProducts { fetchedProducts, calories, weight in
            DispatchQueue.main.async {
                self.products = fetchedProducts
                self.caloriesLeft = calories
                self.personWeight = weight
                self.isLoadingData = false
            }
        }
    }
    

    
    func fetchData() {
        ProductStorageService.shared.fetchAndProcessProducts { fetchedProducts, calories, weight in
            DispatchQueue.main.async {
                self.products = fetchedProducts
                self.caloriesLeft = calories
                self.personWeight = weight
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
    


    func deleteProductWithLoading(time: Int64) {
        deletingProductTime = time
        GRPCService().deleteFood(time: Int64(time)) { success in
            DispatchQueue.main.async {
                if success {
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
                self.products = fetchedProducts
                self.caloriesLeft = calories
                self.personWeight = weight
                self.isLoadingData = false
            }
        }
    }
    

    
    func returnToToday() {
        isViewingCustomDate = false
        currentViewingDate = ""
        currentViewingDateString = ""
        fetchDataWithLoading()
    }

    func fetchDataAfterFoodPhoto() {
        // Always return to today after submitting food photo
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

    // MARK: - Helper Methods

    private func getColor(for value: Int) -> Color {
        if value < softLimit {
            return .green
        } else if value < hardLimit {
            return .yellow
        } else {
            return .red
        }
    }

    private func loadLimitsFromUserDefaults() {
        let userDefaults = UserDefaults.standard
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
        
        // Save to UserDefaults
        let userDefaults = UserDefaults.standard
        userDefaults.set(softLimit, forKey: "softLimit")
        userDefaults.set(hardLimit, forKey: "hardLimit")
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
