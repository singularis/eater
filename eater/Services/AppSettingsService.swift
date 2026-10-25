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

  /// Pleasant or unpleasant buzz when food quality is known. On by default.
  @AppStorage("food_vibration_enabled") var vibrationEnabled: Bool = true {
    didSet { objectWillChange.send() }
  }

  /// When on, text scale is 160%. The slider itself stays 80%…150%.
  @Published var extraLargeText: Bool {
    didSet { UserDefaults.standard.set(extraLargeText, forKey: Self.extraLargeKey) }
  }

  /// Whole-app scale. Slider is 80%…150%. Extra large sets 160%.
  @Published var fontScale: Double {
    didSet {
      let clamped = min(fontScaleCeiling, max(Self.fontScaleMin, fontScale))
      if clamped != fontScale {
        fontScale = clamped
        return
      }
      UserDefaults.standard.set(fontScale, forKey: Self.fontScaleKey)
    }
  }

  static let fontScaleMin = 0.80
  static let fontScaleMax = 1.50
  static let fontScaleExtra = 1.60
  static let fontScaleStep = 0.01

  /// Past this, the home header and carb line reflow so numbers are not clipped.
  static let largeTextLayoutThreshold = 1.15

  private static let fontScaleKey = "app_dish_card_scale_v4"
  private static let extraLargeKey = "app_font_scale_extra_large"
  private static let fontScaleDefault = 1.0

  private init() {
    let extra = UserDefaults.standard.bool(forKey: Self.extraLargeKey)
    extraLargeText = extra
    if extra {
      fontScale = Self.fontScaleExtra
    } else {
      let stored = UserDefaults.standard.object(forKey: Self.fontScaleKey) as? Double
      let raw = stored ?? Self.fontScaleDefault
      fontScale = min(Self.fontScaleMax, max(Self.fontScaleMin, raw))
    }
  }

  /// Slider range. Extra large does not change this.
  var fontScaleRangeLower: Double { Self.fontScaleMin }
  var fontScaleRangeUpper: Double { Self.fontScaleMax }

  private var fontScaleCeiling: Double {
    extraLargeText ? Self.fontScaleExtra : Self.fontScaleMax
  }

  /// Header icons move aside and the carb line wraps once text is this large.
  var largeTextLayout: Bool { fontScale >= Self.largeTextLayoutThreshold }

  /// 0 at 80%, 1 at 160%. Layout that must follow the slider uses this, not a jump at 160%.
  var interfaceTravel: Double {
    let span = Self.fontScaleExtra - Self.fontScaleMin
    return min(1, max(0, (fontScale - Self.fontScaleMin) / span))
  }

  /// Graphs and other tall screens no longer fit from the top once text is this large.
  var centersTallContent: Bool { fontScale >= 1.25 }

  func setExtraLargeText(_ enabled: Bool) {
    extraLargeText = enabled
    if enabled {
      fontScale = Self.fontScaleExtra
    } else if fontScale > Self.fontScaleMax {
      fontScale = Self.fontScaleMax
    }
  }

  var dynamicTypeSize: DynamicTypeSize {
    switch fontScale {
    case ..<0.88: return .small
    case ..<0.95: return .medium
    case ..<1.05: return .large
    case ..<1.15: return .xLarge
    case ..<1.25: return .xxLarge
    case ..<1.35: return .xxxLarge
    case ..<1.60: return .accessibility1
    case ..<1.80: return .accessibility2
    default: return .accessibility3
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


