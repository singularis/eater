import SwiftUI

struct OnboardingStep {
  let title: String
  let description: String
  let anchor: String
  let icon: String
}

struct OnboardingView: View {
  @Binding var isPresented: Bool
  var mode: OnboardingMode = .initial // Default to initial
  
  enum OnboardingMode {
      case initial
      case health
      case social
  }
  
  @SceneStorage("onboardingCurrentStep") private var currentStep = 0
  @State private var showingSkipConfirmation = false
  @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
  @AppStorage("health_onboarding_shown") private var healthOnboardingShown: Bool = false
  @AppStorage("social_onboarding_shown") private var socialOnboardingShown: Bool = false
  @State private var notificationsEnabledLocal: Bool = UserDefaults.standard.bool(
    forKey: "notificationsEnabled")
  @AppStorage("dataDisplayMode") private var dataDisplayMode: String = "simplified"
  @EnvironmentObject var languageService: LanguageService
  @StateObject private var themeService = ThemeService.shared
  @State private var selectedLanguageDisplay: String = ""
  @State private var selectedLanguageCode: String = ""
  @State private var isApplyingLanguage: Bool = false
  
  // Nickname State
  @AppStorage("user_nickname") private var savedNickname: String = ""
  @State private var nickname: String = ""
  @State private var isNicknameLoading: Bool = false
  @State private var nicknameError: String? = nil

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

  let activityLevels = [
    "Sedentary", "Lightly Active", "Moderately Active", "Very Active", "Extremely Active",
  ]

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

  var steps: [OnboardingStep] {
      switch mode {
      case .initial:
          return [
            OnboardingStep(
              title: loc("onboarding.tools.title", "Your Essential Tools 🍽️"),
              description: loc("onboarding.tools.desc", "Small steps that make a big difference."),
              anchor: "tools",
              icon: "scalemass.fill"
            ),
            OnboardingStep(
              title: loc("onboarding.pets.title", "Meet Your Pet Companion 🐾"),
              description: loc("onboarding.pets.desc", "Choose a pet that will motivate you on your journey."),
              anchor: "pets",
              icon: "pawprint.fill"
            ),
            OnboardingStep(
              title: loc("onboarding.new_features.title", "New Features ✨"),
              description: loc("onboarding.new_features.subtitle", "Powerful tools to make your tracking even better."),
              anchor: "smart_tips",
              icon: "sparkles"
            ),
            OnboardingStep(
              title: loc("onboarding.features.title", "All in one Tracker 🚀"),
              description: loc("onboarding.features.desc", "Everything you need to stay healthy, powered by AI."),
              anchor: "features",
              icon: "square.stack.3d.up.fill"
            ),
            OnboardingStep(
              title: loc("disc.title", "Health Information Disclaimer"),
              description: loc(
                "disc.notice.text",
                "This app provides general nutritional information and dietary suggestions for educational purposes only. The information is not intended to replace professional medical advice, diagnosis, or treatment."
              ),
              anchor: "disclaimer",
              icon: "exclamationmark.triangle.fill"
            ),
          ]
      case .health:
          return [
              OnboardingStep(
                  title: loc("onboarding.health_setup.title", "Personalized Health Setup 📋"),
                  description: loc("onboarding.health_setup.desc", "For the best experience, we can calculate personalized calorie recommendations based on your health data. This is completely optional!"),
                  anchor: "health_setup",
                  icon: "heart.text.square.fill"
              ),
              OnboardingStep(
                  title: loc("onboarding.health_form.title", "Your Health Data 📝"),
                  description: loc("onboarding.health_form.desc", "Please provide your basic health information to get personalized recommendations."),
                  anchor: "health_form",
                  icon: "list.clipboard.fill"
              ),
              OnboardingStep(
                  title: loc("onboarding.health_results.title", "Your Personalized Plan 🎯"),
                  description: loc("onboarding.health_results.desc", "Based on your data, here are your personalized recommendations for optimal health."),
                  anchor: "health_results",
                  icon: "chart.bar.doc.horizontal.fill"
              )
          ]
      case .social:
          return [
              OnboardingStep(
                  title: loc("onboarding.friends.title", "Share Meals with Friends 🤝"),
                  description: loc("onboarding.friends.desc", "Add friends and share your dishes right from the list. Pick how much they ate and we'll handle the rest."),
                  anchor: "share",
                  icon: "person.2.fill"
              ),
              OnboardingStep(
                  title: loc("nickname.title", "Set Your Nickname"),
                  description: loc("nickname.description", "Choose a nickname to share with friends instead of your email address."),
                  anchor: "nickname",
                  icon: "person.text.rectangle.fill"
              )
          ]
      }
  }

  // ... (body code remains similar, verifying body update) ...
  // I must be careful not to overwrite the body I just beautified.
  // The user asked to ALIGN.
  // I will just update the 'steps' and the 'defaultStepView' logic.
  
