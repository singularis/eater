import SwiftUI

struct MainAppTutorialView: View {
  @Binding var isPresented: Bool
  var specificStep: TutorialStep? = nil

  @State private var currentPage = 0
  @EnvironmentObject var languageService: LanguageService

  struct TutorialStep: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let title: String
    let description: String
    let iconName: String
    let color: Color
  }

  static var steps: [TutorialStep] {
    [
      TutorialStep(
        key: "hasSeenCameraTutorial",
        title: loc("tutorial.camera.title", "Snap a meal 📸"),
        description: loc("tutorial.camera.desc", "The blue camera button is how you add food. Take a photo of your plate and Eateria logs calories and nutrients for you."),
        iconName: "camera.fill",
        color: AppTheme.accent
      ),
      TutorialStep(
        key: "hasSeenCaloriesTutorial",
        title: loc("tutorial.cals.title", "Calorie Goals 🔥"),
        description: loc("tutorial.cals.desc", "Tap the flame icon to set your daily calorie limits."),
        iconName: "flame.fill",
        color: .orange
      ),
      TutorialStep(
        key: "hasSeenHealthScoreTutorial",
        title: loc("tutorial.bml.title", "Health Score 🏅"),
        description: loc("tutorial.bml.desc", "Check your daily health rank (0-100) based on food quality."),
        iconName: "info.circle",
        color: .green
      ),
      TutorialStep(
        key: "hasSeenSportTutorial",
        title: loc("tutorial.sport.title", "Track Activity 🏃"),
        description: loc("tutorial.sport.desc", "Log your workouts to earn extra calories for the day."),
        iconName: "figure.run",
        color: .blue
      ),
      TutorialStep(
        key: "hasSeenWeightTutorial",
        title: loc("tutorial.weight.title", "Weight Tracking ⚖️"),
        description: loc("tutorial.weight.desc", "Tap the weight display to update your progress."),
        iconName: "figure.stand",
        color: .purple
      ),
      TutorialStep(
        key: "hasSeenTypeGuide",
        title: loc("tutorial.type.title", "Type a meal ✏️"),
        description: loc(
          "tutorial.type.desc",
          "Write what you ate. No photo needed. Add the amount if you know it, such as 200g or 1 cup. For example: rice and vegetables 200g, an apple 150g, or oatmeal with banana. We estimate the calories."
        ),
        iconName: "square.and.pencil",
        color: AppTheme.accent
      ),
      TutorialStep(
        key: "hasSeenCalendarTutorial",
        title: loc("tutorial.calendar.title", "Calendar & History 📅"),
        description: loc("tutorial.calendar.desc", "Tap the date to view past meals or check your streaks."),
        iconName: "calendar",
        color: .red
      ),
      TutorialStep(
        key: "hasSeenAlcoholTutorial",
        title: loc("tutorial.alcohol.title", "Alcohol Tracker 🍷"),
        description: loc("tutorial.alcohol.desc", "Keep an eye on alcohol consumption separately."),
        iconName: "wineglass",
        color: .pink
      ),
      TutorialStep(
        key: "hasSeenStatsTutorial",
        title: loc("tutorial.stats.title", "Your Stats 📊"),
        description: loc("tutorial.stats.desc", "Stats shows calories, weight, and how your week is going. Open it anytime from the tab bar."),
        iconName: "chart.bar.fill",
        color: AppTheme.primaryButtonFill
      ),
    ]
  }

  private var displayedSteps: [TutorialStep] {
    if let specific = specificStep { return [specific] }
    return MainAppTutorialView.steps
  }

  private var step: TutorialStep {
    displayedSteps[min(currentPage, displayedSteps.count - 1)]
  }

  private var canGoBack: Bool {
    specificStep == nil && currentPage > 0
  }

  var body: some View {
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

        if specificStep == nil {
          Button(action: finishTutorial) {
            Text(loc("common.skip", "Skip"))
              .font(.body.weight(.medium))
              .foregroundColor(AppTheme.textPrimary)
              .padding(.horizontal, 16)
              .frame(height: 36)
              .background(AppTheme.surface)
              .clipShape(Capsule())
              .overlay(Capsule().stroke(AppTheme.divider, lineWidth: 1))
          }
          .buttonStyle(.plain)
        }
      }
      .frame(height: 52)
      .padding(.horizontal, 24)

      ScrollView(showsIndicators: false) {
        TutorialCardView(step: step)
          .padding(.horizontal, 24)
          .padding(.top, 12)
          .padding(.bottom, 8)
      }

      VStack(spacing: 14) {
        HStack(spacing: 6) {
          if displayedSteps.count > 1 {
            ForEach(0..<displayedSteps.count, id: \.self) { index in
              Capsule()
                .fill(index == currentPage ? AppTheme.accent : AppTheme.divider)
                .frame(width: index == currentPage ? 18 : 6, height: 6)
            }
          }
        }
        .frame(height: 8)

        Button(action: nextStep) {
          Text(buttonText)
            .font(.body.weight(.semibold))
        }
        .buttonStyle(PrimaryButtonStyle())
      }
      .padding(.horizontal, 24)
      .padding(.top, 8)
      .padding(.bottom, 12)
    }
    .modifier(TutorialBackground(isSheet: specificStep != nil))
    .presentationDragIndicator(.visible)
    .presentationDetents(specificStep == nil ? [.large] : [.medium, .large])
  }

  private var buttonText: String {
    if specificStep != nil { return loc("common.done", "Done") }
    return currentPage == displayedSteps.count - 1
      ? loc("onboarding.start", "Get Started")
      : loc("onboarding.continue", "Continue")
  }

  private func goBack() {
    guard canGoBack else { return }
    HapticsService.shared.select()
    withAnimation(.easeInOut(duration: 0.25)) { currentPage -= 1 }
  }

  private func nextStep() {
    HapticsService.shared.select()
    if currentPage < displayedSteps.count - 1 {
      withAnimation(.easeInOut(duration: 0.25)) { currentPage += 1 }
    } else {
      finishTutorial()
    }
  }

  private func finishTutorial() {
    if let specific = specificStep {
      KeychainHelper.shared.setBool(true, for: specific.key)
    } else {
      KeychainHelper.shared.setBool(true, for: "hasSeenMainAppTutorial")
    }
    isPresented = false
  }
}

/// Single-step sheets sit on glass. The full tutorial is a full-screen cover, so it keeps the opaque gradient.
private struct TutorialBackground: ViewModifier {
  let isSheet: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if isSheet {
      content.appSheetBackground()
    } else {
      content.background(AppTheme.backgroundGradient.ignoresSafeArea())
    }
  }
}

struct TutorialCardView: View {
  let step: MainAppTutorialView.TutorialStep
  @ObservedObject var themeService = ThemeService.shared

  var body: some View {
    VStack(spacing: 18) {
      ZStack {
        Circle()
          .fill(step.color.opacity(0.12))
          .frame(width: 88, height: 88)
        Image(systemName: themeService.icon(for: step.iconName))
          .font(.system(size: 36, weight: .semibold))
          .foregroundStyle(step.color)
      }

      Text(step.title.removingTutorialEmoji)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      Text(step.description)
        .font(.body)
        .foregroundColor(AppTheme.textSecondary)
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }
}

private extension String {
  var removingTutorialEmoji: String {
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
