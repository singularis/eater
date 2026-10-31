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

  /// When on, text scale is 160%. The A buttons step 5% from 80% to 160%.
  @Published var extraLargeText: Bool {
    didSet { UserDefaults.standard.set(extraLargeText, forKey: Self.extraLargeKey) }
  }

  /// Whole-app scale. 80%…160% in 5% steps. Extra large sets 160%.
  /// Follows the phone's text size until the user picks a size in the app.
  @Published var fontScale: Double {
    didSet {
      let clamped = min(fontScaleCeiling, max(Self.fontScaleMin, fontScale))
      if clamped != fontScale {
        fontScale = clamped
        return
      }
      guard !applyingSystemScale else { return }
      UserDefaults.standard.set(fontScale, forKey: Self.fontScaleKey)
    }
  }

  private var applyingSystemScale = false

  static let fontScaleMin = 0.80
  static let fontScaleMax = 1.50
  static let fontScaleExtra = 1.60
  static let fontScaleStep = 0.05

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
    } else if let stored = UserDefaults.standard.object(forKey: Self.fontScaleKey) as? Double {
      fontScale = min(Self.fontScaleExtra, max(Self.fontScaleMin, stored))
    } else {
      fontScale = Self.systemFontScale()
    }
    NotificationCenter.default.addObserver(
      forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.followSystemTextSize()
    }
  }

  /// True while the user has not picked a size in the app.
  var followsSystemTextSize: Bool {
    !extraLargeText && UserDefaults.standard.object(forKey: Self.fontScaleKey) == nil
  }

  func followSystemTextSize() {
    guard followsSystemTextSize else { return }
    let target = Self.systemFontScale()
    guard abs(target - fontScale) > 0.001 else { return }
    applyingSystemScale = true
    fontScale = target
    applyingSystemScale = false
  }

  /// Phone text size (Settings > Display > Text Size) on the app's 5% grid.
  /// Narrow phones stop lower so the home header still fits on one row.
  static func systemFontScale() -> Double {
    let scale: Double
    switch UIApplication.shared.preferredContentSizeCategory {
    case .extraSmall: scale = 0.80
    case .small: scale = 0.85
    case .medium: scale = 0.90
    case .large: scale = 1.00
    case .extraLarge: scale = 1.10
    case .extraExtraLarge: scale = 1.20
    case .extraExtraExtraLarge: scale = 1.30
    case .accessibilityMedium: scale = 1.40
    case .accessibilityLarge, .accessibilityExtraLarge,
      .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
      scale = fontScaleMax
    default: scale = fontScaleDefault
    }
    let screenWidth = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }
      .first ?? 390
    let narrowPhone = screenWidth < 375
    return min(narrowPhone ? 1.30 : fontScaleMax, max(fontScaleMin, scale))
  }

  var fontScaleRangeLower: Double { Self.fontScaleMin }
  var fontScaleRangeUpper: Double { Self.fontScaleExtra }

  /// 160% is always allowed. The A buttons step through 155% on the way to extra large.
  private var fontScaleCeiling: Double { Self.fontScaleExtra }

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

  /// One tap on the small or large A. Snaps onto the 5% grid, then moves one step.
  func stepFontScale(_ direction: Int) {
    let percent = fontScale * 100
    let next: Double
    if direction > 0 {
      next = min(160, floor(percent / 5 + 0.000001) * 5 + 5)
    } else {
      next = max(80, ceil(percent / 5 - 0.000001) * 5 - 5)
    }
    extraLargeText = next >= 159.5
    fontScale = next / 100
  }

  /// Back to the phone's text size.
  func resetFontScale() {
    extraLargeText = false
    UserDefaults.standard.removeObject(forKey: Self.fontScaleKey)
    applyingSystemScale = true
    fontScale = Self.systemFontScale()
    applyingSystemScale = false
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
    // Each guest session is a brand-new anon_<uuid> account, so the old device-wide
    // flag must not count for it, or a guest on a used phone never sees onboarding.
    let resolvedEmail = email ?? defaults.string(forKey: "user_email")
    if AnonymousUserIdentity.isAnonymousEmail(resolvedEmail) {
      return false
    }
    // One-time migrate old device-wide flag so existing users are not shown again
    if defaults.bool(forKey: base) {
      defaults.set(true, forKey: accountKey(base, email: email))
      return true
    }
    return false
  }

  private static let perAccountFlags = [
    "hasSeenOnboarding", "health_onboarding_shown", "social_onboarding_shown",
  ]

  /// Guest upgraded to a real account: what the guest already saw counts for the account.
  func carryOnboardingFlags(from oldEmail: String?, to newEmail: String?) {
    guard let oldEmail, let newEmail, oldEmail.lowercased() != newEmail.lowercased() else { return }
    let defaults = UserDefaults.standard
    for base in Self.perAccountFlags where defaults.bool(forKey: accountKey(base, email: oldEmail)) {
      defaults.set(true, forKey: accountKey(base, email: newEmail))
    }
    objectWillChange.send()
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


