import SwiftUI

struct FeedbackView: View {
  @EnvironmentObject var authService: AuthenticationService
  @Binding var isPresented: Bool
  @State private var feedbackText = ""
  @State private var isSubmitting = false
  @State private var showSuccessAlert = false
  @State private var showErrorAlert = false
  @State private var alertMessage = ""

  var body: some View {
    NavigationView {
      GeometryReader { _ in
        ZStack {
          AppTheme.backgroundGradient
            .edgesIgnoringSafeArea(.all)

          VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
              Text(loc("feedback.title", "Share Your Feedback"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)

              Text(loc("feedback.subtitle", "Help us improve your experience"))
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Feedback text area
            VStack(alignment: .leading, spacing: 8) {
              Text(loc("feedback.field.label", "Your Feedback"))
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

              ZStack(alignment: .topLeading) {
                if feedbackText.isEmpty {
                  Text(
                    loc(
                      "feedback.placeholder",
                      "Tell us what you think about the app, any issues you've encountered, or features you'd like to see..."
                    )
                  )
                  .foregroundColor(AppTheme.textSecondary)
                  .font(.body)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                }

                TextEditor(text: $feedbackText)
                  .font(.body)
                  .foregroundColor(AppTheme.textPrimary)
                  .scrollContentBackground(.hidden)
                  .background(Color.clear)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
              }
              .frame(minHeight: 150)
              .background(AppTheme.surface)
              .cornerRadius(AppTheme.smallRadius)
              .overlay(
                RoundedRectangle(cornerRadius: AppTheme.smallRadius)
                  .stroke(AppTheme.divider, lineWidth: 1)
              )
            }

            Spacer()

            // Submit button
            Button(action: {
              HapticsService.shared.mediumImpact()
              submitFeedback()
            }) {
              HStack {
                if isSubmitting {
                  ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                } else {
                  Image(systemName: "paperplane.fill")
                }
                Text(
                  isSubmitting
                    ? loc("feedback.submitting", "Submitting...")
                    : loc("feedback.submit", "Submit Feedback")
                )
                .fontWeight(.semibold)
              }
              .font(.subheadline)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(
              feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            .disabled(
              feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

            // Cancel button
            Button(action: {
              HapticsService.shared.select()
              isPresented = false
            }) {
              Text(loc("common.cancel", "Cancel"))
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isSubmitting)
            
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
        }
      }
      .navigationTitle(loc("feedback.nav", "Feedback"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(loc("common.close", "Close")) {
            isPresented = false
          }
          .foregroundColor(AppTheme.textPrimary)
          .disabled(isSubmitting)
        }
      }
    }
    .alert(loc("common.done", "Done"), isPresented: $showSuccessAlert) {
      Button(loc("common.ok", "OK")) {
        isPresented = false
      }
    } message: {
      Text(alertMessage)
    }
    .alert(loc("common.error", "Error"), isPresented: $showErrorAlert) {
      Button(loc("common.ok", "OK")) {}
    } message: {
      Text(alertMessage)
    }
  }

  private func submitFeedback() {
    guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

    guard let userEmail = authService.userEmail else {
      alertMessage = loc(
        "feedback.need_login", "Unable to submit feedback. Please try signing in again.")
      showErrorAlert = true
      return
    }

    isSubmitting = true

    GRPCService().submitFeedback(
      time: ISO8601DateFormatter().string(from: Date()),
      userEmail: userEmail,
      feedback: feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
    ) { success in
      DispatchQueue.main.async {
        isSubmitting = false

        if success {
          HapticsService.shared.success()
          alertMessage = loc(
            "feedback.success",
            "Thank you for your feedback! We appreciate your input and will use it to improve the app."
          )
          showSuccessAlert = true
        } else {
          HapticsService.shared.error()
          alertMessage = loc(
            "feedback.fail",
            "Failed to submit feedback. Please check your internet connection and try again.")
          showErrorAlert = true
        }
      }
    }
  }
}

#Preview {
  FeedbackView(isPresented: .constant(true))
    .environmentObject(
      {
        let authService = AuthenticationService()
        authService.setPreviewState(
          email: "preview@example.com",
          profilePictureURL: "https://lh3.googleusercontent.com/a/default-user=s120-c"
        )
        return authService
      }())
}
