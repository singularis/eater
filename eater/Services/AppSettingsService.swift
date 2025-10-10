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


