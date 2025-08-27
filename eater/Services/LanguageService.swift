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
        } else if let deviceCode = Locale.preferredLanguages.first.flatMap({ Locale(identifier: $0).language.languageCode?.identifier }) {
            let normalized = LanguageService.normalize(code: deviceCode)
            print("[LanguageService] init: using device preferred code=\(deviceCode) normalized=\(normalized)")
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
                let codes = urls
                    .filter { $0.pathExtension.lowercased() == "json" }
                    .map { $0.deletingPathExtension().lastPathComponent.lowercased() }
                    .map { LanguageService.normalize(code: $0) }
                let unique = Array(Set(codes)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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

    func setLanguage(code: String, displayName: String? = nil, syncWithBackend: Bool = true, completion: ((Bool) -> Void)? = nil) {
        let normalized = LanguageService.normalize(code: code)
        print("[LanguageService] setLanguage requested code=\(code) normalized=\(normalized) syncWithBackend=\(syncWithBackend)")
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.currentCode = normalized
            // Always use native name unless explicitly provided
            self.currentDisplayName = displayName ?? self.nativeName(for: normalized)
            self.defaults.set(normalized, forKey: self.languageKey)
            self.defaults.set(self.currentDisplayName, forKey: self.displayNameKey)
            self.defaults.synchronize()
            print("[LanguageService] setLanguage updated state code=\(self.currentCode) displayName=\(self.currentDisplayName)")
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
              let raw = try? String(contentsOf: url) else {
            return []
        }
        return raw
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // Map display name to best-guess code
    func code(for displayName: String) -> String {
        // Attempt using Locale to infer code from English names
        let preferred = Locale(identifier: "en")
        for code in Locale.availableIdentifiers.compactMap({ Locale(identifier: $0).language.languageCode?.identifier }) {
            if let name = preferred.localizedString(forLanguageCode: code), name.caseInsensitiveCompare(displayName) == .orderedSame {
                return LanguageService.normalize(code: code)
            }
        }
        // Handle special known names
        let manual: [String: String] = [
            "Chinese (Mandarin)": "zh",
            "Slovene (Slovenian)": "sl"
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
            "ar": "ترند",   // widely used borrowed form
            "be": "ТРЭН",
            "bg": "ТРЕН",
            "bn": "TRND",
            "cs": "TREN",
            "da": "TREN",
            "de": "TREN",
            "el": "ΤΑΣΗ",
            "en": "TRND",
            "es": "TEND",
            "et": "TREN",
            "fi": "TREN",
            "fr": "TEND",
            "ga": "TREN",
            "hi": "TRND",
            "hr": "TREN",
            "hu": "TREN",
            "it": "TEND",
            "ja": "トレンド",
            "ko": "TREN",
            "lt": "TEND",
            "lv": "TEND",
            "mt": "TREN",
            "nl": "TREN",
            "pl": "TREN",
            "pt": "TEND",
            "ro": "TEND",
            "sk": "TREN",
            "sl": "TREN",
            "sv": "TREN",
            "th": "TREN",
            "tr": "EĞİL",
            "uk": "ТРЕН",
            "ur": "TRND",
            "vi": "XUHU",
            "zh": "TREN"
        ]
        return map[currentCode] ?? "TRND"
    }

    // 3-letter macro abbreviations by language (now driven by localization with fallback)
    private func enforce3(_ s: String, fallback: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count == 3 { return t }
        if t.count > 3 { return String(t.prefix(3)) }
        return fallback
    }

    func shortProteinLabel() -> String {
        let localized = loc("macro.pro", "PRO")
        if localized != "PRO" { return enforce3(localized, fallback: "PRO") }
        let map: [String: String] = [
            "ar": "برو","be": "БЯЛ","bg": "БЕЛ","cs": "BIL","da": "PRO","de": "EIW","el": "ΠΡΩ","en": "PRO","es": "PRO","et": "PRO","fi": "PRO","fr": "PRO","ga": "PRO","hr": "PRO","hu": "FEH","it": "PRO","ja": "PRO","ko": "PRO","lt": "BAL","lv": "OLB","mt": "PRO","nl": "EIW","pl": "BIA","pt": "PRO","ro": "PRO","sk": "BIE","sl": "BEL","sv": "PRO","th": "PRO","tr": "PRO","uk": "БІЛ","ur": "PRO","vi": "PRO","zh": "PRO"
        ]
        return (map[currentCode] ?? "PRO")
    }

    func shortFatLabel() -> String {
        let localized = loc("macro.fat", "FAT")
        if localized != "FAT" { return enforce3(localized, fallback: "FAT") }
        let map: [String: String] = [
            "ar": "دهو","be": "ТЛУ","bg": "МАЗ","cs": "TUK","da": "FED","de": "FET","el": "ΛΙΠ","en": "FAT","es": "GRA","et": "RAS","fi": "RAS","fr": "LIP","ga": "SAI","hr": "MAS","hu": "ZSI","it": "GRS","ja": "FAT","ko": "FAT","lt": "RIE","lv": "TAU","mt": "XAĦ","nl": "VET","pl": "TŁU","pt": "GRA","ro": "GRA","sk": "TUK","sl": "MAŠ","sv": "FET","th": "FAT","tr": "YAĞ","uk": "ЖИР","ur": "FAT","vi": "BÉO","zh": "FAT"
        ]
        return (map[currentCode] ?? "FAT")
    }

    func shortCarbLabel() -> String {
        let localized = loc("macro.car", "CAR")
        if localized != "CAR" { return enforce3(localized, fallback: "CAR") }
        let map: [String: String] = [
            "ar": "كرب","be": "ВУГ","bg": "ВЪГ","cs": "SAC","da": "KUL","de": "KOH","el": "ΥΔΑ","en": "CAR","es": "CAR","et": "SÜS","fi": "HII","fr": "GLU","ga": "CAR","hr": "UGL","hu": "SZÉ","it": "CAR","ja": "CAR","ko": "CAR","lt": "ANG","lv": "OGL","mt": "KAR","nl": "KOO","pl": "WEG","pt": "CAR","ro": "CAR","sk": "SAC","sl": "OGL","sv": "KOL","th": "CAR","tr": "KAR","uk": "ВУГ","ur": "CAR","vi": "CAR","zh": "CAR"
        ]
        return (map[currentCode] ?? "CAR")
    }

    func shortSugarLabel() -> String {
        let localized = loc("macro.sug", "SUG")
        if localized != "SUG" { return enforce3(localized, fallback: "SUG") }
        let map: [String: String] = [
            "ar": "سكر","be": "ЦУК","bg": "ЗАХ","cs": "CUK","da": "SUK","de": "ZUC","el": "ΣΑΚ","en": "SUG","es": "AZU","et": "SUH","fi": "SOK","fr": "SUC","ga": "SIÚ","hr": "ŠEĆ","hu": "CUK","it": "ZUC","ja": "SUG","ko": "SUG","lt": "CUK","lv": "CUK","mt": "ZOK","nl": "SUI","pl": "CUK","pt": "AÇU","ro": "ZAH","sk": "CUK","sl": "SLA","sv": "SOC","th": "SUG","tr": "ŞEK","uk": "ЦУК","ur": "SUG","vi": "SUG","zh": "SUG"
        ]
        return (map[currentCode] ?? "SUG")
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
            "be": "BY"
        ]
        let country = representativeCountry[lang] ?? "UN"
        return flagEmoji(forRegionCode: country)
    }

    private func flagEmoji(forRegionCode regionCode: String) -> String {
        guard regionCode.count == 2 else { return "🌐" }
        let base: UInt32 = 127397
        var scalars = String.UnicodeScalarView()
        for v in regionCode.uppercased().unicodeScalars {
            guard let scalar = UnicodeScalar(base + v.value) else { return "🌐" }
            scalars.append(scalar)
        }
        return String(scalars)
    }
}


