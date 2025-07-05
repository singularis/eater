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
            GeometryReader { geometry in
                ZStack {
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            Text("Share Your Feedback")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Help us improve your experience")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Feedback text area
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Feedback")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ZStack(alignment: .topLeading) {
                                if feedbackText.isEmpty {
                                    Text("Tell us what you think about the app, any issues you've encountered, or features you'd like to see...")
                                        .foregroundColor(.gray)
                                        .font(.body)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                }
                                
                                TextEditor(text: $feedbackText)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                            .frame(minHeight: 150)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                        }
                        
                        Spacer()
                        
                        // Submit button
                        Button(action: {
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
                                
                                Text(isSubmitting ? "Submitting..." : "Submit Feedback")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                        .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                        
                        // Cancel button
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                    .disabled(isSubmitting)
                }
            }
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func submitFeedback() {
        guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard let userEmail = authService.userEmail else {
            alertMessage = "Unable to submit feedback. Please try signing in again."
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
                    alertMessage = "Thank you for your feedback! We appreciate your input and will use it to improve the app."
                    showSuccessAlert = true
                } else {
                    alertMessage = "Failed to submit feedback. Please check your internet connection and try again."
                    showErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    FeedbackView(isPresented: .constant(true))
        .environmentObject({
            let authService = AuthenticationService()
            authService.setPreviewState(
                email: "preview@example.com",
                profilePictureURL: "https://lh3.googleusercontent.com/a/default-user=s120-c"
            )
            return authService
        }())
} 