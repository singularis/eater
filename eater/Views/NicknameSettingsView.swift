import SwiftUI

struct NicknameSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var nickname: String = ""
  @State private var isLoading: Bool = false
  @State private var errorMessage: String = ""
  @State private var showAlert: Bool = false
  @State private var alertMessage: String = ""
  @State private var alertTitle: String = ""
  @AppStorage("user_email") private var userEmail: String = ""
  @AppStorage("user_nickname") private var savedNickname: String = ""
  
  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient
          .edgesIgnoringSafeArea(.all)
        
        VStack(spacing: 24) {
          // Icon Header
          ZStack {
            Circle()
              .fill(AppTheme.accent.opacity(0.1))
              .frame(width: 100, height: 100)
            
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
          .padding(.top, 30)
          
          VStack(spacing: 12) {
            Text(loc("nickname.title", "Set Your Nickname"))
              .font(.system(size: 28, weight: .bold, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)
            
            Text(loc("nickname.description", "Choose a nickname to share with friends instead of your email address."))
              .font(.system(size: 16))
              .foregroundColor(AppTheme.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 20)
          }
          
          // Input Section
          VStack(alignment: .leading, spacing: 12) {
            Text(loc("nickname.label", "Nickname (1-50 characters)"))
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(AppTheme.textSecondary)
            
            TextField(loc("nickname.placeholder", "Enter your nickname"), text: $nickname)
              .textFieldStyle(.plain)
              .padding(16)
              .background(AppTheme.surface)
              .cornerRadius(AppTheme.cornerRadius)
              .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                  .stroke(errorMessage.isEmpty ? AppTheme.divider : AppTheme.danger, lineWidth: 1)
              )
              .autocapitalization(.none)
              .disableAutocorrection(true)
              .disabled(isLoading)
              .onChange(of: nickname) { _ in errorMessage = "" }
            
            if !errorMessage.isEmpty {
              Text(errorMessage)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.danger)
                .padding(.leading, 4)
            }
            
            // Character count
            Text("\(nickname.count)/50")
              .font(.system(size: 12))
              .foregroundColor(nickname.count > 50 ? AppTheme.danger : AppTheme.textSecondary)
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
          .cardContainer(padding: 16)
          .padding(.horizontal, 20)
          
          // Info Box - Apple Hidden Email Detection
          if isAppleHiddenEmail(userEmail) {
            HStack(spacing: 12) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppTheme.warning)
              
              VStack(alignment: .leading, spacing: 4) {
                Text(loc("nickname.apple_warning", "Apple ID Detected"))
                  .font(.system(size: 14, weight: .semibold))
                  .foregroundColor(AppTheme.textPrimary)
                
                Text(loc("nickname.apple_warning_desc", "Since you're using Sign in with Apple, setting a nickname will help friends identify you."))
                  .font(.system(size: 12))
                  .foregroundColor(AppTheme.textSecondary)
              }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.warning.opacity(0.1))
            .cornerRadius(AppTheme.smallRadius)
            .overlay(
              RoundedRectangle(cornerRadius: AppTheme.smallRadius)
                .stroke(AppTheme.warning.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 20)
          }
          
          Spacer()
          
          // Save Button
          Button(action: saveNickname) {
            if isLoading {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .frame(maxWidth: .infinity)
            } else {
              Text(loc("nickname.save", "Save Nickname"))
                .frame(maxWidth: .infinity)
            }
          }
          .buttonStyle(PrimaryButtonStyle())
          .disabled(isLoading || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nickname.count > 50)
          .padding(.horizontal, 20)
          .padding(.bottom, 30)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarItems(
        leading: Button(action: { dismiss() }) {
          Image(systemName: "xmark")
            .foregroundColor(AppTheme.textPrimary)
        }
      )
      .onAppear {
        nickname = savedNickname
      }
      .alert(alertTitle, isPresented: $showAlert) {
        Button(loc("common.ok", "OK")) {}
      } message: {
        Text(alertMessage)
      }
    }
  }
  
  private func isAppleHiddenEmail(_ email: String) -> Bool {
    return email.contains("@privaterelay.appleid.com")
  }
  
  /// Only Latin lowercase letters and digits (a-z, 0-9).
  private static func isNicknameValid(_ s: String) -> Bool {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
    return s.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  private func saveNickname() {
    let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    
    guard !trimmed.isEmpty else {
      errorMessage = loc("nickname.empty_error", "Nickname cannot be empty")
      return
    }
    
    guard trimmed.count <= 50 else {
      errorMessage = loc("nickname.length_error", "Nickname must be 50 characters or less")
      return
    }

    guard Self.isNicknameValid(trimmed) else {
      errorMessage = loc("nickname.latin_lowercase_error", "Only Latin lowercase letters and digits (a-z, 0-9)")
      return
    }
    
    errorMessage = ""
    isLoading = true
    HapticsService.shared.select()
    
    GRPCService().updateNickname(nickname: trimmed) { success, errorMsg in
      DispatchQueue.main.async {
        self.isLoading = false
        
        if success {
          savedNickname = trimmed
          nickname = trimmed
          HapticsService.shared.success()
          alertTitle = loc("success.title", "Success")
          alertMessage = loc("nickname.success", "Your nickname has been updated successfully!")
          showAlert = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
          }
        } else {
          HapticsService.shared.error()
          let raw = (errorMsg ?? "").lowercased()
          if raw.contains("already taken") || raw.contains("taken") {
            errorMessage = loc("nickname.taken_error", "This nickname is already taken")
          } else if raw.contains("latin") || raw.contains("lowercase") {
            errorMessage = loc("nickname.latin_lowercase_error", "Only Latin lowercase letters and digits (a-z, 0-9)")
          } else {
            errorMessage = errorMsg ?? loc("nickname.error", "Failed to update nickname. Please try again.")
          }
        }
      }
    }
  }
}
