import SwiftUI

struct LanguageSelectionSheet: View {
  @EnvironmentObject var languageService: LanguageService
  @Binding var isPresented: Bool

  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
        List {
        ForEach(languageService.availableLanguagesDetailed(), id: \.code) { item in
          Button(action: {
            languageService.setLanguage(
              code: item.code, displayName: item.nativeName, syncWithBackend: true
            ) { _ in }
            isPresented = false
          }) {
            HStack(spacing: 12) {
              Text(item.flag)
              Text(item.nativeName)
                .foregroundColor(AppTheme.textPrimary)
              Spacer()
              if languageService.currentCode == item.code {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(AppTheme.success)
              }
            }
          }
          .buttonStyle(PressScaleButtonStyle())
        }
        }
        .scrollContentBackground(.hidden)
      }
      .navigationTitle(loc("profile.language", "Language"))
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(loc("common.close", "Close")) { isPresented = false }
            .foregroundColor(AppTheme.textPrimary)
        }
      }
    }
  }
}
