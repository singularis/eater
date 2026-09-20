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
      let code = LanguageService.normalize(code: stored)
      let native = LanguageService.nativeNameStatic(for: code)
      currentCode = code
      currentDisplayName = native
      defaults.set(native, forKey: displayNameKey)
      defaults.synchronize()
    } else if let preferred = Locale.preferredLanguages.first {
      let normalized = LanguageService.normalize(code: preferred)
      currentCode = normalized
      currentDisplayName = LanguageService.nativeNameStatic(for: normalized)
      defaults.set(normalized, forKey: languageKey)
      defaults.set(currentDisplayName, forKey: displayNameKey)
      defaults.synchronize()
    } else {
      currentCode = "en"
      currentDisplayName = LanguageService.nativeNameStatic(for: "en")
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
    LanguageService.nativeNameStatic(for: code)
  }

  // Static variant safe for use during initialization
  static func nativeNameStatic(for code: String) -> String {
    let norm = LanguageService.normalize(code: code)
    if let name = displayNames[norm] {
      return name
    }
    let lang = LanguageService.baseLanguageCode(of: norm)
    if let name = Locale(identifier: norm).localizedString(forLanguageCode: lang) {
      return name.capitalized
    }
    if let name = Locale.current.localizedString(forLanguageCode: lang) {
      return name.capitalized
    }
    return norm.uppercased()
  }

  func setLanguage(
    code: String, displayName: String? = nil, syncWithBackend: Bool = true,
    completion: ((Bool) -> Void)? = nil
  ) {
    let normalized = LanguageService.normalize(code: code)
    DispatchQueue.main.async {
      self.objectWillChange.send()
      self.currentCode = normalized
      // Always use native name unless explicitly provided
      self.currentDisplayName = displayName ?? self.nativeName(for: normalized)
      self.defaults.set(normalized, forKey: self.languageKey)
      self.defaults.set(self.currentDisplayName, forKey: self.displayNameKey)
      self.defaults.synchronize()
      // Notify observers (e.g., notification scheduling) that language changed
      NotificationCenter.default.post(name: .appLanguageChanged, object: nil)
    }

    guard syncWithBackend, let email = UserDefaults.standard.string(forKey: "user_email") else {
      completion?(true)
      return
    }
    GRPCService().setLanguage(
      userEmail: email, languageCode: LanguageService.baseLanguageCode(of: normalized)
    ) { success in
      if !success {
        // Fallback to English
        DispatchQueue.main.async {
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
      "English (US)": "en-US",
      "English (UK)": "en",
    ]
    if let c = manual[displayName] { return c }
    // Default to English
    return "en"
  }

  private static let displayNames: [String: String] = [
    "en": "English (UK)",
    "en-US": "English (US)",
  ]

  /// Regional packs that have their own `Localization/*.json` file.
  private static let regionalVariants: Set<String> = ["en-us"]

  static func baseLanguageCode(of code: String) -> String {
    code.lowercased().replacingOccurrences(of: "_", with: "-")
      .split(separator: "-").first.map(String.init) ?? code.lowercased()
  }

  static func normalize(code: String) -> String {
    let raw = code.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "_", with: "-")
      .lowercased()
    let parts = raw.split(separator: "-").map(String.init)
    guard let lang = parts.first, !lang.isEmpty else { return raw }
    if parts.count >= 2 {
      let region = parts[1]
      if regionalVariants.contains("\(lang)-\(region)") {
        return "\(lang)-\(region.uppercased())"
      }
    }
    return lang
  }

  // Short label for Recommendation/Advice
  func shortRecommendationLabel() -> String {
    let map: [String: String] = [
      "ar": "نصيحة",    // naseeha (advice)
      "be": "Пара",
      "bg": "Съвет",
      "bn": "পরামর্শ",   // paramarsha (advice)
      "cs": "Rada",     // rada (advice)
      "da": "Råd",      // råd (advice)
      "de": "Rat",      // Rat (advice)
      "el": "Συμβ",     // symvouli (advice) - short for συμβουλή
      "en": "Advice",   // advice
      "es": "Cons",     // consejo (advice)
      "et": "Nõu",      // nõu (advice)
      "fi": "Neuvo",    // neuvo (advice)
      "fr": "Avis",     // avis (advice)
      "ga": "Comh",     // comhairle (advice)
      "hi": "सलाह",     // salah (advice)
      "hr": "Savj",     // savjet (advice)
      "hu": "Tanács",   // tanács (advice)
      "it": "Cons",     // consiglio (advice)
      "ja": "助言",      // jogen (advice)
      "ko": "조언",      // jo-eon (advice)
      "lt": "Patar",    // patarimas (advice)
      "lv": "Padom",    // padoms (advice)
      "mt": "Parir",    // parir (advice)
      "nl": "Advies",   // advies (advice)
      "pl": "Rada",     // rada (advice)
      "pt": "Cons",     // conselho (advice)
      "ro": "Sfat",     // sfat (advice)
      "sk": "Rada",     // rada (advice)
      "sl": "Nasvet",   // nasvet (advice)
      "sv": "Råd",      // råd (advice)
      "th": "แนะนำ",     // khamnaenam (advice)
      "tr": "Tavsiye",  // tavsiye (advice)
      "uk": "Порада",
      "ur": "مشورہ",    // mashwara (advice)
      "vi": "L.khuyên", // lời khuyên (advice)
      "zh": "建议",      // jiànyi (advice)
    ]
    return map[currentCode] ?? map[LanguageService.baseLanguageCode(of: currentCode)] ?? "Advice"
  }

  func flagEmoji(forLanguageCode code: String) -> String {
    let norm = LanguageService.normalize(code: code)
    let regionalCountry: [String: String] = [
      "en-US": "US",
    ]
    if let country = regionalCountry[norm] {
      return flagEmoji(forRegionCode: country)
    }
    let lang = LanguageService.baseLanguageCode(of: norm)
    let representativeCountry: [String: String] = [
      "en": "GB", "es": "ES", "fr": "FR", "de": "DE", "it": "IT", "pt": "PT",
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
