import Foundation
import SwiftUI

final class LanguageService: ObservableObject {
  static let shared = LanguageService()

  @Published private(set) var currentCode: String
  @Published private(set) var currentDisplayName: String

  private let defaults = UserDefaults.standard
  private let languageKey = "app_language_code"
  private let displayNameKey = "app_language_name"

  private init() {
    // Load stored or detect device preferred language
    if let stored = defaults.string(forKey: languageKey), !stored.isEmpty {
      print("[LanguageService] init: using stored code=\(stored)")
      currentCode = stored
      // Prefer native name for consistent display across app restarts
      let native = LanguageService.nativeNameStatic(for: stored)
      currentDisplayName = native
      defaults.set(native, forKey: displayNameKey)
      defaults.synchronize()
    } else if let deviceCode = Locale.preferredLanguages.first.flatMap({
      Locale(identifier: $0).language.languageCode?.identifier
    }) {
      let normalized = LanguageService.normalize(code: deviceCode)
      print(
        "[LanguageService] init: using device preferred code=\(deviceCode) normalized=\(normalized)"
      )
      currentCode = normalized
      currentDisplayName = LanguageService.nativeNameStatic(for: normalized)
      defaults.set(normalized, forKey: languageKey)
      defaults.set(currentDisplayName, forKey: displayNameKey)
      defaults.synchronize()
    } else {
      print("[LanguageService] init: fallback to en")
      currentCode = "en"
      currentDisplayName = "English"
    }
  }

  // MARK: - Available Languages

