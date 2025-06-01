import SwiftUI

struct OnboardingStep {
    let title: String
    let description: String
    let anchor: String
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Welcome to Eater!",
            description: "Let's take a quick tour of the main features. We'll show you where everything is located and how to use each feature.",
            anchor: "welcome"
        ),
        OnboardingStep(
            title: "User Profile & Settings",
            description: "In the top-left corner, you'll find your profile icon. Tap it to access your profile settings, view your history, and manage your account preferences.",
            anchor: "profile"
        ),
        OnboardingStep(
            title: "Weight Tracking",
            description: "On the left side of the screen, you'll see your current weight. Tap this button to take a photo of your weight scale - the app will automatically read and record your weight.",
            anchor: "weight"
        ),
        OnboardingStep(
            title: "Calorie Counter",
            description: "In the center of the screen, you'll see your daily calorie count. The color changes based on your limits: green (good), yellow (warning), red (over limit). Tap it to set your daily calorie limits.",
            anchor: "calories"
        ),
        OnboardingStep(
            title: "Health Trends",
            description: "On the right side, you'll find the 'Trend' button. Tap it to see your health trends and get personalized recommendations based on your eating habits and weight changes.",
            anchor: "trends"
        ),
        OnboardingStep(
            title: "Food Log",
            description: "Below these controls, you'll see your food log. Each entry shows what you've eaten. To delete an item, simply swipe left on it. The list automatically updates as you add or remove items.",
            anchor: "foodlog"
        ),
        OnboardingStep(
            title: "Adding Food",
            description: "At the bottom of the screen, you'll find the main action button. Tap it to take a photo of your food - the app will automatically identify the food and add it to your log with the correct calories.",
            anchor: "addfood"
        ),
        OnboardingStep(
            title: "Health Information",
            description: "In the top-right corner, you'll see an info icon. Tap it to access important health information, disclaimers, and sources for the app's recommendations.",
            anchor: "healthinfo"
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    Text(steps[currentStep].title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(steps[currentStep].description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        if currentStep > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }
                            .foregroundColor(.white)
                        }
                        
                        Button(currentStep == steps.count - 1 ? "Get Started" : "Next") {
                            withAnimation {
                                if currentStep == steps.count - 1 {
                                    hasSeenOnboarding = true
                                    isPresented = false
                                } else {
                                    currentStep += 1
                                }
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .padding(.top)
                }
                .padding()
                .background(Color.gray.opacity(0.9))
                .cornerRadius(20)
                .padding()
                
                Spacer()
            }
        }
    }
} 