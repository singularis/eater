import SwiftUI

final class AppSettingsService: ObservableObject {
  enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark
  }

  static let shared = AppSettingsService()

  @AppStorage("app_appearance_mode") var storedAppearance: String = AppearanceMode.system.rawValue {
    didSet { objectWillChange.send() }
  }

  @AppStorage("app_reduce_motion") var reduceMotion: Bool = false {
    didSet { objectWillChange.send() }
  }

  @AppStorage("save_photos_to_library") var savePhotosToLibrary: Bool = true {
    didSet { objectWillChange.send() }
  }

  @AppStorage("food_shared_count") var foodSharedCount: Int = 0 {
    didSet { objectWillChange.send() }
  }

  @AppStorage("food_scanned_count") var foodScannedCount: Int = 0 {
    didSet { objectWillChange.send() }
  }

  @AppStorage("health_onboarding_shown") var healthOnboardingShown: Bool = false {
    didSet { objectWillChange.send() }
  }

  @AppStorage("social_onboarding_shown") var socialOnboardingShown: Bool = false {
    didSet { objectWillChange.send() }
  }

  var shouldShowHealthOnboarding: Bool {
      // Show after 2 scans if not already shown
      return foodScannedCount >= 2 && !healthOnboardingShown
  }
  
  var shouldShowSocialOnboarding: Bool {
      // Show after 5 scans if not already shown
      return foodScannedCount >= 5 && !socialOnboardingShown
  }

  @AppStorage("progressive_onboarding_level") var progressiveOnboardingLevel: Int = 0 {
    didSet { objectWillChange.send() }
  }

  var appearance: AppearanceMode {
    get { AppearanceMode(rawValue: storedAppearance) ?? .system }
    set { storedAppearance = newValue.rawValue }
  }

  var scheme: ColorScheme? {
    switch appearance {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}


