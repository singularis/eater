import SwiftUI

enum ProgressiveOnboardingStep {
  case demographics // Age, Gender
  case measurements // Height, Weight
  case activity // Activity Level -> Result
  case notifications
  case none
}

struct ProgressiveOnboardingView: View {
  let step: ProgressiveOnboardingStep
  @Binding var isPresented: Bool
  var onComplete: () -> Void

  @EnvironmentObject var languageService: LanguageService
  @State private var age: String = UserDefaults.standard.string(forKey: "userAge") ?? ""
  @State private var isMale: Bool = UserDefaults.standard.bool(forKey: "userIsMale")
  @State private var height: String = ""
  @State private var weight: String = ""
  @State private var activityLevel: String = "Sedentary"
  
  // For Activity Step result
  @State private var showingResult = false
  @State private var recommendedCalories: Int = 0
  
  let activityLevels = [
    "Sedentary", "Lightly Active", "Moderately Active", "Very Active", "Extremely Active",
  ]
  
  // Animation state
  @State private var appearAnimation = false

  var body: some View {
    ZStack {
      AppTheme.surface.edgesIgnoringSafeArea(.all)
      
      // Dynamic Background blobs
      GeometryReader { geo in
          Circle()
              .fill(Color.blue.opacity(0.1))
              .frame(width: 200, height: 200)
              .blur(radius: 40)
              .position(x: 0, y: 0)
          
          Circle()
              .fill(Color.purple.opacity(0.1))
              .frame(width: 200, height: 200)
              .blur(radius: 40)
              .position(x: geo.size.width, y: geo.size.height)
      }
      
      VStack(spacing: 24) {
        // Drag Indicator
        Capsule()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 40, height: 5)
            .padding(.top, 10)
        
        Spacer()
        
        // Icon with Pulse
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.1))
                .frame(width: 100, height: 100)
                .scaleEffect(appearAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: appearAnimation)
            
