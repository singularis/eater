import SwiftUI

struct HealthSettingsView: View {
    @Binding var isPresented: Bool
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var age: String = ""
    @State private var isMale: Bool = true
    @State private var activityLevel: String = "Sedentary"
    @State private var showingHealthDataAlert = false
    
    // Calculated values
    @State private var optimalWeight: Double = 0
    @State private var recommendedCalories: Int = 0
    @State private var timeToOptimalWeight: String = ""
    @State private var showResults = false
    
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
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        if showResults {
                            healthResultsView
                        } else {
                            healthFormView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(showResults ? loc("health.plan.title", "Your Plan") : loc("nav.health_settings", "Health Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(loc("common.cancel", "Cancel")) {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                if showResults {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(loc("common.save", "Save")) {
                            saveHealthData()
                            isPresented = false
                        }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
        .alert(loc("health.invalid.title", "Invalid Health Data"), isPresented: $showingHealthDataAlert) {
            Button(loc("common.ok", "OK"), role: .cancel) { }
        } message: {
            Text(loc("health.invalid.msg", "Please provide valid values for height (cm), weight (kg), and age (years)."))
        }
    }
    
    private var healthFormView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text(loc("health.update.title", "Update Your Health Data"))
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
                    Picker(loc("health.gender", "Gender:"), selection: $isMale) {
                        Text(loc("health.gender.male", "Male")).tag(true)
                        Text(loc("health.gender.female", "Female")).tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("health.activity", "Activity Level:"))
                        .foregroundColor(.white)
                    Picker(loc("health.activity", "Activity Level:"), selection: $activityLevel) {
                        ForEach(activityLevels, id: \.self) { level in
                            Text(localizedActivityLevel(level)).tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .background(Color.white)
                    .cornerRadius(8)
                }
                
                Button(loc("health.calc_plan", "Calculate My Plan")) {
                    if validateAndCalculateHealthData() {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showResults = true
                        }
                    } else {
                        showingHealthDataAlert = true
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(25)
                .padding(.top, 20)
            }
        }
    }
    
    private var healthResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text(loc("health.updated_plan", "Your Updated Plan"))
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
                
                Button(loc("common.back_to_edit", "Back to Edit")) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showResults = false
                    }
                }
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(25)
                .padding(.top, 10)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadExistingData() {
        let userDefaults = UserDefaults.standard
        if userDefaults.bool(forKey: "hasUserHealthData") {
            height = String(userDefaults.double(forKey: "userHeight"))
            weight = String(userDefaults.double(forKey: "userWeight"))
            age = String(userDefaults.integer(forKey: "userAge"))
            isMale = userDefaults.bool(forKey: "userIsMale")
            activityLevel = userDefaults.string(forKey: "userActivityLevel") ?? "Sedentary"
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
        
        return true
    }
    
    private func saveHealthData() {
        guard let heightValue = Double(height),
              let weightValue = Double(weight),
              let ageValue = Int(age) else { return }
        
        let userDefaults = UserDefaults.standard
        userDefaults.set(heightValue, forKey: "userHeight")
        userDefaults.set(weightValue, forKey: "userWeight")
        userDefaults.set(ageValue, forKey: "userAge")
        userDefaults.set(isMale, forKey: "userIsMale")
        userDefaults.set(activityLevel, forKey: "userActivityLevel")
        userDefaults.set(optimalWeight, forKey: "userOptimalWeight")
        userDefaults.set(recommendedCalories, forKey: "userRecommendedCalories")
        userDefaults.set(true, forKey: "hasUserHealthData")
        
        // Only update calorie limits if user hasn't set them manually
        let hasManualCalorieLimits = userDefaults.bool(forKey: "hasManualCalorieLimits")
        if !hasManualCalorieLimits {
            // Set the calorie limits based on recommendations
            let softLimit = recommendedCalories
            let hardLimit = Int(Double(recommendedCalories) * 1.15) // 15% above recommendation
            userDefaults.set(softLimit, forKey: "softLimit")
            userDefaults.set(hardLimit, forKey: "hardLimit")
        }
    }
}

#Preview {
    HealthSettingsView(isPresented: .constant(true))
} 