  // Renamed to handle index
  private func defaultStepView(for index: Int) -> some View {
    let step = steps[index]
    
    if step.anchor == "tools" {
        return AnyView(toolsStepView)
    }
    
    if step.anchor == "pets" {
        return AnyView(petThemeStepView)
    }
    
    if step.anchor == "smart_tips" {
        return AnyView(smartTipsStepView)
    }
    
    if step.anchor == "language" {
        return AnyView(languageSelectionView)
    }
    
    if step.anchor == "features" {
        return AnyView(featuresStepView)
    }
    
    if step.anchor == "nickname" {
        return AnyView(nicknameStepView)
    }
    
    if step.anchor == "disclaimer" {
        return AnyView(disclaimerStepView)
    }

    if step.anchor == "health_form" {
         return AnyView(healthFormStepView)
    }

    if step.anchor == "health_results" {
         return AnyView(healthResultsStepView)
    }
    
    return AnyView(VStack(spacing: 30) {
      Spacer()
        
      // Hero Icon
      ZStack {
        // Glowing background effect
        ForEach(0..<3) { i in
            Circle()
                .stroke(AppTheme.accent.opacity(0.2 - Double(i) * 0.05), lineWidth: 2)
                .frame(width: 120 + CGFloat(i * 20), height: 120 + CGFloat(i * 20))
        }
        
        Circle()
            .fill(AppTheme.surface)
            .frame(width: 120, height: 120)
            .shadow(color: AppTheme.accent.opacity(0.2), radius: 10, x: 0, y: 5)

        Image(systemName: step.icon)
            .font(.system(size: 50))
            .foregroundStyle(
                LinearGradient(
                    colors: [AppTheme.accent, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .symbolEffect(.bounce.byLayer, options: .repeating, value: true)
      }
      .padding(.bottom, 20)

      VStack(spacing: 16) {
        Text(localizedTitle(for: step.anchor))
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
          .foregroundColor(AppTheme.textPrimary)
          .fixedSize(horizontal: false, vertical: true)

        Text(localizedDescription(for: step.anchor))
          .font(.system(size: 18, weight: .regular, design: .rounded))
          .multilineTextAlignment(.center)
          .foregroundColor(AppTheme.textSecondary)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 20)
      
      Spacer()
    }
    .padding(.horizontal, 24))
  }
  
  private var toolsStepView: some View {
    VStack(spacing: 16) {
      // Title
      Text(loc("onboarding.tools.title", "Your Essential Tools 🍽️"))
        .font(.system(size: 34, weight: .bold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.top, 10)

      // Subtitle
      Text(loc("onboarding.tools.subtitle", "These are small but very important steps toward healthier eating."))
        .font(.system(size: 18, weight: .regular, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
        .multilineTextAlignment(.center)
        .lineSpacing(4)
        .padding(.horizontal, 24)

      // --- Kitchen Scales Card ---
      HStack(spacing: 14) {
        Image("onboarding_kitchen_scales")
          .resizable()
          .scaledToFit()
          .frame(width: 80, height: 80)
          .padding(6)
          .background(AppTheme.surfaceAlt)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          Text(loc("onboarding.tools.scales.title", "Kitchen Scales"))
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)

          Text(loc("onboarding.tools.scales.desc", "Weigh your food to understand real portions. You will be surprised how much a \"small\" serving actually weighs."))
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.surface)
      .cornerRadius(18)
      .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
      .padding(.horizontal, 20)

      // --- Food Containers Card ---
      HStack(spacing: 14) {
        Image("onboarding_food_containers")
          .resizable()
          .scaledToFit()
          .frame(width: 80, height: 80)
          .padding(6)
          .background(AppTheme.surfaceAlt)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          Text(loc("onboarding.tools.containers.title", "Food Containers"))
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)

          Text(loc("onboarding.tools.containers.desc", "Organize meals so nothing goes to waste. Containers make meal prep effortless and keep your eating structured."))
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.surface)
      .cornerRadius(18)
      .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
      .padding(.horizontal, 20)

      // --- Track Everything reminder ---
      VStack(spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(.green)

          Text(loc("onboarding.tools.track.title", "Track Everything"))
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
        }

        Text(loc("onboarding.tools.track.desc", "Even if something seems less healthy, keep tracking! No judgment, no stopping. That is the path to a balanced relationship with food. Every step toward awareness matters."))
          .font(.system(size: 15, weight: .regular, design: .rounded))
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(14)
      .frame(maxWidth: .infinity)
      .background(Color.green.opacity(0.06))
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.green.opacity(0.2), lineWidth: 1)
      )
      .padding(.horizontal, 20)

      Spacer()
    }
  }

  private var petThemeStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 20) {
        // Title with paws inline
        HStack(spacing: 6) {
          Text(loc("onboarding.pets.title_short", "Meet Your Pet Companion"))
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
          Image(systemName: "pawprint.fill")
            .font(.system(size: 22))
            .foregroundColor(AppTheme.textPrimary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.top, 16)

        Text(loc("onboarding.pets.subtitle", "Pick a furry friend that will motivate you every day!"))
          .font(.system(size: 17, weight: .regular, design: .rounded))
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
          .lineSpacing(3)
          .padding(.horizontal, 24)

        // --- British Cat ---
        VStack(spacing: 12) {
          HStack(spacing: 10) {
            if let catImg = AppMascot.cat.happyImage() {
              Image(catImg)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
              Text("British Cat")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
              Text(loc("onboarding.pets.cat.desc", "Elegant and opinionated. Purrs when you eat well, hisses when you don't."))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            }
          }

          // Cat moods preview (centered)
          HStack(spacing: 14) {
            Spacer()
            PetMoodBubble(imageName: "british_cat_happy", label: loc("onboarding.pets.mood.happy", "Happy"))
            PetMoodBubble(imageName: "british_cat_gym", label: loc("onboarding.pets.mood.gym", "Gym"))
            PetMoodBubble(imageName: "british_cat_bad_food", label: loc("onboarding.pets.mood.upset", "Upset"))
            PetMoodBubble(imageName: "british_cat_alcohol", label: loc("onboarding.pets.mood.alcohol_tracking", "Alcohol"))
            Spacer()
          }

          // Choose cat button
          Button(action: {
            HapticsService.shared.select()
            themeService.currentMascot = .cat
            themeService.playSound(for: "happy")
          }) {
            Text(themeService.currentMascot == .cat
              ? loc("onboarding.pets.cat.chosen", "You chose the cat! 🐱")
              : loc("onboarding.pets.cat.choose", "Choose me if you are a cat person!"))
              .font(.system(size: 15, weight: .semibold, design: .rounded))
              .foregroundColor(themeService.currentMascot == .cat ? .white : AppTheme.textPrimary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(
                themeService.currentMascot == .cat
                  ? AnyShapeStyle(LinearGradient(colors: [AppTheme.accent, Color.purple], startPoint: .leading, endPoint: .trailing))
                  : AnyShapeStyle(AppTheme.surfaceAlt)
              )
              .cornerRadius(14)
          }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .overlay(
          RoundedRectangle(cornerRadius: 18)
            .stroke(themeService.currentMascot == .cat ? AppTheme.accent : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, 20)

        // --- French Bulldog ---
        VStack(spacing: 12) {
          HStack(spacing: 10) {
            if let dogImg = AppMascot.dog.happyImage() {
              Image(dogImg)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
              Text("French Bulldog")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
              Text(loc("onboarding.pets.dog.desc", "Loyal and expressive. Barks with joy for healthy meals, growls at junk food."))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            }
          }

          // Dog moods preview (centered)
          HStack(spacing: 14) {
            Spacer()
            PetMoodBubble(imageName: "french_bulldog_happy", label: loc("onboarding.pets.mood.happy", "Happy"))
            PetMoodBubble(imageName: "french_bulldog_gym", label: loc("onboarding.pets.mood.gym", "Gym"))
            PetMoodBubble(imageName: "french_bulldog_bad_food", label: loc("onboarding.pets.mood.upset", "Upset"))
            PetMoodBubble(imageName: "french_bulldog_alcohol", label: loc("onboarding.pets.mood.alcohol_tracking", "Alcohol"))
            Spacer()
          }

          // Choose dog button
          Button(action: {
            HapticsService.shared.select()
            themeService.currentMascot = .dog
            themeService.playSound(for: "happy")
          }) {
            Text(themeService.currentMascot == .dog
              ? loc("onboarding.pets.dog.chosen", "You chose the dog! 🐶")
              : loc("onboarding.pets.dog.choose", "Choose me if you are a dog lover!"))
              .font(.system(size: 15, weight: .semibold, design: .rounded))
              .foregroundColor(themeService.currentMascot == .dog ? .white : AppTheme.textPrimary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(
                themeService.currentMascot == .dog
                  ? AnyShapeStyle(LinearGradient(colors: [AppTheme.accent, Color.purple], startPoint: .leading, endPoint: .trailing))
                  : AnyShapeStyle(AppTheme.surfaceAlt)
              )
              .cornerRadius(14)
          }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .overlay(
          RoundedRectangle(cornerRadius: 18)
            .stroke(themeService.currentMascot == .dog ? AppTheme.accent : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, 20)

        // --- What your pet does ---
        VStack(spacing: 10) {
          Text(loc("onboarding.pets.features.title", "What Your Pet Does"))
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)

          VStack(alignment: .leading, spacing: 8) {
            PetFeatureRow(icon: "speaker.wave.2.fill", color: .blue,
              text: loc("onboarding.pets.feature.sounds", "Reacts with real sounds to your food choices"))
            PetFeatureRow(icon: "face.smiling.fill", color: .green,
              text: loc("onboarding.pets.feature.happy", "Cheerful sounds when you eat healthy"))
            PetFeatureRow(icon: "exclamationmark.bubble.fill", color: .orange,
              text: loc("onboarding.pets.feature.upset", "Upset sounds for less healthy picks"))
            PetFeatureRow(icon: "message.fill", color: .purple,
              text: loc("onboarding.pets.feature.messages", "Unique motivational messages in your language"))
            PetFeatureRow(icon: "pawprint.fill", color: AppTheme.accent,
              text: loc("onboarding.pets.feature.icons", "Custom themed icons throughout the app"))
          }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(16)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 20)

        Spacer().frame(height: 8)
      }
    }
  }

  private var smartTipsStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 18) {
        // Title
        Text(loc("onboarding.new_features.title", "New Features ✨"))
          .font(.system(size: 30, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 20)
          .padding(.top, 12)

        Text(loc("onboarding.new_features.subtitle", "Powerful tools to make your tracking even better."))
          .font(.system(size: 16, weight: .regular, design: .rounded))
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
          .lineSpacing(3)
          .padding(.horizontal, 24)

        // --- 1. Try Manually ---
        VStack(spacing: 10) {
          HStack(spacing: 10) {
            ZStack {
              Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 44, height: 44)
              Image(systemName: "hand.tap.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
            }
            Text(loc("onboarding.tips.try_manual.title", "Try Manually"))
              .font(.system(size: 18, weight: .bold, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)
            Spacer()
          }

          Text(loc("onboarding.tips.try_manual.desc", "If the AI recognized a dish differently from what you actually ate, just tap on it and select \"Try manually\". You can then type the correct food name, adjust the portion, or update ingredients. The app will recalculate everything for you."))
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .padding(.horizontal, 20)

        // --- 2. Additional (coffee example) ---
        VStack(spacing: 10) {
          HStack(spacing: 10) {
            ZStack {
              Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 44, height: 44)
              Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            }
            Text(loc("onboarding.tips.addons.title", "Additional Add ons"))
              .font(.system(size: 18, weight: .bold, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)
            Spacer()
          }

          Text(loc("onboarding.tips.addons.desc2", "Tap any food and select \"Additional\" to see what you can add. For example, with coffee you can choose lemon 5g, honey 10g, milk 50g, or sugar. Each add on changes the healthiness score so you can compare: coffee with sugar (score 65) versus coffee with lemon (score 89). Works with sushi, tea, and many other dishes!"))
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .padding(.horizontal, 20)

        // --- 3. Target Setting ---
        VStack(spacing: 10) {
          HStack(spacing: 10) {
            ZStack {
              Circle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 44, height: 44)
              Image(systemName: "target")
                .font(.system(size: 20))
                .foregroundColor(.green)
            }
            Text(loc("onboarding.tips.target.title", "Your Personal Plan"))
              .font(.system(size: 18, weight: .bold, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)
            Spacer()
          }

          Text(loc("onboarding.tips.target.desc", "Set your target weight and choose your activity level. The app will calculate a personalized plan with a timeline just for you. BMI is kept safe and never drops below 18.5. You can also pick an \"activity only\" option that focuses on weight loss through exercise rather than dietary changes. It is fully tailored to your real life situation!"))
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .padding(.horizontal, 20)

        Spacer().frame(height: 8)
      }
    }
  }

  private var featuresStepView: some View {
    VStack(spacing: 30) {
        Spacer()
        
        Text(loc("onboarding.power_features.title", "Power Features ⚡️"))
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.top, 20)
            
        VStack(spacing: 20) {
            FeatureRow(
                icon: "camera.fill",
                color: .blue,
                title: loc("feature.food_log.title", "Smart Food Log"),
                desc: loc("feature.food_log.desc", "Snap food to count calories instantly.")
            )
            FeatureRow(
                icon: "scalemass.fill",
                color: .purple,
                title: loc("feature.scale.title", "Scale Reader"),
                desc: loc("feature.scale.desc", "Snap your scale to log weight automatically.")
            )
            FeatureRow(
                icon: "wineglass.fill",
                color: .red,
                title: loc("feature.alcohol.title", "Alcohol Tracker"),
                desc: loc("feature.alcohol.desc", "Monitor intake with visual history dots.")
            )
            FeatureRow(
                icon: "calendar.badge.clock",
                color: .orange,
                title: loc("feature.timetravel.title", "Time Travel"),
                desc: loc("feature.timetravel.desc", "Forgot to log? Backdate entries anytime.")
            )
            FeatureRow(
                icon: "pawprint.fill",
                color: AppTheme.success,
                title: loc("feature.pet_sounds.title", "Pet Sound Feedback"),
                desc: loc(
                  "feature.pet_sounds.desc",
                  "We added a fun pet themed feedback system. Choose a British cat or a French bulldog. Your pet reacts with sounds. Less healthy food triggers an angry woof or a displeased cat sound. Great choices trigger cheerful happy sounds."
                )
            )
        }
        .padding(.horizontal)
        
        Spacer()
    }
  }
  
  private var disclaimerStepView: some View {
    ScrollView {
      VStack(spacing: 24) {
        Spacer().frame(height: 20)
        
        // Warning Icon
        ZStack {
          Circle()
            .fill(Color.orange.opacity(0.1))
            .frame(width: 100, height: 100)
          
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 50))
            .foregroundColor(.orange)
        }
        .padding(.bottom, 10)
        
        // Title
        Text(loc("disc.title", "Health Information Disclaimer"))
          .font(.system(size: 28, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
          .foregroundColor(AppTheme.textPrimary)
        
        // Main Notice
        VStack(alignment: .leading, spacing: 16) {
          DisclaimerSection(
            title: loc("disc.section.notice", "Important Notice"),
            text: loc(
              "disc.notice.text",
              "This app provides general nutritional information and dietary suggestions for educational purposes only. The information is not intended to replace professional medical advice, diagnosis, or treatment."
            )
          )
          
          DisclaimerSection(
            title: loc("disc.section.medical", "Medical Disclaimer"),
            text: loc(
              "disc.medical.text",
              "Always consult with a qualified healthcare provider before making any changes to your diet or nutrition plan, especially if you have medical conditions, allergies, or dietary restrictions."
            )
          )
          
          DisclaimerSection(
            title: loc("disc.section.accuracy", "Accuracy Disclaimer"),
            text: loc(
              "disc.accuracy.text",
              "Nutritional estimates are based on visual analysis and may not be completely accurate. Actual nutritional content may vary based on preparation methods, portion sizes, and ingredient variations."
            )
          )
        }
        .padding(.horizontal, 20)
        
        Spacer()
      }
    }
  }
  
  struct DisclaimerSection: View {
    let title: String
    let text: String
    
    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.accent)
        
        Text(text)
          .font(.system(size: 15, weight: .regular, design: .rounded))
          .foregroundColor(AppTheme.textSecondary)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding()
      .background(AppTheme.surface)
      .cornerRadius(12)
    }
  }
  
  struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
  }
  
  // MARK: - Health Views (Integrated from Progressive Onboarding logic)
  
  private var healthFormStepView: some View {
      VStack(spacing: 20) {
          Spacer()
          
          VStack(spacing: 24) {
              // Age
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
              }
              
              // Gender
              VStack(alignment: .leading, spacing: 8) {
                  Text(loc("health.gender", "Gender"))
                      .font(.caption)
                      .foregroundColor(.gray)
                      .padding(.leading, 4)
                      
                  HStack(spacing: 0) {
                      ForEach([true, false], id: \.self) { isMaleOption in
                          Button(action: { isMale = isMaleOption }) {
                              Text(isMaleOption ? loc("health.gender.male", "Male") : loc("health.gender.female", "Female"))
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
              
              // Measurements
              HStack(spacing: 16) {
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
              
              // Activity Level
              VStack(alignment: .leading, spacing: 8) {
                   Text(loc("health.activity", "Activity Level:"))
                       .font(.caption)
                       .foregroundColor(.gray)
                       .padding(.leading, 4)
                   
                   Menu {
                       ForEach(activityLevels, id: \.self) { level in
                           Button(action: { activityLevel = level }) {
                               Text(localizedActivityLevel(level))
                           }
                       }
                   } label: {
                       HStack {
                           Text(localizedActivityLevel(activityLevel))
                               .foregroundColor(AppTheme.textPrimary)
                           Spacer()
                           Image(systemName: "chevron.up.chevron.down")
                               .font(.caption)
                               .foregroundColor(.gray)
                       }
                       .padding()
                       .background(AppTheme.surfaceAlt)
                       .cornerRadius(12)
                   }
              }
          }
          .padding(.horizontal, 24)
          
          Spacer()
      }
      .onAppear {
          // Pre-fill if exists
           if let h = UserDefaults.standard.string(forKey: "userHeight") { height = h }
           if UserDefaults.standard.double(forKey: "userHeight") > 0 {
               height = String(Int(UserDefaults.standard.double(forKey: "userHeight")))
           }
           if UserDefaults.standard.double(forKey: "userWeight") > 0 {
               weight = String(format: "%.1f", UserDefaults.standard.double(forKey: "userWeight"))
           }
           if let a = UserDefaults.standard.string(forKey: "userAge") { age = a }
           if UserDefaults.standard.integer(forKey: "userAge") > 0 {
               age = String(UserDefaults.standard.integer(forKey: "userAge"))
           }
           isMale = UserDefaults.standard.bool(forKey: "userIsMale")
      }
  }
  
  private var healthResultsStepView: some View {
      VStack(spacing: 30) {
          Spacer()
          
          VStack(spacing: 16) {
              Text(loc("prog.result", "Your Daily Goal"))
                  .font(.headline)
                  .foregroundColor(AppTheme.textSecondary)
              
              Text("\(recommendedCalories)")
                    .font(.system(size: 70, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [AppTheme.accent, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
              Text(loc("units.kcal", "kcal"))
                  .font(.title3)
                  .fontWeight(.medium)
                  .foregroundColor(AppTheme.textSecondary)
          }
          .padding(.vertical, 20)
          
          if optimalWeight > 0 {
              VStack(spacing: 8) {
                  Text(loc("health.optimal_weight", "🎯 Optimal Weight"))
                      .font(.headline)
                      .foregroundColor(AppTheme.textPrimary)
                  
                  Text("\(String(format: "%.1f", optimalWeight)) kg")
                      .font(.title2)
                      .fontWeight(.bold)
                      .foregroundColor(.green)
                      
                  Text(timeToOptimalWeight)
                      .font(.subheadline)
                      .foregroundColor(.gray)
              }
              .padding()
              .background(AppTheme.surface.opacity(0.5))
              .cornerRadius(16)
          }
          
          Spacer()
      }
  }

  var body: some View {
    ZStack {
      // Dynamic Background
      AppTheme.backgroundGradient
        .edgesIgnoringSafeArea(.all)
        .overlay(
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -100, y: -200)
                
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 100, y: 200)
            }
        )
      
      VStack(spacing: 0) {
        // Top Bar
        HStack {
            if currentStep > 0 {
                Button(action: {
                    withAnimation { currentStep -= 1 }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            
            Spacer()
            
            Button(loc("onboarding.skip", "Skip")) {
                withAnimation { showingSkipConfirmation = true }
            }
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
        }
        .padding(.top, 50)
        .padding(.horizontal, 24)
        
        // Content Area with Transitions
        TabView(selection: $currentStep) {
            ForEach(0..<steps.count, id: \.self) { index in
                defaultStepView(for: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never)) // We build our own controls
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
        
        Spacer()
        
        // Bottom Controls
        VStack(spacing: 24) {
            // Custom Page Indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentStep ? AppTheme.accent : Color.gray.opacity(0.3))
                        .frame(width: index == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(), value: currentStep)
                }
            }
            
            // Main Action Button
            Button(action: {
                handleNextStep()
            }) {
                Group {
                    if isNicknameLoading && steps[currentStep].anchor == "nickname" {
                         ProgressView()
                           .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                         Text(currentStep == steps.count - 1 ? loc("onboarding.start", "Get Started") : loc("onboarding.continue", "Continue"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                }
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(20)
                    .shadow(color: AppTheme.accent.opacity(0.4), radius: 10, x: 0, y: 5)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
      }
    }
    .onAppear {
      if selectedLanguageCode.isEmpty {
        selectedLanguageCode = languageService.currentCode
        selectedLanguageDisplay = languageService.nativeName(for: languageService.currentCode)
      }
    }
    .alert(loc("onboarding.skip.title", "Skip Onboarding?"), isPresented: $showingSkipConfirmation) {
        Button(loc("onboarding.skip.continue", "Continue Tutorial"), role: .cancel) {}
        Button(loc("onboarding.skip.skip", "Skip")) {
            completeOnboarding()
        }
    } message: {
       Text(loc("onboarding.skip.message", "You can always access this tutorial later from your profile settings."))
    }
  }

  private func handleNextStep() {
      // Validate current step
      if currentStep < steps.count {
          let step = steps[currentStep]
          
          if step.anchor == "nickname" {
              saveNickname { success in
                  if success {
                      completeOnboarding() // Nickname is last step in social
                  }
              }
              return
          }
          
          if step.anchor == "health_form" {
              // Save health data logic
              if let h = Double(height), let w = Double(weight), let a = Int(age) {
                  UserDefaults.standard.set(h.rounded(), forKey: "userHeight")
                  UserDefaults.standard.set((w * 10).rounded() / 10, forKey: "userWeight")
                  UserDefaults.standard.set(a, forKey: "userAge")
                  UserDefaults.standard.set(isMale, forKey: "userIsMale")
                  UserDefaults.standard.set(activityLevel, forKey: "userActivityLevel")
                  UserDefaults.standard.set(true, forKey: "hasUserHealthData") // Mark as done
                  calculatePlan()
                  // Move to results
                  withAnimation { currentStep += 1 }
              } else {
                  // Show alert? For now just stay.
                  HapticsService.shared.error()
              }
              return
          }
      }
      
      // Default behavior
      if currentStep < steps.count - 1 {
          withAnimation { currentStep += 1 }
      } else {
          completeOnboarding()
      }
  }
  
  private func calculatePlan() {
      // Logic from ProgressiveOnboarding logic
      let h = Double(height) ?? 175
      let w = Double(weight) ?? 70
      let a = Int(age) ?? 25
      
      // Optimal Weight Calculation (simple BMI based - e.g. BMI 22)
      // weight = BMI * (height/100)^2
      let optimalBMI = 22.0
      let heightInM = h / 100.0
      optimalWeight = optimalBMI * (heightInM * heightInM)
      
      // Time to reach (assuming 0.5kg week loss)
      let diff = w - optimalWeight
      if diff > 0 {
          let weeks = Int(diff / 0.5)
          timeToOptimalWeight = String(format: loc("health.goal.weeks", "%d weeks to reach optimal weight"), weeks)
      } else {
           timeToOptimalWeight = loc("health.goal.maintain", "You are at optimal weight!")
      }

      let bmr: Double = isMale ? (10 * w + 6.25 * h - 5 * Double(a) + 5) : (10 * w + 6.25 * h - 5 * Double(a) - 161)
      
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

  private func saveNickname(completion: @escaping (Bool) -> Void) {
    let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard !trimmed.isEmpty else {
      nicknameError = loc("nickname.empty_error", "Nickname cannot be empty")
      completion(false)
      return
    }
    
    guard trimmed.count <= 50 else {
      nicknameError = loc("nickname.length_error", "Nickname must be 50 characters or less")
      completion(false)
      return
    }
    
    // Check if user is logged in via token presence
    guard UserDefaults.standard.string(forKey: "auth_token") != nil else {
         // Not logged in? Just save locally
         savedNickname = trimmed
         completion(true)
         return
    }
    
    isNicknameLoading = true
    HapticsService.shared.select()
    
    GRPCService().updateNickname(nickname: trimmed) { success, errorMsg in
      DispatchQueue.main.async {
        self.isNicknameLoading = false
        if success {
          self.savedNickname = trimmed
          completion(true)
        } else {
          self.nicknameError = errorMsg ?? loc("nickname.error", "Failed to update nickname")
          HapticsService.shared.error()
          completion(false)
        }
      }
    }
  }

  private var nicknameStepView: some View {
    VStack(spacing: 30) {
      Spacer()
      
      // Hero Icon
      ZStack {
        // Glowing background effect
        ForEach(0..<2) { i in
            Circle()
                .stroke(AppTheme.accent.opacity(0.2 - Double(i) * 0.05), lineWidth: 2)
                .frame(width: 120 + CGFloat(i * 20), height: 120 + CGFloat(i * 20))
        }
        
        Circle()
            .fill(AppTheme.surface)
            .frame(width: 120, height: 120)
            .shadow(color: AppTheme.accent.opacity(0.2), radius: 10, x: 0, y: 5)

        Image(systemName: "person.text.rectangle.fill")
            .font(.system(size: 50))
            .foregroundStyle(
                LinearGradient(
                    colors: [AppTheme.accent, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
      }
      .padding(.bottom, 10)

      VStack(spacing: 16) {
        Text(loc("nickname.title", "Set Your Nickname"))
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
          .foregroundColor(AppTheme.textPrimary)

        Text(loc("nickname.description", "Choose a nickname to share with friends."))
          .font(.system(size: 18, weight: .regular, design: .rounded))
          .multilineTextAlignment(.center)
          .foregroundColor(AppTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 20)
      
      // Input Field
      VStack(alignment: .leading, spacing: 12) {
         TextField(loc("nickname.placeholder", "Enter your nickname"), text: $nickname)
           .font(.system(size: 18))
           .padding(16)
           .background(AppTheme.surface)
           .cornerRadius(AppTheme.cornerRadius)
           .overlay(
             RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
               .stroke(nicknameError != nil ? AppTheme.danger : AppTheme.divider, lineWidth: 1)
           )
           .autocapitalization(.none)
           .disableAutocorrection(true)
           .disabled(isNicknameLoading)
           .onChange(of: nickname) { _ in nicknameError = nil }

         if let error = nicknameError {
             Text(error)
               .font(.system(size: 14))
               .foregroundColor(AppTheme.danger)
               .padding(.leading, 4)
         }
      }
      .padding(.horizontal, 30)
      .padding(.top, 10)
      
      Spacer()
    }
    .onAppear {
        if nickname.isEmpty { nickname = savedNickname }
    }
  }

  private func completeOnboarding() {
    print("Completing onboarding for mode: \(mode)")
    switch mode {
    case .initial:
        hasSeenOnboarding = true
        if selectedLanguageCode.isEmpty {
            LanguageService.shared.setLanguage(code: "en", syncWithBackend: true) { _ in }
        }
    case .health:
        healthOnboardingShown = true
    case .social:
         socialOnboardingShown = true
    }
    
    currentStep = 0
    withAnimation {
        isPresented = false
    }
  }

  private var languageSelectionView: some View {
    VStack(spacing: 30) {
        // Icon
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 120, height: 120)
            
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        }
        .padding(.top, 40)
        
        Text(loc("onboarding.language.title", "Choose Language 🌐"))
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
        
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(languageService.availableLanguagesDetailed(), id: \.code) { item in
                    Button(action: {
                        selectedLanguageDisplay = item.nativeName
                        selectedLanguageCode = item.code
                        LanguageService.shared.setLanguage(code: item.code, syncWithBackend: false) { _ in }
                    }) {
                        VStack(spacing: 8) {
                            Text(item.flag)
                                .font(.system(size: 40))
                            Text(item.nativeName)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(item.code == selectedLanguageCode ? Color.blue.opacity(0.1) : AppTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(item.code == selectedLanguageCode ? Color.blue : Color.clear, lineWidth: 2)
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        )
                    }
                }
            }
            .padding(10)
        }
    }
    .padding(.horizontal, 24)
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
    case "tools":
        return loc("onboarding.tools.title", "Your Essential Tools 🍽️")
    case "pets":
        return loc("onboarding.pets.title", "Meet Your Pet Companion 🐾")
    case "smart_tips":
        return loc("onboarding.new_features.title", "New Features ✨")
    case "features":
        return loc("onboarding.features.title", "All in one Tracker 🚀")
    case "disclaimer":
      return loc("onboarding.disclaimer.title", "Important Health Disclaimer ⚠️")
    case "complete":
      return loc("onboarding.complete.title", "You're All Set! 🎉")
    case "language":
        return loc("onboarding.language.title", "Choose Language 🌐")
    case "nickname":
        return loc("nickname.title", "Set Your Nickname")
    default:
      if let step = steps.first(where: { $0.anchor == anchor }) {
          return step.title
      }
      return ""
    }
  }

  private func localizedDescription(for anchor: String) -> String {
    switch anchor {
    case "welcome":
      return loc(
        "onboarding.welcome.desc",
        "Your smart food companion that helps you track calories, monitor weight, and make healthier choices. Let's take a quick tour!"
      )
    case "addfood":
      return loc(
        "onboarding.recognition.desc",
        "Simply take a photo of your food and our AI will automatically identify it and log the calories. No more manual searching!"
      )
    case "tracking":
      return loc(
        "onboarding.tracking.desc",
        "Monitor your daily calories with our color-coded system and track your weight by photographing your scale. Everything is automated!"
      )
    case "alcohol":
      return loc(
        "onboarding.alcohol.desc",
        "See your alcohol history on a calendar. Dots mark days you drank (bigger dot = more drinks). The top wineglass changes color by recency: red (today/last week), yellow (last month), green (older). Tap it to open the calendar."
      )
    case "share":
      return loc(
        "onboarding.friends.desc",
        "Add friends and share your dishes right from the list. Pick how much they ate (25%, 50%, 75% or custom) and we'll handle the rest."
      )
    case "insights":
      return loc(
        "onboarding.insights.desc",
        "View your trends, manage your profile, and access health information - all designed to help you reach your wellness goals."
      )
    case "health_setup":
      return loc(
        "onboarding.health_setup.desc",
        "For the best experience, we can calculate personalized calorie recommendations based on your health data. This is completely optional!"
      )
    case "health_form":
      return loc(
        "onboarding.health_form.desc",
        "Please provide your basic health information to get personalized recommendations.")
    case "health_results":
      return loc(
        "onboarding.health_results.desc",
        "Based on your data, here are your personalized recommendations for optimal health.")
    case "disclaimer":
      return loc(
        "onboarding.disclaimer.desc",
        "This app is for informational purposes only and not a substitute for professional medical advice. Always consult healthcare providers for personalized dietary guidance and medical decisions."
      )
    case "complete":
      return loc(
        "onboarding.complete.desc",
        "Ready to start your healthy journey? You can always revisit this tutorial from your profile settings if needed."
      )
    case "tools":
        return loc("onboarding.tools.desc", "Small steps that make a big difference.")
    case "pets":
        return loc("onboarding.pets.desc", "Choose a pet that will motivate you on your journey.")
    case "smart_tips":
        return loc("onboarding.new_features.subtitle", "Powerful tools to make your tracking even better.")
    case "features":
        return loc("onboarding.features.desc", "Everything you need to stay healthy, powered by AI.")
    case "language":
        return loc("onboarding.language.desc", "Pick your preferred language.")
    case "nickname":
        return loc("nickname.description", "Choose a nickname to share with friends.")
    default:
        if let step = steps.first(where: { $0.anchor == anchor }) {
            return step.description
        }
        return ""
    }
  }

  // MARK: - View Components

}

// MARK: - Pet Theme Helpers

struct PetMoodBubble: View {
  let imageName: String
  let label: String

  var body: some View {
    VStack(spacing: 4) {
      Image(imageName)
        .resizable()
        .scaledToFit()
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
      Text(label)
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
    }
  }
}

struct PetFeatureRow: View {
  let icon: String
  let color: Color
  let text: String

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 16))
        .foregroundColor(color)
        .frame(width: 28)
      Text(text)
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