  /// Discover available language codes by scanning bundled files in `Localization/*.json`.
  /// Falls back to `languages.txt` if folder-based discovery fails.
  func availableLanguageCodes() -> [String] {
    // Scan the bundled Localization directory for json files like "en.json"
    if let dirURL = Bundle.main.url(forResource: "Localization", withExtension: nil) {
      do {
        let fm = FileManager.default
        let urls = try fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
        let codes =
          urls
          .filter { $0.pathExtension.lowercased() == "json" }
          .map { $0.deletingPathExtension().lastPathComponent.lowercased() }
          .map { LanguageService.normalize(code: $0) }
        let unique = Array(Set(codes)).sorted {
          $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        if !unique.isEmpty { return unique }
      } catch {
        // Ignore and fall back
      }
    }
    // Fallback: infer from languages.txt display names → codes
    let names = loadAvailableLanguages()
    let codes = names.map { code(for: $0) }
    return Array(Set(codes)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// Return tuples of (code, native name, flag emoji) for presenting to users.
  func availableLanguagesDetailed() -> [(code: String, nativeName: String, flag: String)] {
    let codes = availableLanguageCodes()
    return codes.map { c in
      let native = nativeName(for: c)
      let flag = flagEmoji(forLanguageCode: c)
      return (c, native, flag)
    }.sorted { $0.nativeName.localizedCaseInsensitiveCompare($1.nativeName) == .orderedAscending }
  }

  func nativeName(for code: String) -> String {
    let norm = LanguageService.normalize(code: code)
    // Try to get native name using the locale itself
    if let name = Locale(identifier: norm).localizedString(forLanguageCode: norm) {
      return name.capitalized
    }
    // Fallback to current locale
    if let name = Locale.current.localizedString(forLanguageCode: norm) {
      return name.capitalized
    }
    return norm.uppercased()
  }

  // Static variant safe for use during initialization
  static func nativeNameStatic(for code: String) -> String {
    let norm = LanguageService.normalize(code: code)
    if let name = Locale(identifier: norm).localizedString(forLanguageCode: norm) {
      return name.capitalized
    }
    if let name = Locale.current.localizedString(forLanguageCode: norm) {
      return name.capitalized
    }
    return norm.uppercased()
  }

  func setLanguage(
    code: String, displayName: String? = nil, syncWithBackend: Bool = true,
    completion: ((Bool) -> Void)? = nil
  ) {
    let normalized = LanguageService.normalize(code: code)
    print(
      "[LanguageService] setLanguage requested code=\(code) normalized=\(normalized) syncWithBackend=\(syncWithBackend)"
    )
    DispatchQueue.main.async {
      self.objectWillChange.send()
      self.currentCode = normalized
      // Always use native name unless explicitly provided
      self.currentDisplayName = displayName ?? self.nativeName(for: normalized)
      self.defaults.set(normalized, forKey: self.languageKey)
      self.defaults.set(self.currentDisplayName, forKey: self.displayNameKey)
      self.defaults.synchronize()
      print(
        "[LanguageService] setLanguage updated state code=\(self.currentCode) displayName=\(self.currentDisplayName)"
      )
      // Notify observers (e.g., notification scheduling) that language changed
      NotificationCenter.default.post(name: .appLanguageChanged, object: nil)
    }

    guard syncWithBackend, let email = UserDefaults.standard.string(forKey: "user_email") else {
      print("[LanguageService] setLanguage skipping backend sync (no email or disabled)")
      completion?(true)
      return
    }
    print("[LanguageService] setLanguage calling backend for email=\(email)")
    GRPCService().setLanguage(userEmail: email, languageCode: normalized) { success in
      print("[LanguageService] backend setLanguage finished success=\(success)")
      if !success {
        // Fallback to English
        DispatchQueue.main.async {
          print("[LanguageService] backend failed, falling back to en")
          self.currentCode = "en"
          self.currentDisplayName = self.nativeName(for: "en")
          self.defaults.set("en", forKey: self.languageKey)
          self.defaults.set(self.currentDisplayName, forKey: self.displayNameKey)
          self.defaults.synchronize()
          NotificationCenter.default.post(name: .appLanguageChanged, object: nil)
        }
      } else {
        // success
      }
      completion?(success)
    }
  }

  // Load list from bundled languages.txt
  func loadAvailableLanguages() -> [String] {
    guard let url = Bundle.main.url(forResource: "languages", withExtension: "txt"),
      let raw = try? String(contentsOf: url, encoding: .utf8)
    else {
      return []
    }
    return
      raw
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  // Map display name to best-guess code
  func code(for displayName: String) -> String {
    // Attempt using Locale to infer code from English names
    let preferred = Locale(identifier: "en")
    for code in Locale.availableIdentifiers.compactMap({
      Locale(identifier: $0).language.languageCode?.identifier
    }) {
      if let name = preferred.localizedString(forLanguageCode: code),
        name.caseInsensitiveCompare(displayName) == .orderedSame
      {
        return LanguageService.normalize(code: code)
      }
    }
    // Handle special known names
    let manual: [String: String] = [
      "Chinese (Mandarin)": "zh",
      "Slovene (Slovenian)": "sl",
    ]
    if let c = manual[displayName] { return c }
    // Default to English
    return "en"
  }

  static func normalize(code: String) -> String {
    // Only keep language part (e.g., "en-US" -> "en")
    return code.lowercased().split(separator: "-").first.map(String.init) ?? code.lowercased()
  }

  // Short label for Trend: must be 4 letters, language aware
  func shortTrendLabel() -> String {
    // Provide 4-character abbreviations per language for UI consistency.
    // Use local-script where clear; otherwise use a Latin abbreviation.
    let map: [String: String] = [
      "ar": "ترند",
      "be": "Трэн",
      "bg": "Трен",
      "bn": "ট্রেন",
      "cs": "Tren",
      "da": "Tren",
      "de": "Tren",
      "el": "Τάση",
      "en": "Trnd",
      "es": "Tend",
      "et": "Tren",
      "fi": "Tren",
      "fr": "Tend",
      "ga": "Treo",
      "hi": "ट्रेंड",
      "hr": "Tren",
      "hu": "Tren",
      "it": "Tend",
      "ja": "トレ",
      "ko": "트렌",
      "lt": "Tend",
      "lv": "Tend",
      "mt": "Tend",
      "nl": "Tren",
      "pl": "Tren",
      "pt": "Tend",
      "ro": "Tend",
      "sk": "Tren",
      "sl": "Tren",
      "sv": "Tren",
      "th": "เทรน",
      "tr": "Eğil",
      "uk": "Трен",
      "ur": "رجح",
      "vi": "Xuhu",
      "zh": "趋势",
    ]
    return map[currentCode] ?? "TRND"
  }

  func flagEmoji(forLanguageCode code: String) -> String {
    let lang = LanguageService.normalize(code: code)
    let representativeCountry: [String: String] = [
      "en": "US", "es": "ES", "fr": "FR", "de": "DE", "it": "IT", "pt": "PT",
      "ru": "RU", "uk": "UA", "zh": "CN", "ja": "JP", "ar": "SA", "hi": "IN",
      "bn": "BD", "nl": "NL", "sv": "SE", "fi": "FI", "da": "DK", "no": "NO",
      "tr": "TR", "el": "GR", "pl": "PL", "cs": "CZ", "sk": "SK", "sl": "SI",
      "hr": "HR", "hu": "HU", "lv": "LV", "lt": "LT", "et": "EE", "ro": "RO",
      "bg": "BG", "ga": "IE", "mt": "MT", "th": "TH", "ur": "PK", "vi": "VN",
      "be": "BY", "ko": "KR",
    ]
    let country = representativeCountry[lang] ?? "UN"
    return flagEmoji(forRegionCode: country)
  }

  private func flagEmoji(forRegionCode regionCode: String) -> String {
    guard regionCode.count == 2 else { return "🌐" }
    let base: UInt32 = 127_397
    var scalars = String.UnicodeScalarView()
    for v in regionCode.uppercased().unicodeScalars {
      guard let scalar = UnicodeScalar(base + v.value) else { return "🌐" }
      scalars.append(scalar)
    }
    return String(scalars)
  }
}

extension Notification.Name {
  static let appLanguageChanged = Notification.Name("appLanguageChanged")
}
