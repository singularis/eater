import SwiftUI
import UIKit

private func shown(_ key: String, _ fallback: String) -> String {
  Localization.shared.tr(key, default: fallback).removingEmoji
}

private extension String {
  /// Drops emoji from tutorial titles so the screens read as plain text.
  var removingEmoji: String {
    let kept = unicodeScalars.filter { scalar in
      let value = scalar.value
      if value == 0xFE0F || value == 0x200D { return false }
      if scalar.properties.isEmojiPresentation { return false }
      if value >= 0x1F000 { return false }
      return true
    }
    return String(String.UnicodeScalarView(kept))
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

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
      case howItWorks
  }
  
  @SceneStorage("onboardingCurrentStep") private var currentStep = 0
  /// Health and social flows must not resume a tutorial page. A stale index
  /// used to land past the end of those shorter flows.
  @State private var flowStep = 0
  @State private var showingSkipConfirmation = false
  @State private var notificationsEnabledLocal: Bool = UserDefaults.standard.bool(
    forKey: "notificationsEnabled")
  @EnvironmentObject var languageService: LanguageService
  @StateObject private var themeService = ThemeService.shared
  @State private var selectedLanguageDisplay: String = ""
  @State private var selectedLanguageCode: String = ""
  @State private var isApplyingLanguage: Bool = false
  @State private var showFeedback: Bool = false
  @State private var platePageIndex: Int = 0
  
  // Nickname State
  @AppStorage("user_nickname") private var savedNickname: String = ""
  @State private var nickname: String = ""
  @State private var isNicknameLoading: Bool = false
  @State private var nicknameError: String? = nil

  var steps: [OnboardingStep] {
      switch mode {
      case .initial, .howItWorks, .health:
          return [
            OnboardingStep(
              title: "",
              description: "",
              anchor: "intro",
              icon: "sparkles"
            ),
            OnboardingStep(
              title: shown("onboarding.tools.title", "Your Essential Tools 🍽️"),
              description: shown("onboarding.tools.desc", "Small steps that make a big difference."),
              anchor: "tools",
              icon: "wrench.and.screwdriver"
            ),
            OnboardingStep(
              title: shown("onboarding.pets.title", "Meet Your Pet Companion 🐾"),
              description: shown("onboarding.pets.desc", "Choose a pet that will motivate you on your journey."),
              anchor: "pets",
              icon: "pawprint.fill"
            ),
            OnboardingStep(
              title: shown("onboarding.plan.title", "Your Personal Plan 😎"),
              description: shown("onboarding.plan.desc", "See how your goal and activity level turn into a safe, realistic plan."),
              anchor: "plan",
              icon: "target"
            ),
            OnboardingStep(
              title: shown("onboarding.plates.title", "Balanced Plate and Score"),
              description: shown("onboarding.plates.desc", "See how a balanced plate leads to a higher health score."),
              anchor: "balanced_plate",
              icon: "leaf.circle.fill"
            ),
            OnboardingStep(
              title: shown("onboarding.new_features.title", "More than a photo"),
              description: shown("onboarding.new_features.subtitle", "A photo of your meal is the main way to log. Here is everything else."),
              anchor: "smart_tips",
              icon: "sparkles"
            ),
            OnboardingStep(
              title: shown("onboarding.team.title", "Let's Build Eateria Together"),
              description: shown("onboarding.team.desc", "We'd love to grow with you."),
              anchor: "team",
              icon: "heart.circle.fill"
            ),
            OnboardingStep(
              title: shown("disc.title", "Health Information Disclaimer"),
              description: shown(
                "disc.notice.text",
                "This app provides general nutritional information and dietary suggestions for educational purposes only. The information is not intended to replace professional medical advice, diagnosis, or treatment."
              ),
              anchor: "disclaimer",
              icon: "exclamationmark.triangle.fill"
            ),
          ]
      case .social:
          return [
              OnboardingStep(
                  title: shown("onboarding.friends.title", "Share Meals with Friends 🤝"),
                  description: shown("onboarding.friends.desc", "Add friends and share your dishes right from the list. Pick how much they ate and we'll handle the rest."),
                  anchor: "share",
                  icon: "person.2.fill"
              ),
              OnboardingStep(
                  title: shown("nickname.title", "Set Your Nickname"),
                  description: shown("nickname.description", "Choose a nickname to share with friends instead of your email address."),
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
    
    if step.anchor == "intro" {
        return AnyView(introStepView)
    }
    
    if step.anchor == "tools" {
        return AnyView(toolsStepView)
    }
    
    if step.anchor == "pets" {
        return AnyView(petThemeStepView)
    }
    
    if step.anchor == "plan" {
        return AnyView(planStepView)
    }
    
    if step.anchor == "balanced_plate" {
        return AnyView(balancedPlateStepView)
    }
    
    if step.anchor == "smart_tips" {
        return AnyView(smartTipsStepView)
    }
    
    if step.anchor == "language" {
        return AnyView(languageSelectionView)
    }
    
    if step.anchor == "team" {
        return AnyView(teamStepView)
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

    return AnyView(GeometryReader { geo in
      ScrollView(showsIndicators: false) {
        VStack(spacing: 20) {
          Spacer(minLength: 24)
          Image(systemName: themeService.icon(for: step.icon))
            .font(.system(size: 32, weight: .semibold))
            .foregroundColor(AppTheme.accent)
            .frame(width: 72, height: 72)
            .background(AppTheme.accent.opacity(0.12))
            .clipShape(Circle())
          stepHeader(localizedTitle(for: step.anchor), localizedDescription(for: step.anchor))
          Spacer(minLength: 24)
        }
        .frame(minHeight: geo.size.height)
        .frame(maxWidth: .infinity)
      }
    })
  }

  private func stepHeader(_ title: String, _ subtitle: String) -> some View {
    VStack(spacing: 8) {
      Text(title)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      if !subtitle.isEmpty {
        Text(subtitle)
          .font(.system(size: 16, weight: .regular, design: .rounded))
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, 24)
  }
  
  private var toolsStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 16) {
        stepHeader(
          shown("onboarding.tools.title", "Your Essential Tools"),
          shown("onboarding.tools.subtitle", "These are small but very important steps toward healthier eating.")
        )

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
          Text(shown("onboarding.tools.scales.title", "Kitchen Scales"))
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)

          Text(shown("onboarding.tools.scales.desc", "Weigh your food to understand real portions. You will be surprised how much a \"small\" serving actually weighs."))
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
      .padding(.horizontal, 24)

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
          Text(shown("onboarding.tools.containers.title", "Food Containers"))
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)

          Text(shown("onboarding.tools.containers.desc", "Organize meals so nothing goes to waste. Containers make meal prep effortless and keep your eating structured."))
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
      .padding(.horizontal, 24)

      // --- Track Everything reminder ---
      VStack(spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(.green)

          Text(shown("onboarding.tools.track.title", "Track Everything"))
            .font(.body.weight(.semibold))
            .foregroundColor(AppTheme.textPrimary)
        }

        Text(shown("onboarding.tools.track.desc", "Even if something seems less healthy, keep tracking! No judgment, no stopping. That is the path to a balanced relationship with food. Every step toward awareness matters."))
          .font(.subheadline)
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
      .padding(.horizontal, 24)

        Spacer().frame(height: 24)
      }
    }
  }

