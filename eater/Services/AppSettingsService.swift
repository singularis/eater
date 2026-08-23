import SwiftUI

final class AppSettingsService: ObservableObject {
  enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark
  }

  static let shared = AppSettingsService()

  @AppStorage("app_appearance_mode") var storedAppearance: String = AppearanceMode.light.rawValue {
    didSet { objectWillChange.send() }
  }

  @AppStorage("app_reduce_motion") var reduceMotion: Bool = false {
    didSet { objectWillChange.send() }
  }

  @AppStorage("save_photos_to_library") var savePhotosToLibrary: Bool = true {
    didSet { objectWillChange.send() }
  }

  /// Home meal-card scale. Slider 80%…120%, step 1%.
  @Published var fontScale: Double {
    didSet { UserDefaults.standard.set(fontScale, forKey: Self.fontScaleKey) }
  }

  static let fontScaleMin = 0.80
  static let fontScaleMax = 1.20
  static let fontScaleStep = 0.01

  private static let fontScaleKey = "app_dish_card_scale_v4"
  private static let fontScaleDefault = 1.0

  private init() {
    let stored = UserDefaults.standard.object(forKey: Self.fontScaleKey) as? Double
    let raw = stored ?? Self.fontScaleDefault
    fontScale = min(Self.fontScaleMax, max(Self.fontScaleMin, raw))
  }

  var dynamicTypeSize: DynamicTypeSize {
    switch fontScale {
    case ..<0.88: return .small
    case ..<0.95: return .medium
    case ..<1.05: return .large
    case ..<1.15: return .xLarge
    case ..<1.25: return .xxLarge
    case ..<1.35: return .xxxLarge
    default: return .accessibility1
    }
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

  /// Per-account flag so the same person does not see the tutorial again after logout.
  private func accountKey(_ base: String, email: String?) -> String {
    let id = (email ?? UserDefaults.standard.string(forKey: "user_email") ?? "unknown")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    return "\(base).\(id)"
  }

  private func accountFlag(_ base: String, email: String?) -> Bool {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: accountKey(base, email: email)) {
      return true
    }
    // One-time migrate old device-wide flag so existing users are not shown again
    if defaults.bool(forKey: base) {
      defaults.set(true, forKey: accountKey(base, email: email))
      return true
    }
    return false
  }

  func hasCompletedInitialOnboarding(for email: String?) -> Bool {
    accountFlag("hasSeenOnboarding", email: email)
  }

  func markInitialOnboardingSeen(for email: String?) {
    UserDefaults.standard.set(true, forKey: accountKey("hasSeenOnboarding", email: email))
    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    objectWillChange.send()
  }

  func shouldShowHealthOnboarding(for email: String? = nil) -> Bool {
    foodScannedCount >= 2 && !accountFlag("health_onboarding_shown", email: email)
  }

  func shouldShowSocialOnboarding(for email: String? = nil) -> Bool {
    foodScannedCount >= 5 && !accountFlag("social_onboarding_shown", email: email)
  }

  func markHealthOnboardingSeen(for email: String?) {
    UserDefaults.standard.set(true, forKey: accountKey("health_onboarding_shown", email: email))
    healthOnboardingShown = true
  }

  func markSocialOnboardingSeen(for email: String?) {
    UserDefaults.standard.set(true, forKey: accountKey("social_onboarding_shown", email: email))
    socialOnboardingShown = true
  }

  var shouldShowHealthOnboarding: Bool {
    shouldShowHealthOnboarding(for: nil)
  }

  var shouldShowSocialOnboarding: Bool {
    shouldShowSocialOnboarding(for: nil)
  }

  @AppStorage("progressive_onboarding_level") var progressiveOnboardingLevel: Int = 0 {
    didSet { objectWillChange.send() }
  }

  var appearance: AppearanceMode {
    get {
      let mode = AppearanceMode(rawValue: storedAppearance) ?? .light
      return mode == .system ? .light : mode
    }
    set { storedAppearance = newValue == .system ? AppearanceMode.light.rawValue : newValue.rawValue }
  }

  var scheme: ColorScheme? {
    switch appearance {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}


