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
    
    let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Welcome to Eater! 🍎",
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
            title: "Get Personalized Insights 💡",
            description: "View your trends, manage your profile, and access health information - all designed to help you reach your wellness goals.",
            anchor: "insights",
            icon: "lightbulb.fill"
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
                VStack(spacing: 30) {
                    // Icon
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
                }
                
                Spacer()
                
                // Navigation buttons
                VStack(spacing: 16) {
                    if currentStep == steps.count - 1 {
                        // Last screen - show both options
                        VStack(spacing: 12) {
                            Button(action: {
                                // Just dismiss without setting hasSeenOnboarding
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
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep += 1
                                }
                            }) {
                                HStack {
                                    Text("Next")
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
                    }
                }
                .padding(.bottom, 50)
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
    }
} 