import SwiftUI

/// Explains what the app does and how user data is handled, shown from the login screen
/// so people can evaluate the app before signing in.
struct AppInfoView: View {
  @Environment(\.dismiss) private var dismiss
  // Read so the view re-renders when the phone switches light/dark;
  // AppTheme resolves its colors from the current trait collection.
  @Environment(\.colorScheme) private var systemColorScheme

  var body: some View {
    let _ = systemColorScheme
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)

        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            Text(loc("info.intro", "Eateria turns a photo of your meal into a full nutrition log, so tracking what you eat takes seconds instead of minutes."))
              .font(.body)
              .foregroundColor(AppTheme.textPrimary)
              .fixedSize(horizontal: false, vertical: true)

            section(title: loc("info.section.how", "How it works")) {
              VStack(alignment: .leading, spacing: 14) {
                step(1, loc("info.how.step1", "Take a photo of your meal or pick one from your library."))
                step(2, loc("info.how.step2", "AI identifies the dish and estimates calories, protein, fat and carbs."))
                step(3, loc("info.how.step3", "Review your day, adjust portions and watch your progress."))
              }
            }

            section(title: loc("info.section.features", "What you get")) {
              VStack(alignment: .leading, spacing: 12) {
                bullet("camera.viewfinder", loc("info.features.food", "Automatic food recognition and calorie tracking"))
                bullet("chart.bar.fill", loc("info.features.stats", "Charts for calories, macros and weight trends"))
                bullet("figure.run", loc("info.features.activity", "Activity and alcohol logging that adjusts your daily limit"))
                bullet("person.2.fill", loc("info.features.social", "Share meals with friends and sync across devices"))
              }
            }

            section(title: loc("info.section.privacy", "Your privacy")) {
              Text(
                loc(
                  "info.privacy.text",
                  "You sign in with Apple or Google, so we never see a password. Your data is encrypted in transit, stored on secured servers, and is never sold to advertisers."
                )
              )
              .font(.body)
              .foregroundColor(AppTheme.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
            }

            section(title: loc("info.section.guest", "Trying without an account")) {
              Text(
                loc(
                  "info.guest.text",
                  "\"Let Me Try\" starts a guest session with every feature unlocked. Sign in whenever you are ready to keep your history and use the app on more devices."
                )
              )
              .font(.body)
              .foregroundColor(AppTheme.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(20)
        }
      }
      .navigationTitle(loc("info.title", "About Eateria"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(loc("common.close", "Close")) {
            HapticsService.shared.select()
            dismiss()
          }
          .foregroundColor(AppTheme.textPrimary)
        }
      }
    }
  }

  // MARK: - Building blocks

  private func section<Content: View>(
    title: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardContainer(padding: 16)
  }

  private func step(_ number: Int, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(number)")
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .frame(width: 26, height: 26)
        .background(Circle().fill(AppTheme.accent))

      Text(text)
        .font(.subheadline)
        .foregroundColor(AppTheme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func bullet(_ icon: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(AppTheme.accent)
        .frame(width: 22)

      Text(text)
        .font(.subheadline)
        .foregroundColor(AppTheme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

#Preview {
  AppInfoView()
}
