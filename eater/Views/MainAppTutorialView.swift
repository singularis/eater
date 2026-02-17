
import SwiftUI

import SwiftUI


struct MainAppTutorialView: View {
    @Binding var isPresented: Bool
    var specificStep: TutorialStep? = nil // If set, only show this step
    
    @State private var currentPage = 0
    @EnvironmentObject var languageService: LanguageService
    
    // Animation state
    @State private var appearAnimation = false
    
    struct TutorialStep: Identifiable, Equatable {
        let id = UUID()
        let key: String // Keychain key
        let title: String
        let description: String
        let iconName: String
        let color: Color
    }
    
    static var steps: [TutorialStep] {
        [
            TutorialStep(
                key: "hasSeenCameraTutorial",
                title: loc("tutorial.camera.title", "Snap & Track 📸"),
                description: loc("tutorial.camera.desc", "Take a photo of your meal to instantly analyze calories and nutrients."),
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
                iconName: "figure.stand", // Changed from scalemass.fill
                color: .purple
            ),
            TutorialStep(
                key: "hasSeenAdviceTutorial",
                title: loc("tutorial.advice.title", "Daily Advice 💡"),
                description: loc("tutorial.advice.desc", "Get personalized insights and tips to improve your diet."),
                iconName: "sparkles",
                color: .yellow
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
            )
        ]
    }
    
    private var displayedSteps: [TutorialStep] {
        if let specific = specificStep {
            return [specific]
        }
        return MainAppTutorialView.steps
    }

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
                // Header / Drag Indicator for sheet
                HStack {
                    if specificStep != nil {
                        Spacer()
                        // Drag Indicator
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 5)
                            .padding(.top, 10)
                        Spacer()
                    } else {
                        // Full tutorial mode - Skip button
                        Spacer()
                        Button(action: finishTutorial) {
                            Text(loc("common.skip", "Skip"))
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding()
                    }
                }
                
                TabView(selection: $currentPage) {
                    ForEach(0..<displayedSteps.count, id: \.self) { index in
                        TutorialCardView(step: displayedSteps[index], appearAnimation: appearAnimation)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Indicators (only for multi-step)
                if displayedSteps.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<displayedSteps.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? AppTheme.accent : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 10)
                }
                
                // Button
                Button(action: nextStep) {
                    Text(buttonText)
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
            }
        }
        .onAppear {
            withAnimation { appearAnimation = true }
        }
    }
    
    private var buttonText: String {
        if specificStep != nil {
            return loc("common.done", "Done")
        }
        return currentPage == displayedSteps.count - 1 ? loc("common.start", "Get Started") : loc("common.next", "Next")
    }
    
    private func nextStep() {
        if currentPage < displayedSteps.count - 1 {
            withAnimation {
                currentPage += 1
            }
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
        withAnimation {
            isPresented = false
        }
    }
}

struct TutorialCardView: View {
    let step: MainAppTutorialView.TutorialStep
    var appearAnimation: Bool
    @ObservedObject var themeService = ThemeService.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon with Pulse
            ZStack {
                Circle()
                    .fill(step.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(appearAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: appearAnimation)
                
                Image(systemName: themeService.icon(for: step.iconName))
                    .font(.system(size: 50))
                    .foregroundStyle(step.color)
                    .symbolEffect(.bounce, value: appears) // Using a constant or state if available, or just static
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(step.description)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // Helper property to satisfy symbolEffect value requirement
    private var appears: Bool { appearAnimation }
}

