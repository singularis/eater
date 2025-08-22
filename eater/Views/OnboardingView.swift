import SwiftUI

struct OnboardingStep {
    let title: String
    let description: String
    let anchor: String
    let icon: String
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var showingSkipConfirmation = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var notificationsEnabledLocal: Bool = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    @AppStorage("dataDisplayMode") private var dataDisplayMode: String = "simplified"
    
    // Health data collection state
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var age: String = ""
    @State private var isMale: Bool = true
    @State private var activityLevel: String = "Sedentary"
    @State private var showingHealthDataAlert = false
    @State private var agreedToProvideData = false
    
    // Calculated values
    @State private var optimalWeight: Double = 0
    @State private var recommendedCalories: Int = 0
    @State private var timeToOptimalWeight: String = ""
    
    let activityLevels = ["Sedentary", "Lightly Active", "Moderately Active", "Very Active", "Extremely Active"]
    
    let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Welcome to Eateria! 🍎",
            description: "Your smart food companion that helps you track calories, monitor weight, and make healthier choices. Let's take a quick tour!",
            anchor: "welcome",
            icon: "hand.wave.fill"
        ),
        OnboardingStep(
            title: "Smart Food Recognition 📸",
            description: "Simply take a photo of your food and our AI will automatically identify it and log the calories. No more manual searching!",
            anchor: "addfood",
            icon: "camera.fill"
        ),
        OnboardingStep(
            title: "Track Your Progress 📊",
            description: "Monitor your daily calories with our color-coded system and track your weight by photographing your scale. Everything is automated!",
            anchor: "tracking",
            icon: "chart.line.uptrend.xyaxis"
        ),
        OnboardingStep(
            title: "Share Meals with Friends 🤝",
            description: "Add friends and share your dishes right from the list. Pick how much they ate (25%, 50%, 75% or custom) and we’ll handle the rest.",
            anchor: "share",
            icon: "person.2.fill"
        ),
        OnboardingStep(
            title: "Get Personalized Insights 💡",
            description: "View your trends, manage your profile, and access health information - all designed to help you reach your wellness goals.",
            anchor: "insights",
            icon: "lightbulb.fill"
        ),
        OnboardingStep(
            title: "Personalized Health Setup 📋",
            description: "For the best experience, we can calculate personalized calorie recommendations based on your health data. This is completely optional!",
            anchor: "health_setup",
            icon: "person.crop.circle.fill"
        ),
        OnboardingStep(
            title: "Your Health Data 📝",
            description: "Please provide your basic health information to get personalized recommendations.",
            anchor: "health_form",
            icon: "heart.fill"
        ),
        OnboardingStep(
            title: "Your Personalized Plan 🎯",
            description: "Based on your data, here are your personalized recommendations for optimal health.",
            anchor: "health_results",
            icon: "target"
        ),
        OnboardingStep(
            title: "Important Health Disclaimer ⚠️",
            description: "This app is for informational purposes only and not a substitute for professional medical advice. Always consult healthcare providers for personalized dietary guidance and medical decisions.",
            anchor: "disclaimer",
            icon: "exclamationmark.triangle.fill"
        ),
        OnboardingStep(
            title: "Stay on Track with Gentle Reminders ⏰",
            description: "Enable reminders to snap your meals: breakfast (by 12), lunch (by 17), and dinner (by 21). We’ll only remind you if you haven’t snapped food yet.",
            anchor: "notifications_setup",
            icon: "bell.badge.fill"
        ),
        OnboardingStep(
            title: "Choose Your Data Mode 📈",
            description: "Pick how much detail you want to see. You can change this later in your profile.",
            anchor: "data_mode",
            icon: "slider.horizontal.3"
        ),
        OnboardingStep(
            title: "You're All Set! 🎉",
            description: "Ready to start your healthy journey? You can always revisit this tutorial from your profile settings if needed.",
            anchor: "complete",
            icon: "checkmark.circle.fill"
        )
    ]
    
    var body: some View {
        ZStack {
            // Don't show anything if user has already seen onboarding
            if !hasSeenOnboarding {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                // Header with progress and skip
                HStack {
                    Button("Skip") {
                        showingSkipConfirmation = true
                    }
                    .foregroundColor(.white)
                    .opacity(0.8)
                    
                    Spacer()
                    
                    // Progress indicator
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Circle()
                                .fill(index <= currentStep ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentStep ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: currentStep)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Step counter
                    Text("\(currentStep + 1)/\(steps.count)")
                        .foregroundColor(.white)
                        .opacity(0.8)
                        .font(.caption)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Main content
                if steps[currentStep].anchor == "health_setup" {
                    healthSetupView
                } else if steps[currentStep].anchor == "health_form" {
                    healthFormView
                } else if steps[currentStep].anchor == "health_results" {
                    healthResultsView
                } else if steps[currentStep].anchor == "notifications_setup" {
                    notificationsSetupView
                } else if steps[currentStep].anchor == "data_mode" {
                    dataModeView
                } else {
                    defaultStepView
                }
                
                Spacer()
                
                    // Navigation buttons
                    navigationButtonsView
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            // Automatically dismiss if user has already seen onboarding
            if hasSeenOnboarding {
                isPresented = false
            }
        }
        .alert("Skip Onboarding?", isPresented: $showingSkipConfirmation) {
            Button("Continue Tutorial", role: .cancel) { }
            Button("Skip") {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isPresented = false
                }
            }
            Button("Skip & Don't Show Again") {
                hasSeenOnboarding = true
                withAnimation(.easeInOut(duration: 0.5)) {
                    isPresented = false
                }
            }
        } message: {
            Text("You can always access this tutorial later from your profile settings.")
        }
        .alert("Invalid Health Data", isPresented: $showingHealthDataAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please provide valid values for height (cm), weight (kg), and age (years).")
        }
    }
    
    // MARK: - View Components
    
    private var defaultStepView: some View {
        VStack(spacing: 30) {
            // Icon with special styling for disclaimer
            Image(systemName: steps[currentStep].icon)
                .font(.system(size: 60))
                .foregroundColor(steps[currentStep].anchor == "disclaimer" ? .yellow : .white)
                .symbolEffect(.bounce, value: currentStep)
            
            VStack(spacing: 16) {
                Text(steps[currentStep].title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(steps[currentStep].anchor == "disclaimer" ? .yellow : .white)
                    .multilineTextAlignment(.center)
                
                // Special styling for disclaimer text
                if steps[currentStep].anchor == "disclaimer" {
                    Text(steps[currentStep].description)
                        .font(.body)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow, lineWidth: 2)
                        )
                        .cornerRadius(12)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(steps[currentStep].description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .opacity(0.9)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 30)
        }
    }

    private var notificationsSetupView: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .symbolEffect(.bounce, value: currentStep)

            VStack(spacing: 12) {
                Text("Stay on Track with Gentle Reminders ⏰")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Enable reminders to snap your meals: breakfast (by 12), lunch (by 17), and dinner (by 21). We’ll only remind you if you haven’t snapped food yet. You can change this later in settings.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .opacity(0.9)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 14) {
                Button(action: {
                    NotificationService.shared.requestAuthorizationAndEnable(true) { granted in
                        notificationsEnabledLocal = granted
                        withAnimation(.easeInOut(duration: 0.3)) { currentStep += 1 }
                    }
                }) {
                    Text("Enable Reminders")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(12)
                }

                Button(action: {
                    NotificationService.shared.requestAuthorizationAndEnable(false)
                    notificationsEnabledLocal = false
                    withAnimation(.easeInOut(duration: 0.3)) { currentStep += 1 }
                }) {
                    Text("Not Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 30)
        }
    }

    private var dataModeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 60))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: currentStep)

            VStack(spacing: 12) {
                Text("Choose Your Data Mode 📈")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Pick how much detail you want to see. You can change this later in your profile.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .opacity(0.9)
                    .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 10) {

                Picker("Mode", selection: $dataDisplayMode) {
                    Text("Simplified").font(.system(size: 22, weight: .semibold, design: .rounded)).tag("simplified")
                    Text("Full").font(.system(size: 22, weight: .semibold, design: .rounded)).tag("full")
                }
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .controlSize(.large)
                .pickerStyle(SegmentedPickerStyle())
                .background(Color.white.opacity(0.15))
                .cornerRadius(10)
            }
        }
    }
    
    private var healthSetupView: some View {
        VStack(spacing: 30) {
            Image(systemName: steps[currentStep].icon)
                .font(.system(size: 60))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: currentStep)
            
            VStack(spacing: 16) {
                Text(steps[currentStep].title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(steps[currentStep].description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .opacity(0.9)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
            
            VStack(spacing: 16) {
                Button("Yes, Let's Personalize") {
                    agreedToProvideData = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep += 1
                    }
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(12)
                
                Button("Skip This Step") {
                    agreedToProvideData = false
                    // Skip to disclaimer (skip health form and results)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = steps.firstIndex { $0.anchor == "disclaimer" } ?? currentStep + 1
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
            }
            .padding(.horizontal, 30)
        }
    }
    
    private var healthFormView: some View {
        VStack(spacing: 20) {
            Image(systemName: steps[currentStep].icon)
                .font(.system(size: 60))
                .foregroundColor(.red)
                .symbolEffect(.bounce, value: currentStep)
            
            Text(steps[currentStep].title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                HStack {
                    Text("Height (cm):")
                        .foregroundColor(.white)
                        .frame(width: 100, alignment: .leading)
                    TextField("175", text: $height)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text("Weight (kg):")
                        .foregroundColor(.white)
                        .frame(width: 100, alignment: .leading)
                    TextField("70", text: $weight)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text("Age (years):")
                        .foregroundColor(.white)
                        .frame(width: 100, alignment: .leading)
                    TextField("25", text: $age)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text("Gender:")
                        .foregroundColor(.white)
                        .frame(width: 100, alignment: .leading)
                    Picker("Gender", selection: $isMale) {
                        Text("Male").tag(true)
                        Text("Female").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity Level:")
                        .foregroundColor(.white)
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(activityLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .background(Color.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 30)
        }
    }
    
    private var healthResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: steps[currentStep].icon)
                .font(.system(size: 60))
                .foregroundColor(.green)
                .symbolEffect(.bounce, value: currentStep)
            
            Text(steps[currentStep].title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("🎯 Optimal Weight")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("\(optimalWeight, specifier: "%.1f") kg")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 8) {
                    Text("🔥 Daily Calorie Target")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("\(recommendedCalories) kcal")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 8) {
                    Text("⏰ Estimated Timeline")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text(timeToOptimalWeight)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 30)
        }
    }
    
    private var navigationButtonsView: some View {
        VStack(spacing: 16) {
            if currentStep == steps.count - 1 {
                // Last screen - show both options
                VStack(spacing: 12) {
                    Button(action: {
                        // Mark onboarding as seen when user completes it
                        hasSeenOnboarding = true
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isPresented = false
                        }
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        hasSeenOnboarding = true
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isPresented = false
                        }
                    }) {
                        Text("Don't show again")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.yellow.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.yellow, lineWidth: 2)
                            )
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 30)
            } else if steps[currentStep].anchor == "health_setup" {
                // Health setup screen - buttons are handled in the view itself
                EmptyView()
            } else if steps[currentStep].anchor == "notifications_setup" {
                // Notifications setup screen - buttons handled in view
                EmptyView()
            } else {
                // Navigation buttons for other screens
                HStack(spacing: 20) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .foregroundColor(.white)
                            .opacity(0.8)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if steps[currentStep].anchor == "health_form" {
                            // Validate and calculate before proceeding
                            if validateAndCalculateHealthData() {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep += 1
                                }
                            } else {
                                showingHealthDataAlert = true
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        }
                    }) {
                        HStack {
                            Text(getNextButtonText())
                            if steps[currentStep].anchor != "disclaimer" && steps[currentStep].anchor != "health_form" {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(getNextButtonTextColor())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(getNextButtonBackgroundColor())
                        .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 30)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getNextButtonText() -> String {
        switch steps[currentStep].anchor {
        case "disclaimer":
            return "I Understand"
        case "health_form":
            return "Calculate My Plan"
        default:
            return "Next"
        }
    }
    
    private func getNextButtonTextColor() -> Color {
        switch steps[currentStep].anchor {
        case "disclaimer":
            return .red
        case "health_form":
            return .white
        default:
            return .blue
        }
    }
    
    private func getNextButtonBackgroundColor() -> Color {
        switch steps[currentStep].anchor {
        case "disclaimer":
            return Color.yellow
        case "health_form":
            return Color.green
        default:
            return Color.white
        }
    }
    
    private func validateAndCalculateHealthData() -> Bool {
        guard let heightValue = Double(height),
              let weightValue = Double(weight),
              let ageValue = Int(age),
              heightValue > 0,
              weightValue > 0,
              ageValue > 0 else {
            return false
        }
        
        // Calculate optimal weight using BMI (21.5 - middle of healthy range)
        let heightInMeters = heightValue / 100.0
        optimalWeight = 21.5 * heightInMeters * heightInMeters
        
        // Calculate BMR using Mifflin-St Jeor Equation
        let bmr: Double
        if isMale {
            bmr = 10 * weightValue + 6.25 * heightValue - 5 * Double(ageValue) + 5
        } else {
            bmr = 10 * weightValue + 6.25 * heightValue - 5 * Double(ageValue) - 161
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
        let weightDifference = weightValue - optimalWeight
        let calorieAdjustment: Double
        
        if abs(weightDifference) < 2 {
            // Maintain current weight
            calorieAdjustment = 0
            timeToOptimalWeight = "You are at optimal weight!"
        } else if weightDifference > 0 {
            // Lose weight - safe deficit of 500 calories per day
            calorieAdjustment = -500
            let weeksToGoal = Int(ceil(abs(weightDifference) * 2)) // ~0.5kg per week
            timeToOptimalWeight = "\(weeksToGoal) weeks to reach optimal weight"
        } else {
            // Gain weight - safe surplus of 300 calories per day
            calorieAdjustment = 300
            let weeksToGoal = Int(ceil(abs(weightDifference) * 4)) // ~0.25kg per week
            timeToOptimalWeight = "\(weeksToGoal) weeks to reach optimal weight"
        }
        
        recommendedCalories = Int(tdee + calorieAdjustment)
        
        // Save the calculated values to UserDefaults
        saveHealthData(heightValue: heightValue, 
                      weightValue: weightValue, 
                      ageValue: ageValue,
                      isMale: isMale,
                      activityLevel: activityLevel,
                      optimalWeight: optimalWeight,
                      recommendedCalories: recommendedCalories)
        
        return true
    }
    
    private func saveHealthData(heightValue: Double, weightValue: Double, ageValue: Int, 
                               isMale: Bool, activityLevel: String, optimalWeight: Double, 
                               recommendedCalories: Int) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(heightValue, forKey: "userHeight")
        userDefaults.set(weightValue, forKey: "userWeight")
        userDefaults.set(ageValue, forKey: "userAge")
        userDefaults.set(isMale, forKey: "userIsMale")
        userDefaults.set(activityLevel, forKey: "userActivityLevel")
        userDefaults.set(optimalWeight, forKey: "userOptimalWeight")
        userDefaults.set(recommendedCalories, forKey: "userRecommendedCalories")
        userDefaults.set(true, forKey: "hasUserHealthData")
        
        // Set the calorie limits based on recommendations
        let softLimit = recommendedCalories
        let hardLimit = Int(Double(recommendedCalories) * 1.15) // 15% above recommendation
        userDefaults.set(softLimit, forKey: "softLimit")
        userDefaults.set(hardLimit, forKey: "hardLimit")
    }
} 