  private var introStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 20) {
        Spacer().frame(height: 8)

        Group {
          if UIImage(named: "onboarding_intro_pets") != nil {
            Image("onboarding_intro_pets")
              .resizable()
          } else {
            Image("onboarding_plate1")
              .resizable()
          }
        }
        .scaledToFill()
        .frame(width: 168, height: 168)
        .clipShape(Circle())
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)

        stepHeader(
          shown("onboarding.intro.title", "Welcome to Eateria"),
          shown("onboarding.intro.lead", "Photograph a meal. We log the calories and a health score.")
        )

        VStack(alignment: .leading, spacing: 12) {
          introPoint("camera.fill", shown("onboarding.intro.point.photo", "Snap the plate from the blue camera button."))
          introPoint("leaf.fill", shown("onboarding.intro.point.score", "A higher score means a more balanced plate."))
          introPoint("heart.fill", shown("onboarding.intro.point.habit", "Keep logging, even on a less healthy day."))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .padding(.horizontal, 24)

        Spacer().frame(height: 8)
      }
    }
  }

  private func introPoint(_ icon: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(AppTheme.accent)
        .frame(width: 28, height: 28)
        .background(AppTheme.accent.opacity(0.12))
        .clipShape(Circle())
      Text(text)
        .font(.subheadline)
        .foregroundColor(AppTheme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
  }

  private func chooseMascot(_ mascot: AppMascot) {
    guard themeService.currentMascot != mascot else { return }
    HapticsService.shared.select()
    themeService.currentMascot = mascot
    if mascot != .none {
      themeService.playSound(for: "happy")
    }
  }

  private func mascotChoice<Avatar: View>(
    _ mascot: AppMascot,
    title: String,
    detail: String,
    moods: [(String, String)] = [],
    @ViewBuilder avatar: () -> Avatar
  ) -> some View {
    let selected = themeService.currentMascot == mascot
    return Button {
      chooseMascot(mascot)
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .center, spacing: 12) {
          avatar()
          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .font(.body.weight(.semibold))
              .foregroundColor(AppTheme.textPrimary)
            Text(detail)
              .font(.subheadline)
              .foregroundColor(AppTheme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 8)
          Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundColor(selected ? AppTheme.accent : AppTheme.divider)
        }
        if !moods.isEmpty {
          HStack(spacing: 8) {
            Spacer(minLength: 0)
            ForEach(Array(moods.enumerated()), id: \.offset) { _, mood in
              PetMoodBubble(imageName: mood.0, label: mood.1)
            }
            Spacer(minLength: 0)
          }
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
          .stroke(selected ? AppTheme.accent : AppTheme.divider, lineWidth: selected ? 2 : 1)
      )
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 24)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var petThemeStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 12) {
        stepHeader(
          shown("onboarding.pets.title", "Meet Your Pet Companion"),
          shown("onboarding.pets.subtitle", "Tap a companion. It reacts when you log food. Or keep the simple look.")
        )

        mascotChoice(
          .cat,
          title: "Cat",
          detail: shown("onboarding.pets.cat.desc", "Elegant and opinionated. Purrs when you eat well, hisses when you don't."),
          moods: [
            ("british_cat_happy", shown("onboarding.pets.mood.happy", "Happy")),
            ("british_cat_gym", shown("onboarding.pets.mood.gym", "Gym")),
            ("british_cat_bad_food", shown("onboarding.pets.mood.upset", "Upset")),
            ("british_cat_alcohol", shown("onboarding.pets.mood.alcohol_tracking", "Alcohol")),
          ]
        ) {
          if let catImg = AppMascot.cat.happyImage() {
            Image(catImg)
              .resizable()
              .scaledToFit()
              .frame(width: 56, height: 56)
              .clipShape(Circle())
          }
        }

        mascotChoice(
          .dog,
          title: "Root",
          detail: shown("onboarding.pets.dog.desc", "Loyal and expressive. Barks with joy for healthy meals, growls at junk food."),
          moods: [
            ("french_bulldog_happy", shown("onboarding.pets.mood.happy", "Happy")),
            ("french_bulldog_gym", shown("onboarding.pets.mood.gym", "Gym")),
            ("french_bulldog_bad_food", shown("onboarding.pets.mood.upset", "Upset")),
            ("french_bulldog_alcohol", shown("onboarding.pets.mood.alcohol_tracking", "Alcohol")),
          ]
        ) {
          if let dogImg = AppMascot.dog.happyImage() {
            Image(dogImg)
              .resizable()
              .scaledToFit()
              .frame(width: 56, height: 56)
              .clipShape(Circle())
          }
        }

        mascotChoice(
          .none,
          title: shown("onboarding.pets.default.title", "Default Style"),
          detail: shown("onboarding.pets.default.desc", "Clean and simple. Standard icons without pet reactions.")
        ) {
          Image(systemName: "star.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(AppTheme.accent)
            .frame(width: 56, height: 56)
            .background(AppTheme.accent.opacity(0.12))
            .clipShape(Circle())
        }

        Spacer().frame(height: 8)
      }
    }
  }

  private static let extraGroups: [(titleKey: String, title: String, tools: [(icon: String, titleKey: String, title: String, descKey: String, desc: String)])] = [
    ("onboarding.extra.group.log", "Logging", [
      ("square.and.pencil", "onboarding.extra.type.title", "Type a meal", "onboarding.extra.type.desc", "Write what you ate, such as rice and vegetables 200g. No photo needed."),
      ("hand.tap.fill", "onboarding.extra.manual.title", "Try manually", "onboarding.extra.manual.desc", "If a photo got the dish wrong, type the right name. Calories and the score update."),
      ("cup.and.saucer.fill", "onboarding.extra.addons.title", "Additives", "onboarding.extra.addons.desc", "Open a dish and add milk, sugar, wasabi, and similar extras."),
      ("calendar", "onboarding.extra.calendar.title", "Past days", "onboarding.extra.calendar.desc", "Tap the date to see earlier meals, or log one you forgot."),
    ]),
    ("onboarding.extra.group.body", "Your body", [
      ("camera.viewfinder", "onboarding.extra.weight.title", "Weight", "onboarding.extra.weight.desc", "Photograph your scale and the weight is logged."),
      ("figure.run", "onboarding.extra.activity.title", "Activity and chess", "onboarding.extra.activity.desc", "Gym, steps, treadmill, elliptical, yoga, and a live chess score. Burned calories are added."),
      ("wineglass.fill", "onboarding.extra.alcohol.title", "Alcohol", "onboarding.extra.alcohol.desc", "Drinks sit on their own calendar, separate from meals."),
      ("heart.fill", "onboarding.extra.health.title", "Apple Health", "onboarding.extra.health.desc", "Fill height and weight from Apple Health, and add calories you burned."),
    ]),
    ("onboarding.extra.group.app", "Around the app", [
      ("lightbulb.fill", "onboarding.extra.ideas.title", "Ideas", "onboarding.extra.ideas.desc", "Meal ideas from what you still have left today, and advice for the week."),
      ("person.2.fill", "onboarding.extra.friends.title", "Friends", "onboarding.extra.friends.desc", "Share a dish and pick how much your friend ate."),
      ("chart.bar.fill", "onboarding.extra.stats.title", "Stats", "onboarding.extra.stats.desc", "See calories, weight, and how the week is going."),
    ]),
  ]

  private var smartTipsStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 18) {
        stepHeader(
          shown("onboarding.new_features.title", "More than a photo"),
          shown("onboarding.new_features.subtitle", "A photo of your meal is the main way to log. Here is everything else.")
        )
        .frame(maxWidth: .infinity)

        ForEach(Array(Self.extraGroups.enumerated()), id: \.offset) { _, group in
          VStack(alignment: .leading, spacing: 8) {
            Text(shown(group.titleKey, group.title))
              .font(.subheadline.weight(.semibold))
              .foregroundColor(AppTheme.textSecondary)
              .padding(.horizontal, 4)

            VStack(spacing: 0) {
              ForEach(Array(group.tools.enumerated()), id: \.offset) { index, tool in
                if index > 0 {
                  Divider().padding(.leading, 56)
                }
                HStack(alignment: .top, spacing: 12) {
                  Image(systemName: tool.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(Circle())
                  VStack(alignment: .leading, spacing: 2) {
                    Text(shown(tool.titleKey, tool.title))
                      .font(.subheadline.weight(.semibold))
                      .foregroundColor(AppTheme.textPrimary)
                    Text(shown(tool.descKey, tool.desc))
                      .font(.footnote)
                      .foregroundColor(AppTheme.textSecondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
              }
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
          }
        }
        .padding(.horizontal, 24)

        Spacer().frame(height: 8)
      }
    }
  }

  private var planStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 16) {
        stepHeader(
          shown("onboarding.plan.title", "Your Personal Plan"),
          shown("onboarding.plan.subtitle", "Set a safe goal and let the app build a realistic path for you.")
        )

        VStack(alignment: .leading, spacing: 14) {
          PlanBulletRow(
            icon: "heart.circle.fill",
            color: AppTheme.success,
            text: shown("onboarding.plan.point.weight", "Choose your target weight. BMI never goes below 18.5, so the goal stays safe.")
          )
          PlanBulletRow(
            icon: "figure.walk.circle.fill",
            color: AppTheme.accent,
            text: shown("onboarding.plan.point.activity", "Pick your activity level or use the activity only mode to focus on movement instead of diet.")
          )
          PlanBulletRow(
            icon: "calendar.badge.clock",
            color: AppTheme.warning,
            text: shown("onboarding.plan.point.timeline", "We calculate a daily calorie range and a timeline that fits your lifestyle.")
          )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .padding(.horizontal, 24)

        Text(shown("onboarding.plan.hint", "Set this any time in Profile, Health."))
          .font(.subheadline)
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
          .padding(.bottom, 12)
      }
    }
  }

  private static let plateSlideshowSlides: [(imageName: String, titleKey: String, titleDefault: String, score: Int, descKey: String, descDefault: String)] = [
    ("onboarding_plate1", "onboarding.plates.slide1.title", "Avocado salad", 95, "onboarding.plates.slide1.desc", "Avocado, egg, tomato, cheese, olive. A real life example that often scores in the 90s."),
    ("onboarding_plate2", "onboarding.plates.slide2.title", "Chicken breast bowl", 94, "onboarding.plates.slide2.desc", "Chicken breast, rice, avocado, cucumber. Filling and balanced, typical high score."),
    ("onboarding_plate3", "onboarding.plates.slide3.title", "Chicken with broccoli and egg", 93, "onboarding.plates.slide3.desc", "Grilled chicken, broccoli, egg. Simple, high protein, high score."),
  ]

  private var balancedPlateStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 14) {
        stepHeader(
          shown("onboarding.plates.title", "Balanced Plate and Score"),
          shown("onboarding.plates.subtitle", "The higher the score, the closer you are to balance and long term health.")
        )

        let slide = Self.plateSlideshowSlides[platePageIndex]
        BalancedPlateCard(
          imageName: slide.imageName,
          title: shown(slide.titleKey, slide.titleDefault),
          scoreText: "\(shown("onboarding.plates.score_label", "Score")): \(slide.score)",
          description: shown(slide.descKey, slide.descDefault)
        )
        .padding(.horizontal, 24)
        .id(platePageIndex)

        HStack(spacing: 4) {
          ForEach(0..<Self.plateSlideshowSlides.count, id: \.self) { index in
            Button {
              guard index != platePageIndex else { return }
              HapticsService.shared.select()
              platePageIndex = index
            } label: {
              Capsule()
                .fill(index == platePageIndex ? AppTheme.accent : AppTheme.divider)
                .frame(width: index == platePageIndex ? 18 : 8, height: 8)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(shown(Self.plateSlideshowSlides[index].titleKey, Self.plateSlideshowSlides[index].titleDefault))
          }
        }

        Text(shown("onboarding.plates.motivation.desc", "When the score goes up, your plate is more balanced. Can you nudge today's score a little higher?"))
          .font(.subheadline)
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
          .padding(.bottom, 12)
      }
    }
  }

  private var teamStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 16) {
        stepHeader(
          shown("onboarding.team.title", "Let's Build Eateria Together"),
          ""
        )

        Text(shown("onboarding.team.message", "Dear customers,\nThank you for using Eateria.\n\nWe're building the app actively and would love to grow it with you. If you'd like to join the team, contribute ideas, or simply share feedback, we'd be happy to hear from you.\n\nWith 💜,\nThe Eateria team"))
          .font(.body)
          .foregroundColor(AppTheme.textPrimary)
          .multilineTextAlignment(.leading)
          .lineSpacing(5)
          .padding(.horizontal, 24)
          .frame(maxWidth: .infinity, alignment: .leading)
        
        HStack(spacing: 20) {
          TeamMemberCard(
            imageName: "team_eugen",
            name: "Eugen",
            title: shown("onboarding.team.role.founder", "Cat"),
            linkURL: "https://www.linkedin.com/in/eugenparasochka/"
          )
          TeamMemberCard(
            imageName: "team_olha",
            name: "Olha",
            title: shown("onboarding.team.role.founder2", "Root"),
            linkURL: "https://www.linkedin.com/in/olha-ivanova-devops/"
          )
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        
        Button(action: { showFeedback = true }) {
          HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
            Text(shown("onboarding.team.leave_feedback", "Leave feedback"))
              .font(.body.weight(.semibold))
          }
          .foregroundColor(AppTheme.accent)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(AppTheme.surface)
          .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
              .stroke(AppTheme.divider, lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        
        Spacer().frame(height: 16)
      }
    }
    .sheet(isPresented: $showFeedback) {
      FeedbackView(isPresented: $showFeedback)
        .appInterfaceScale()
    }
  }

  private var featuresStepView: some View {
    VStack(spacing: 30) {
        Spacer()
        
        Text(shown("onboarding.power_features.title", "Power Features ⚡️"))
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.top, 20)
            
        VStack(spacing: 20) {
            FeatureRow(
                icon: "camera.fill",
                color: .blue,
                title: shown("feature.food_log.title", "Smart Food Log"),
                desc: shown("feature.food_log.desc", "Snap food to count calories instantly.")
            )
            FeatureRow(
                icon: "viewfinder",
                color: .purple,
                title: shown("feature.scale.title", "Scale Reader"),
                desc: shown("feature.scale.desc", "Snap your scale to log weight automatically.")
            )
            FeatureRow(
                icon: "wineglass.fill",
                color: .red,
                title: shown("feature.alcohol.title", "Alcohol Tracker"),
                desc: shown("feature.alcohol.desc", "Monitor intake with visual history dots.")
            )
            FeatureRow(
                icon: "calendar.badge.clock",
                color: .orange,
                title: shown("feature.timetravel.title", "Time Travel"),
                desc: shown("feature.timetravel.desc", "Forgot to log? Backdate entries anytime.")
            )
            FeatureRow(
                icon: "pawprint.fill",
                color: AppTheme.success,
                title: shown("feature.pet_sounds.title", "Pet Sound Feedback"),
                desc: shown(
                  "feature.pet_sounds.desc",
                  "We added a fun pet themed feedback system. Choose a Cat or Root. Your pet reacts with sounds. Less healthy food triggers an angry woof or a displeased cat sound. Great choices trigger cheerful happy sounds."
                )
            )
        }
        .padding(.horizontal)
        
        Spacer()
    }
  }
  
  private var disclaimerStepView: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 28, weight: .semibold))
          .foregroundColor(AppTheme.warning)
          .frame(width: 72, height: 72)
          .background(AppTheme.warning.opacity(0.12))
          .clipShape(Circle())
          .padding(.top, 8)

        stepHeader(
          shown("disc.title", "Health Information Disclaimer"),
          shown("onboarding.disclaimer.short", "Please read this before you start.")
        )
        
        // Main Notice
        VStack(alignment: .leading, spacing: 16) {
          DisclaimerSection(
            title: shown("disc.section.notice", "Important Notice"),
            text: shown(
              "disc.notice.text",
              "This app provides general nutritional information and dietary suggestions for educational purposes only. The information is not intended to replace professional medical advice, diagnosis, or treatment."
            )
          )
          
          DisclaimerSection(
            title: shown("disc.section.medical", "Medical Disclaimer"),
            text: shown(
              "disc.medical.text",
              "Always consult with a qualified healthcare provider before making any changes to your diet or nutrition plan, especially if you have medical conditions, allergies, or dietary restrictions."
            )
          )
          
          DisclaimerSection(
            title: shown("disc.section.accuracy", "Accuracy Disclaimer"),
            text: shown(
              "disc.accuracy.text",
              "Nutritional estimates are based on visual analysis and may not be completely accurate. Actual nutritional content may vary based on preparation methods, portion sizes, and ingredient variations."
            )
          )
        }
        .padding(.horizontal, 24)
        
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
  
  private var usesTutorialProgress: Bool {
    mode == .initial || mode == .howItWorks
  }

  private var stepIndex: Int {
    let raw = usesTutorialProgress ? currentStep : flowStep
    guard !steps.isEmpty else { return 0 }
    return min(max(raw, 0), steps.count - 1)
  }

  private func setStep(_ newValue: Int) {
    let clamped = min(max(newValue, 0), max(steps.count - 1, 0))
    if usesTutorialProgress {
      currentStep = clamped
    } else {
      flowStep = clamped
    }
  }

  private var stepSelection: Binding<Int> {
    Binding(get: { stepIndex }, set: { setStep($0) })
  }

  private var canGoBack: Bool { stepIndex > 0 }

  private var isLastStep: Bool { stepIndex == steps.count - 1 }

  private var proceedTitle: String {
    isLastStep ? shown("onboarding.start", "Get Started") : shown("onboarding.continue", "Continue")
  }

  private var showsProceedSpinner: Bool {
    isNicknameLoading && steps[stepIndex].anchor == "nickname"
  }

  var body: some View {
    ZStack {
      AppTheme.backgroundGradient
        .edgesIgnoringSafeArea(.all)

      VStack(spacing: 0) {
        HStack(spacing: 12) {
          Button(action: goBack) {
            Image(systemName: "chevron.left")
              .font(.system(size: 17, weight: .bold))
              .foregroundColor(AppTheme.textPrimary)
              .frame(width: 44, height: 44)
              .background(AppTheme.surface)
              .clipShape(Circle())
              .overlay(Circle().stroke(AppTheme.divider, lineWidth: 1))
          }
          .buttonStyle(.plain)
          .opacity(canGoBack ? 1 : 0)
          .disabled(!canGoBack)
          .accessibilityHidden(!canGoBack)

          Spacer(minLength: 0)

          Button(shown("onboarding.skip", "Skip")) {
            HapticsService.shared.select()
            withAnimation { showingSkipConfirmation = true }
          }
          .buttonStyle(.plain)
          .font(.body.weight(.medium))
          .foregroundColor(AppTheme.textPrimary)
          .padding(.horizontal, 16)
          .frame(height: 36)
          .background(AppTheme.surface)
          .clipShape(Capsule())
          .overlay(Capsule().stroke(AppTheme.divider, lineWidth: 1))
        }
        .frame(height: 52)
        .padding(.horizontal, 24)

        TabView(selection: stepSelection) {
          ForEach(0..<steps.count, id: \.self) { index in
            defaultStepView(for: index)
              .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(HiddenPageControl())
        .animation(AppSettingsService.shared.reduceMotion ? .none : .easeInOut(duration: 0.25), value: stepIndex)

        VStack(spacing: 14) {
          HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { index in
              Capsule()
                .fill(index == stepIndex ? AppTheme.accent : AppTheme.divider)
                .frame(width: index == stepIndex ? 18 : 6, height: 6)
            }
          }
          .frame(height: 8)
          .accessibilityLabel(shown("onboarding.progress", "Step \(stepIndex + 1) of \(steps.count)"))

          Button(action: handleNextStep) {
            Text(proceedTitle)
              .font(.body.weight(.semibold))
              .opacity(showsProceedSpinner ? 0 : 1)
              .overlay {
                if showsProceedSpinner {
                  ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
              }
          }
          .buttonStyle(PrimaryButtonStyle())
          .disabled(showsProceedSpinner)
          .opacity(showsProceedSpinner ? 0.7 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
      }
    }
    .onAppear {
      if usesTutorialProgress {
        setStep(currentStep)
      }
      if selectedLanguageCode.isEmpty {
        selectedLanguageCode = languageService.currentCode
        selectedLanguageDisplay = languageService.nativeName(for: languageService.currentCode)
      }
    }
    .overlay {
      if showingSkipConfirmation {
        skipConfirmationOverlay
      }
    }
  }

  private var skipConfirmationOverlay: some View {
    ZStack {
      Color.black.opacity(0.5)
        .ignoresSafeArea()
        .onTapGesture { showingSkipConfirmation = false }
      VStack(spacing: 20) {
        Text(shown("onboarding.skip.title", "Skip Onboarding?"))
          .font(.headline)
          .foregroundColor(AppTheme.textPrimary)
        Text(shown("onboarding.skip.message", "You can always access this tutorial later from your profile settings."))
          .font(.subheadline)
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
        VStack(spacing: 12) {
          Button(action: {
            HapticsService.shared.select()
            showingSkipConfirmation = false
          }) {
            Text(shown("onboarding.skip.continue", "Continue Tutorial"))
              .font(.body.weight(.semibold))
          }
          .buttonStyle(PrimaryButtonStyle())
          Button(action: {
            HapticsService.shared.select()
            completeOnboarding()
          }) {
            Text(shown("onboarding.skip.skip", "Skip"))
              .font(.system(size: 16, weight: .semibold, design: .rounded))
              .foregroundColor(.red)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
      }
      .padding(24)
      .background(AppTheme.surface)
      .cornerRadius(20)
      .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
      .padding(.horizontal, 32)
    }
  }

  private func goBack() {
    guard canGoBack else { return }
    HapticsService.shared.select()
    moveToStep(stepIndex - 1)
  }

  private func moveToStep(_ newValue: Int) {
    if AppSettingsService.shared.reduceMotion {
      setStep(newValue)
    } else {
      withAnimation(.easeInOut(duration: 0.25)) { setStep(newValue) }
    }
  }

  private func handleNextStep() {
      HapticsService.shared.select()
      let step = steps[stepIndex]

      if step.anchor == "nickname" {
          saveNickname { success in
              if success {
                  completeOnboarding()
              }
          }
          return
      }

      if stepIndex < steps.count - 1 {
          moveToStep(stepIndex + 1)
      } else {
          completeOnboarding()
      }
  }


  private static func isNicknameValidLatinLowercase(_ s: String) -> Bool {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
    return s.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  private func saveNickname(completion: @escaping (Bool) -> Void) {
    let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    
    // Nickname is optional — skip save if the user left it blank
    guard !trimmed.isEmpty else {
      completion(true)
      return
    }
    
    guard trimmed.count <= 50 else {
      nicknameError = shown("nickname.length_error", "Nickname must be 50 characters or less")
      completion(false)
      return
    }

    guard Self.isNicknameValidLatinLowercase(trimmed) else {
      nicknameError = shown("nickname.latin_lowercase_error", "Only Latin lowercase letters and digits (a-z, 0-9)")
      completion(false)
      return
    }
    
    guard KeychainHelper.shared.read("auth_token") != nil else {
         savedNickname = trimmed
         completion(true)
         return
    }
    
    isNicknameLoading = true

    GRPCService().updateNickname(nickname: trimmed) { success, errorMsg in
      DispatchQueue.main.async {
        self.isNicknameLoading = false
        if success {
          self.savedNickname = trimmed
          completion(true)
        } else {
          let raw = (errorMsg ?? "").lowercased()
          if raw.contains("already taken") || raw.contains("taken") {
            self.nicknameError = shown("nickname.taken_error", "This nickname is already taken")
          } else if raw.contains("latin") || raw.contains("lowercase") {
            self.nicknameError = shown("nickname.latin_lowercase_error", "Only Latin lowercase letters and digits (a-z, 0-9)")
          } else {
            self.nicknameError = errorMsg ?? shown("nickname.error", "Failed to update nickname")
          }
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
      Image(systemName: "person.text.rectangle.fill")
        .font(.system(size: 32, weight: .semibold))
        .foregroundColor(AppTheme.accent)
        .frame(width: 72, height: 72)
        .background(AppTheme.accent.opacity(0.12))
        .clipShape(Circle())

      VStack(spacing: 16) {
        Text(shown("nickname.title", "Set Your Nickname"))
          .font(.system(size: 28, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
          .foregroundColor(AppTheme.textPrimary)

        Text(shown("nickname.description", "Choose a nickname to share with friends."))
          .font(.system(size: 16, weight: .regular, design: .rounded))
          .multilineTextAlignment(.center)
          .foregroundColor(AppTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 20)
      
      // Input Field
      VStack(alignment: .leading, spacing: 12) {
         TextField(shown("nickname.placeholder", "Enter your nickname"), text: $nickname)
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
           .onChange(of: nickname) { nicknameError = nil }

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
    let email = UserDefaults.standard.string(forKey: "user_email")
    switch mode {
    case .initial:
        AppSettingsService.shared.markInitialOnboardingSeen(for: email)
        if selectedLanguageCode.isEmpty {
            LanguageService.shared.setLanguage(code: "en", syncWithBackend: true) { _ in }
        }
    case .health:
        AppSettingsService.shared.markHealthOnboardingSeen(for: email)
    case .social:
        AppSettingsService.shared.markSocialOnboardingSeen(for: email)
    case .howItWorks:
        break
    }
    
    currentStep = 0
    flowStep = 0
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
        
        Text(shown("onboarding.language.title", "Choose Language 🌐"))
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
      return shown("onboarding.welcome.title", "Welcome to Eateria! 🍎")
    case "addfood":
      return shown("onboarding.recognition.title", "Smart Food Recognition 📸")
    case "tracking":
      return shown("onboarding.tracking.title", "Track Your Progress 📊")
    case "alcohol":
      return shown("onboarding.alcohol.title", "Alcohol Tracking 🍷")
    case "share":
      return shown("onboarding.friends.title", "Share Meals with Friends 🤝")
    case "insights":
      return shown("onboarding.insights.title", "Get Personalized Insights 💡")
    case "health_setup":
      return shown("onboarding.health_setup.title", "Personalized Health Setup 📋")
    case "health_form":
      return shown("onboarding.health_form.title", "Your Health Data 📝")
    case "health_results":
      return shown("onboarding.health_results.title", "Your Personalized Plan 🎯")
    case "tools":
        return shown("onboarding.tools.title", "Your Essential Tools 🍽️")
    case "pets":
        return shown("onboarding.pets.title", "Meet Your Pet Companion 🐾")
    case "plan":
        return shown("onboarding.plan.title", "Your Personal Plan 😎")
    case "balanced_plate":
        return shown("onboarding.plates.title", "Balanced Plate and Score")
    case "smart_tips":
        return shown("onboarding.new_features.title", "More than a photo")
    case "team":
        return shown("onboarding.team.title", "Let's Build Eateria Together")
    case "features":
        return shown("onboarding.features.title", "All in one Tracker 🚀")
    case "disclaimer":
      return shown("onboarding.disclaimer.title", "Important Health Disclaimer ⚠️")
    case "complete":
      return shown("onboarding.complete.title", "You're All Set! 🎉")
    case "language":
        return shown("onboarding.language.title", "Choose Language 🌐")
    case "nickname":
        return shown("nickname.title", "Set Your Nickname")
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
      return shown(
        "onboarding.welcome.desc",
        "Your smart food companion that helps you track calories, monitor weight, and make healthier choices. Let's take a quick tour!"
      )
    case "addfood":
      return shown(
        "onboarding.recognition.desc",
        "Simply take a photo of your food and our LLM will automatically identify it and log the calories. No more manual searching!"
      )
    case "tracking":
      return shown(
        "onboarding.tracking.desc",
        "Monitor your daily calories with our color-coded system and track your weight by photographing your scale. Everything is automated!"
      )
    case "alcohol":
      return shown(
        "onboarding.alcohol.desc",
        "See your alcohol history on a calendar. Dots mark days you drank (bigger dot = more drinks). The top wineglass changes color by recency: red (today/last week), yellow (last month), green (older). Tap it to open the calendar."
      )
    case "share":
      return shown(
        "onboarding.friends.desc",
        "Add friends and share your dishes right from the list. Pick how much they ate (25%, 50%, 75% or custom) and we'll handle the rest."
      )
    case "insights":
      return shown(
        "onboarding.insights.desc",
        "View your trends, manage your profile, and access health information - all designed to help you reach your wellness goals."
      )
    case "health_setup":
      return shown(
        "onboarding.health_setup.desc",
        "For the best experience, we can calculate personalized calorie recommendations based on your health data. This is completely optional!"
      )
    case "health_form":
      return shown(
        "onboarding.health_form.desc",
        "Please provide your basic health information to get personalized recommendations.")
    case "health_results":
      return shown(
        "onboarding.health_results.desc",
        "Based on your data, here are your personalized recommendations for optimal health.")
    case "disclaimer":
      return shown(
        "onboarding.disclaimer.desc",
        "This app is for informational purposes only and not a substitute for professional medical advice. Always consult healthcare providers for personalized dietary guidance and medical decisions."
      )
    case "complete":
      return shown(
        "onboarding.complete.desc",
        "Ready to start your healthy journey? You can always revisit this tutorial from your profile settings if needed."
      )
    case "tools":
        return shown("onboarding.tools.desc", "Small steps that make a big difference.")
    case "pets":
        return shown("onboarding.pets.desc", "Choose a pet that will motivate you on your journey.")
    case "plan":
        return shown("onboarding.plan.desc", "See how your goal and activity level turn into a safe, realistic plan.")
    case "balanced_plate":
        return shown("onboarding.plates.desc", "See how a balanced plate leads to a higher health score.")
    case "smart_tips":
        return shown("onboarding.new_features.subtitle", "A photo of your meal is the main way to log. Here is everything else.")
    case "team":
        return shown("onboarding.team.desc", "We'd love to grow with you.")
    case "features":
        return shown("onboarding.features.desc", "Everything you need to stay healthy, powered by LLM technology.")
    case "language":
        return shown("onboarding.language.desc", "Pick your preferred language.")
    case "nickname":
        return shown("nickname.description", "Choose a nickname to share with friends.")
    default:
        if let step = steps.first(where: { $0.anchor == anchor }) {
            return step.description
        }
        return ""
    }
  }

  // MARK: - View Components

}

// Hides the system page dots. Nested page TabViews draw them on top of the cards
// even when indexDisplayMode is .never.
private struct HiddenPageControl: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    DispatchQueue.main.async {
      var node: UIView? = uiView.superview
      var depth = 0
      while let current = node, depth < 16, !(current is UIWindow) {
        for child in current.subviews {
          if let control = child as? UIPageControl {
            control.isHidden = true
            control.alpha = 0
          }
        }
        node = current.superview
        depth += 1
      }
    }
  }
}

// Simple star shape for clipping intro image
struct StarShape: Shape {
  let corners: Int
  let smoothness: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
    var angle: CGFloat = -.pi / 2
    let angleIncrement = .pi * 2 / CGFloat(corners * 2)
    let radius = min(rect.width, rect.height) / 2
    let innerRadius = radius * smoothness

    for i in 0..<(corners * 2) {
      let r = (i % 2 == 0) ? radius : innerRadius
      let x = center.x + cos(angle) * r
      let y = center.y + sin(angle) * r
      if i == 0 {
        path.move(to: CGPoint(x: x, y: y))
      } else {
        path.addLine(to: CGPoint(x: x, y: y))
      }
      angle += angleIncrement
    }
    path.closeSubpath()
    return path
  }
}

/// Softer, rounded star / blob shape so the intro image is not clipped too aggressively.
struct WavyStarShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let maxRadius = min(rect.width, rect.height) / 2

    // Approximate a rounded 5‑point "starfish" using a smooth sinusoidal radius.
    let steps = 180
    for i in 0...steps {
      let progress = Double(i) / Double(steps)
      let theta = progress * 2 * Double.pi

      // 5 gentle bumps around the circle.
      let wave = 0.25 * sin(5 * theta)
      let radius = maxRadius * CGFloat(0.75 + wave)

      let x = center.x + cos(CGFloat(theta)) * radius
      let y = center.y + sin(CGFloat(theta)) * radius

      if i == 0 {
        path.move(to: CGPoint(x: x, y: y))
      } else {
        path.addLine(to: CGPoint(x: x, y: y))
      }
    }

    path.closeSubpath()
    return path
  }
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

struct PlanBulletRow: View {
  let icon: String
  let color: Color
  let text: String
  
  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 22))
        .foregroundColor(color)
        .frame(width: 32)
      Text(text)
        .font(.system(size: 17, weight: .regular, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct BalancedPlateCard: View {
  let imageName: String
  let title: String
  let scoreText: String
  let description: String
  
  private var hasImage: Bool {
    UIImage(named: imageName) != nil
  }
  
  var body: some View {
    VStack(spacing: 10) {
      Group {
        if hasImage {
          Image(imageName)
            .resizable()
            .scaledToFit()
        } else {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppTheme.textSecondary.opacity(0.12))
            .overlay(
              Image(systemName: "leaf.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
            )
        }
      }
      .frame(maxWidth: .infinity)
      .frame(minHeight: 160)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
      
      HStack {
        Text(title)
          .font(.system(size: 17, weight: .semibold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)
        Spacer()
        Text(scoreText)
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .foregroundColor(AppTheme.success)
      }
      
      Text(description)
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.surface)
    .cornerRadius(20)
    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
  }
}

struct TeamMemberCard: View {
  let imageName: String
  let name: String
  let title: String
  var linkURL: String? = nil
  /// Background image for the card (e.g. dog). When set, shown behind content with a scrim.
  var backgroundImageName: String? = nil
  /// User's profile photo URL; when set, shown in the circle instead of imageName.
  var profilePictureURL: String? = nil
  
  private var hasPhoto: Bool {
    UIImage(named: imageName) != nil
  }
  
  private var avatarView: some View {
    Group {
      if let urlString = profilePictureURL, let url = URL(string: urlString) {
        AsyncImage(url: url) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Circle()
            .fill(AppTheme.textSecondary.opacity(0.2))
            .overlay(
              Image(systemName: "person.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
            )
        }
      } else if hasPhoto {
        Image(imageName)
          .resizable()
          .scaledToFill()
      } else {
        Image(systemName: "person.circle.fill")
          .resizable()
          .scaledToFit()
          .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
      }
    }
    .frame(width: 79, height: 79)
    .clipShape(Circle())
    .overlay(
      Circle()
        .stroke(AppTheme.surface.opacity(0.5), lineWidth: 1)
    )
    .contentShape(Circle())
    .onTapGesture {
      if let urlString = linkURL, let url = URL(string: urlString) {
        UIApplication.shared.open(url)
      }
    }
  }
  
  var body: some View {
    Group {
      if backgroundImageName != nil && UIImage(named: backgroundImageName!) != nil {
        // Dog + ball layout: photo in bottom-left corner, name/title top-right; link kept
        ZStack(alignment: .bottomLeading) {
          cardBackground
          avatarView
            .padding(.leading, 11)
            .padding(.bottom, 11)
          VStack(alignment: .trailing, spacing: 4) {
            Text(name)
              .font(.system(size: 14, weight: .bold, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)
            Text(title)
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundColor(AppTheme.textSecondary)
          }
          .padding(.trailing, 11)
          .padding(.top, 11)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
      } else {
        VStack(spacing: 7) {
          avatarView
          Text(name)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
          Text(title)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(minHeight: 108)
    .padding(.vertical, 13)
    .background(backgroundImageName == nil ? cardBackground : nil)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(AppTheme.surface.opacity(0.5), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 3)
    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .onTapGesture {
      if backgroundImageName != nil, let urlString = linkURL, let url = URL(string: urlString) {
        UIApplication.shared.open(url)
      }
    }
  }
  
  @ViewBuilder
  private var cardBackground: some View {
    if let bg = backgroundImageName, UIImage(named: bg) != nil {
      ZStack {
        Image(bg)
          .resizable()
          .scaledToFill()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
        LinearGradient(
          colors: [Color.black.opacity(0.5), Color.black.opacity(0.35)],
          startPoint: .top,
          endPoint: .bottom
        )
      }
    } else {
      AppTheme.surface
    }
  }
}