            Image(systemName: iconForStep)
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: step)
        }
        .padding(.bottom, 10)
        
        VStack(spacing: 8) {
            Text(titleForStep)
              .font(.system(size: 28, weight: .bold, design: .rounded))
              .multilineTextAlignment(.center)
              .foregroundColor(AppTheme.textPrimary)
            
            Text(subtitleForStep)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 24)
            
            if step == .notifications {
                 Text(loc("onboarding.notifications.desc", "Enable reminders to snap your meals..."))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal)
            }
        }
        
        contentForStep
            .padding(.vertical, 10)
        
        Spacer()
        
        Button(action: handleNext) {
          Text(buttonTitle)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [AppTheme.accent, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .disabled(!isValid)
        .opacity(isValid ? 1 : 0.6)
      }
    }
    .onAppear {
        loadData()
        withAnimation { appearAnimation = true }
    }
  }
  
  private var iconForStep: String {
    switch step {
    case .demographics: return "person.fill.questionmark"
    case .measurements: return "ruler.fill"
    case .activity: return "figure.run"
    case .notifications: return "bell.badge.fill"
    case .none: return "star"
    }
  }
  
  private var titleForStep: String {
    switch step {
    case .demographics: return loc("prog.demo.title", "Tell us about yourself")
    case .measurements: return loc("prog.meas.title", "Body Measurements")
    case .activity: return loc("prog.act.title", "How active are you?")
    case .notifications: return loc("prog.notif.title", "Stay on Track")
    case .none: return ""
    }
  }
  
  private var subtitleForStep: String {
    switch step {
    case .demographics: return loc("prog.demo.sub", "Unlock personalized stats by answering a few questions.")
    case .measurements: return loc("prog.meas.sub", "This helps us calculate your daily calorie needs.")
    case .activity: return loc("prog.act.sub", "Determine your daily energy expenditure.")
    case .notifications: return loc("prog.notif.sub", "Never miss a meal with smart reminders.")
    case .none: return ""
    }
  }
  
  private var buttonTitle: String {
    switch step {
    case .activity: return showingResult ? loc("common.done", "Done") : loc("prog.calc", "Calculate Plan")
    default: return loc("common.next", "Next")
    }
  }
  
  private var isValid: Bool {
    switch step {
    case .demographics:
      return !age.isEmpty && Int(age) != nil
    case .measurements:
      return !height.isEmpty && !weight.isEmpty && Double(height) != nil && Double(weight) != nil
    case .activity:
      return true
    case .notifications:
      return true
    case .none:
      return true
    }
  }
  
  @ViewBuilder
  private var contentForStep: some View {
    switch step {
    case .demographics:
      VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc("health.age", "Age"))
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            TextField("25", text: $age)
                .keyboardType(.numberPad)
                .padding()
                .background(AppTheme.surfaceAlt)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Gender")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading, 4)
                
            HStack(spacing: 0) {
                ForEach([true, false], id: \.self) { isMaleOption in
                    Button(action: { isMale = isMaleOption }) {
                        Text(isMaleOption ? loc("health.male", "Male") : loc("health.female", "Female"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isMale == isMaleOption ? AppTheme.surface : Color.clear)
                            .foregroundColor(isMale == isMaleOption ? AppTheme.textPrimary : AppTheme.textSecondary)
                            .cornerRadius(10)
                            .shadow(color: isMale == isMaleOption ? Color.black.opacity(0.05) : Color.clear, radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding(4)
            .background(AppTheme.surfaceAlt)
            .cornerRadius(14)
        }
      }
      .padding(.horizontal, 30)
      
    case .measurements:
      VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
             Text(loc("health.height", "Height (cm)"))
                 .font(.caption)
                 .foregroundColor(.gray)
                 .padding(.leading, 4)
             
             TextField("175", text: $height)
                 .keyboardType(.numberPad)
                 .padding()
                 .background(AppTheme.surfaceAlt)
                 .cornerRadius(12)
        }
        
        VStack(alignment: .leading, spacing: 8) {
             Text(loc("health.weight", "Weight (kg)"))
                 .font(.caption)
                 .foregroundColor(.gray)
                 .padding(.leading, 4)
             
             TextField("70", text: $weight)
                 .keyboardType(.decimalPad)
                 .padding()
                 .background(AppTheme.surfaceAlt)
                 .cornerRadius(12)
        }
      }
      .padding(.horizontal, 30)
      
    case .activity:
      if showingResult {
          VStack(spacing: 16) {
              Text(loc("prog.result", "Your Daily Goal"))
                  .font(.headline)
                  .foregroundColor(AppTheme.textSecondary)
              
              Text("\(recommendedCalories)")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [AppTheme.accent, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
              Text("kcal")
                  .font(.title3)
                  .fontWeight(.medium)
                  .foregroundColor(AppTheme.textSecondary)
          }
          .padding(.vertical, 20)
          .transition(.scale.combined(with: .opacity))
      } else {
          VStack(spacing: 8) {
              Text("Select Activity Level")
                  .font(.caption)
                  .foregroundColor(.gray)
              
              Picker("Activity", selection: $activityLevel) {
                ForEach(activityLevels, id: \.self) { level in
                  Text(localizedActivityLevel(level)).tag(level)
                }
              }
              .pickerStyle(.wheel)
              .background(AppTheme.surfaceAlt.opacity(0.5))
              .cornerRadius(16)
          }
          .padding(.horizontal, 24)
      }
      
    case .notifications:
         EmptyView() // Text description handled in header

    case .none:
      EmptyView()
    }
  }
  
  private func loadData() {
      // Load existing values if present to pre-fill
      let defaults = UserDefaults.standard
      if let h = defaults.string(forKey: "userHeight") { height = h } // Stored as Double usually, check types
      // In OnboardingView it was binding to String
      if defaults.double(forKey: "userHeight") > 0 {
          height = String(Int(defaults.double(forKey: "userHeight")))
      }
      if defaults.double(forKey: "userWeight") > 0 {
          weight = String(format: "%.1f", defaults.double(forKey: "userWeight"))
      }
  }
  
  private func handleNext() {
    let defaults = UserDefaults.standard
    switch step {
    case .demographics:
        defaults.set(Int(age) ?? 25, forKey: "userAge")
        defaults.set(isMale, forKey: "userIsMale")
        onComplete()
        
    case .measurements:
        let h = (Double(height) ?? 175).rounded()
        let w = ((Double(weight) ?? 70) * 10).rounded() / 10
        defaults.set(h, forKey: "userHeight")
        defaults.set(w, forKey: "userWeight")
        onComplete()
        
    case .activity:
        if !showingResult {
            defaults.set(activityLevel, forKey: "userActivityLevel")
            calculatePlan()
            showingResult = true
        } else {
            // Check if health setup is complete
            defaults.set(true, forKey: "hasUserHealthData")
            onComplete()
        }
    
    case .notifications:
        NotificationService.shared.requestAuthorizationAndEnable(true) { _ in
            onComplete()
        }
        
    case .none:
        onComplete()
    }
  }
  
  private func calculatePlan() {
      // Logic copied/adapted from OnboardingView/ContentView
      // Simple TDEE calc
      let h = Double(height) ?? (UserDefaults.standard.double(forKey: "userHeight") > 0 ? UserDefaults.standard.double(forKey: "userHeight") : 175)
      let w = Double(weight) ?? (UserDefaults.standard.double(forKey: "userWeight") > 0 ? UserDefaults.standard.double(forKey: "userWeight") : 70)
      let a = Int(age) ?? (UserDefaults.standard.integer(forKey: "userAge") > 0 ? UserDefaults.standard.integer(forKey: "userAge") : 25)
      let male = isMale
      
      let bmr: Double
      if male {
        bmr = 10 * w + 6.25 * h - 5 * Double(a) + 5
      } else {
        bmr = 10 * w + 6.25 * h - 5 * Double(a) - 161
      }
      
      let multiplier: Double
      switch activityLevel {
      case "Sedentary": multiplier = 1.2
      case "Lightly Active": multiplier = 1.375
      case "Moderately Active": multiplier = 1.55
      case "Very Active": multiplier = 1.725
      case "Extremely Active": multiplier = 1.9
      default: multiplier = 1.2
      }
      
      let tdee = bmr * multiplier
      // Deficit 500
      let target = Int(tdee - 500)
      recommendedCalories = max(target, 1200)
      
      // Save
      UserDefaults.standard.set(recommendedCalories, forKey: "userRecommendedCalories")
      // Update limits
      let soft = recommendedCalories
      let hard = Int(Double(soft) * 1.15)
      let limits = CalorieLimitsStorageService.Limits(softLimit: soft, hardLimit: hard, hasManualCalorieLimits: false)
      CalorieLimitsStorageService.shared.save(limits)
      UserDefaults.standard.set(soft, forKey: "softLimit")
      UserDefaults.standard.set(hard, forKey: "hardLimit")
  }

  func localizedActivityLevel(_ level: String) -> String {
    switch level {
    case "Sedentary": return loc("health.activity.sedentary", "Sedentary")
    case "Lightly Active": return loc("health.activity.lightly", "Lightly Active")
    case "Moderately Active": return loc("health.activity.moderately", "Moderately Active")
    case "Very Active": return loc("health.activity.very", "Very Active")
    case "Extremely Active": return loc("health.activity.extremely", "Extremely Active")
    default: return level
    }
  }
}
