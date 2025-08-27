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
    @EnvironmentObject var languageService: LanguageService
    @State private var selectedLanguageDisplay: String = ""
    @State private var selectedLanguageCode: String = ""
    @State private var isApplyingLanguage: Bool = false
    
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
    
    func localizedActivityLevel(_ level: String) -> String {
        switch level {
        case "Sedentary":
            return loc("health.activity.sedentary", "Sedentary")
        case "Lightly Active":
            return loc("health.activity.lightly", "Lightly Active")
        case "Moderately Active":
            return loc("health.activity.moderately", "Moderately Active")
        case "Very Active":
            return loc("health.activity.very", "Very Active")
        case "Extremely Active":
            return loc("health.activity.extremely", "Extremely Active")
        default:
            return level
        }
    }
    
    let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Choose Language 🌐",
            description: "Pick your preferred language. You can change it later in the tutorial.",
            anchor: "language",
            icon: "globe"
        ),
        OnboardingStep(
            title: loc("onboarding.welcome.title", "Welcome to Eateria! 🍎"),
            description: loc("onboarding.welcome.desc", "Your smart food companion that helps you track calories, monitor weight, and make healthier choices. Let's take a quick tour!"),
            anchor: "welcome",
            icon: "hand.wave.fill"
        ),
        OnboardingStep(
            title: loc("onboarding.recognition.title", "Smart Food Recognition 📸"),
            description: loc("onboarding.recognition.desc", "Simply take a photo of your food and our AI will automatically identify it and log the calories. No more manual searching!"),
            anchor: "addfood",
            icon: "camera.fill"
        ),
        OnboardingStep(
            title: loc("onboarding.tracking.title", "Track Your Progress 📊"),
            description: loc("onboarding.tracking.desc", "Monitor your daily calories with our color-coded system and track your weight by photographing your scale. Everything is automated!"),
            anchor: "tracking",
            icon: "chart.line.uptrend.xyaxis"
        ),
        OnboardingStep(
            title: loc("onboarding.alcohol.title", "Alcohol Tracking 🍷"),
            description: loc("onboarding.alcohol.desc", "See your alcohol history on a calendar. Dots mark days you drank (bigger dot = more drinks). The top wineglass changes color by recency: red (today/last week), yellow (last month), green (older). Tap it to open the calendar."),
            anchor: "alcohol",
            icon: "wineglass.fill"
        ),
        OnboardingStep(
            title: loc("onboarding.friends.title", "Share Meals with Friends 🤝"),
            description: loc("onboarding.friends.desc", "Add friends and share your dishes right from the list. Pick how much they ate (25%, 50%, 75% or custom) and we'll handle the rest."),
            anchor: "share",
            icon: "person.2.fill"
        ),
        OnboardingStep(
            title: loc("onboarding.insights.title", "Get Personalized Insights 💡"),
            description: loc("onboarding.insights.desc", "View your trends, manage your profile, and access health information - all designed to help you reach your wellness goals."),
            anchor: "insights",
            icon: "lightbulb.fill"
        ),
        OnboardingStep(
            title: loc("onboarding.health_setup.title", "Personalized Health Setup 📋"),
            description: loc("onboarding.health_setup.desc", "For the best experience, we can calculate personalized calorie recommendations based on your health data. This is completely optional!"),
            anchor: "health_setup",
            icon: "person.crop.circle.fill"
        ),
        OnboardingStep(
            title: loc("onboarding.health_form.title", "Your Health Data 📝"),
            description: loc("onboarding.health_form.desc", "Please provide your basic health information to get personalized recommendations."),
            anchor: "health_form",
            icon: "heart.fill"
        ),
        OnboardingStep(
            title: loc("onboarding.health_results.title", "Your Personalized Plan 🎯"),
            description: loc("onboarding.health_results.desc", "Based on your data, here are your personalized recommendations for optimal health."),
            anchor: "health_results",
            icon: "target"
        ),
        OnboardingStep(
            title: loc("onboarding.disclaimer.title", "Important Health Disclaimer ⚠️"),
            description: loc("onboarding.disclaimer.desc", "This app is for informational purposes only and not a substitute for professional medical advice. Always consult healthcare providers for personalized dietary guidance and medical decisions."),
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
            title: loc("onboarding.complete.title", "You're All Set! 🎉"),
            description: loc("onboarding.complete.desc", "Ready to start your healthy journey? You can always revisit this tutorial from your profile settings if needed."),
            anchor: "complete",
            icon: "checkmark.circle.fill"
        )
    ]
    
    var body: some View {
        ZStack {
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
                    Button(loc("onboarding.skip", "Skip")) {
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
                if steps[currentStep].anchor == "language" {
                    languageSelectionView
                } else if steps[currentStep].anchor == "health_setup" {
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
        .onAppear {
            // Only set language selection if not already set
            if selectedLanguageCode.isEmpty {
                selectedLanguageCode = languageService.currentCode
                selectedLanguageDisplay = languageService.nativeName(for: languageService.currentCode)
            }
        }
        .alert(loc("onboarding.skip.title", "Skip Onboarding?"), isPresented: $showingSkipConfirmation) {
            Button(loc("onboarding.skip.continue", "Continue Tutorial"), role: .cancel) { }
            Button(loc("onboarding.skip.skip", "Skip")) {
                // Fallback to English if skipping
                LanguageService.shared.setLanguage(code: "en", syncWithBackend: true) { _ in }
                withAnimation(.easeInOut(duration: 0.5)) {
                    isPresented = false
                }
            }
            Button(loc("onboarding.skip.dontshow", "Skip & Don't Show Again")) {
                hasSeenOnboarding = true
                // Fallback to English
                LanguageService.shared.setLanguage(code: "en", syncWithBackend: true) { _ in }
                withAnimation(.easeInOut(duration: 0.5)) {
                    isPresented = false
                }
            }
        } message: {
            Text(loc("onboarding.skip.message", "You can always access this tutorial later from your profile settings."))
        }
        .alert(loc("health.invalid.title", "Invalid Health Data"), isPresented: $showingHealthDataAlert) {
            Button(loc("common.ok", "OK"), role: .cancel) { }
        } message: {
            Text(loc("health.invalid.msg", "Please provide valid values for height (cm), weight (kg), and age (years)."))
        }
    }
    private var languageSelectionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: currentStep)

            Text(loc("onboarding.language.title", "Choose Language 🌐"))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Use discovered languages from Localization folder
            let items = languageService.availableLanguagesDetailed()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.code) { item in
                        Button(action: {
                            selectedLanguageDisplay = item.nativeName
                            selectedLanguageCode = item.code
                        }) {
                            HStack {
                                Text(item.flag)
                                Text(item.nativeName)
                                    .fontWeight(item.nativeName == selectedLanguageDisplay ? .bold : .regular)
                                Spacer()
                                if item.nativeName == selectedLanguageDisplay {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(item.nativeName == selectedLanguageDisplay ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 350)


        }
    }
    
    // MARK: - Helper Methods
    
    private func localizedTitle(for anchor: String) -> String {
        switch anchor {
        case "welcome":
            return loc("onboarding.welcome.title", "Welcome to Eateria! 🍎")
        case "addfood":
            return loc("onboarding.recognition.title", "Smart Food Recognition 📸")
        case "tracking":
            return loc("onboarding.tracking.title", "Track Your Progress 📊")
        case "alcohol":
            return loc("onboarding.alcohol.title", "Alcohol Tracking 🍷")
        case "share":
            return loc("onboarding.friends.title", "Share Meals with Friends 🤝")
        case "insights":
            return loc("onboarding.insights.title", "Get Personalized Insights 💡")
        case "health_setup":
            return loc("onboarding.health_setup.title", "Personalized Health Setup 📋")
        case "health_form":
            return loc("onboarding.health_form.title", "Your Health Data 📝")
        case "health_results":
            return loc("onboarding.health_results.title", "Your Personalized Plan 🎯")
        case "disclaimer":
            return loc("onboarding.disclaimer.title", "Important Health Disclaimer ⚠️")
        case "complete":
            return loc("onboarding.complete.title", "You're All Set! 🎉")
        default:
            return steps[currentStep].title
        }
    }
    
    private func localizedDescription(for anchor: String) -> String {
        switch anchor {
        case "welcome":
            return loc("onboarding.welcome.desc", "Your smart food companion that helps you track calories, monitor weight, and make healthier choices. Let's take a quick tour!")
        case "addfood":
            return loc("onboarding.recognition.desc", "Simply take a photo of your food and our AI will automatically identify it and log the calories. No more manual searching!")
        case "tracking":
            return loc("onboarding.tracking.desc", "Monitor your daily calories with our color-coded system and track your weight by photographing your scale. Everything is automated!")
        case "alcohol":
            return loc("onboarding.alcohol.desc", "See your alcohol history on a calendar. Dots mark days you drank (bigger dot = more drinks). The top wineglass changes color by recency: red (today/last week), yellow (last month), green (older). Tap it to open the calendar.")
        case "share":
            return loc("onboarding.friends.desc", "Add friends and share your dishes right from the list. Pick how much they ate (25%, 50%, 75% or custom) and we'll handle the rest.")
        case "insights":
            return loc("onboarding.insights.desc", "View your trends, manage your profile, and access health information - all designed to help you reach your wellness goals.")
        case "health_setup":
            return loc("onboarding.health_setup.desc", "For the best experience, we can calculate personalized calorie recommendations based on your health data. This is completely optional!")
        case "health_form":
            return loc("onboarding.health_form.desc", "Please provide your basic health information to get personalized recommendations.")
        case "health_results":
            return loc("onboarding.health_results.desc", "Based on your data, here are your personalized recommendations for optimal health.")
        case "disclaimer":
            return loc("onboarding.disclaimer.desc", "This app is for informational purposes only and not a substitute for professional medical advice. Always consult healthcare providers for personalized dietary guidance and medical decisions.")
        case "complete":
            return loc("onboarding.complete.desc", "Ready to start your healthy journey? You can always revisit this tutorial from your profile settings if needed.")
        default:
            return steps[currentStep].description
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
                Text(localizedTitle(for: steps[currentStep].anchor))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(steps[currentStep].anchor == "disclaimer" ? .yellow : .white)
                    .multilineTextAlignment(.center)
                
                // Special styling for disclaimer text
                if steps[currentStep].anchor == "disclaimer" {
                    Text(localizedDescription(for: steps[currentStep].anchor))
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
                    Text(localizedDescription(for: steps[currentStep].anchor))
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
                Text(loc("onboarding.notifications.title", "Stay on Track with Gentle Reminders ⏰"))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(loc("onboarding.notifications.desc", "Enable reminders to snap your meals: breakfast (by 12), lunch (by 17), and dinner (by 21). We’ll only remind you if you haven’t snapped food yet. You can change this later in settings."))
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
                    Text(loc("onboarding.notifications.enable", "Enable Reminders"))
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
                    Text(loc("onboarding.notifications.notnow", "Not Now"))
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
                Text(loc("onboarding.datamode.title", "Choose Your Data Mode 📈"))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(loc("onboarding.datamode.desc", "Pick how much detail you want to see. You can change this later in your profile."))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .opacity(0.9)
                    .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 10) {

                Picker("Mode", selection: $dataDisplayMode) {
                    Text(loc("common.simplified", "Simplified")).font(.system(size: 22, weight: .semibold, design: .rounded)).tag("simplified")
                    Text(loc("common.full", "Full")).font(.system(size: 22, weight: .semibold, design: .rounded)).tag("full")
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
                Button(loc("onboarding.personalize", "Yes, Let's Personalize")) {
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
                
                Button(loc("onboarding.skip_step", "Skip This Step")) {
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
                    Text(loc("health.height", "Height (cm):"))
                        .foregroundColor(.white)
                        .frame(width: 100, alignment: .leading)
                    TextField("175", text: $height)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text(loc("health.weight", "Weight (kg):"))
                        .foregroundColor(.white)
                        .frame(width: 100, alignment: .leading)
                    TextField("70", text: $weight)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text(loc("health.age", "Age (years):"))
                        .foregroundColor(.white)
                        .frame(width: 100, alignment: .leading)
                    TextField("25", text: $age)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text(loc("health.gender", "Gender:"))
                        .foregroundColor(.white)
                        .frame(width: 100, alignment: .leading)
                    Picker("Gender", selection: $isMale) {
                        Text(loc("health.gender.male", "Male")).tag(true)
                        Text(loc("health.gender.female", "Female")).tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("health.activity", "Activity Level:"))
                        .foregroundColor(.white)
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(activityLevels, id: \.self) { level in
                            Text(localizedActivityLevel(level)).tag(level)
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
                    Text(loc("health.optimal_weight", "🎯 Optimal Weight"))
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("\(optimalWeight, specifier: "%.1f") \(loc("units.kg", "kg"))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 8) {
                    Text(loc("health.daily_calorie", "🔥 Daily Calorie Target"))
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("\(recommendedCalories) \(loc("units.kcal", "kcal"))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 8) {
                    Text(loc("health.estimated_timeline", "⏰ Estimated Timeline"))
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
                        
                        // Sync with backend if we haven't already
                        if !selectedLanguageCode.isEmpty {
                            // The language was already applied locally, just sync with backend now
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                languageService.setLanguage(code: selectedLanguageCode, syncWithBackend: true) { _ in }
                            }
                        }
                        
                        // Close the onboarding
                        isPresented = false
                    }) {
                        Text(loc("onboarding.getstarted", "Get Started"))
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        hasSeenOnboarding = true
                        
                        // Sync with backend if we haven't already
                        if !selectedLanguageCode.isEmpty {
                            // The language was already applied locally, just sync with backend now
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                languageService.setLanguage(code: selectedLanguageCode, syncWithBackend: true) { _ in }
                            }
                        }
                        
                        // Close the onboarding
                        isPresented = false
                    }) {
                        Text(loc("onboarding.dontshowagain", "Don't show again"))
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
            } else if steps[currentStep].anchor == "language" {
                // Language selection screen - uses standard navigation
                HStack(spacing: 20) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text(loc("common.back", "Previous"))
                            }
                            .foregroundColor(.white)
                            .opacity(0.8)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Apply selected language and advance
                        let lc = selectedLanguageCode.isEmpty ? languageService.currentCode : selectedLanguageCode
                        
                        // Apply the language change immediately but without backend sync
                        if lc != languageService.currentCode {
                            // Clear the localization cache to force reload with new language
                            languageService.setLanguage(code: lc, syncWithBackend: false) { _ in }
                        }
                        
                        // Store the selection for later backend sync
                        selectedLanguageCode = lc
                        
                        // Small delay to let the language change settle, then advance
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            currentStep += 1
                        }
                    }) {
                        HStack {
                            Text(loc("onboarding.next", "Next"))
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 30)
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
                                Text(loc("common.back", "Previous"))
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
            return loc("onboarding.understand", "I Understand")
        case "health_form":
            return loc("health.calc_plan", "Calculate My Plan")
        default:
            return loc("onboarding.next", "Next")
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
            timeToOptimalWeight = loc("health.goal.maintain", "You are at optimal weight!")
        } else if weightDifference > 0 {
            // Lose weight - safe deficit of 500 calories per day
            calorieAdjustment = -500
            let weeksToGoal = Int(ceil(abs(weightDifference) * 2)) // ~0.5kg per week
            timeToOptimalWeight = String(format: loc("health.goal.weeks", "%d weeks to reach optimal weight"), weeksToGoal)
        } else {
            // Gain weight - safe surplus of 300 calories per day
            calorieAdjustment = 300
            let weeksToGoal = Int(ceil(abs(weightDifference) * 4)) // ~0.25kg per week
            timeToOptimalWeight = String(format: loc("health.goal.weeks", "%d weeks to reach optimal weight"), weeksToGoal)
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