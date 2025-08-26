import Foundation

enum FoodQuotesLocalized {
    static func quotes(for languageCode: String) -> [String] {
        let code = LanguageService.normalize(code: languageCode)
        // Try file-based quotes first
        if let fileQuotes = loadQuotesFile(for: code), !fileQuotes.isEmpty {
            return fileQuotes
        }
        // Fallback to English file
        if let enQuotes = loadQuotesFile(for: "en"), !enQuotes.isEmpty {
            return enQuotes
        }
        // Fallback to built-in list
        return FoodQuotes.all
    }

    private static func loadQuotesFile(for code: String) -> [String]? {
        guard let url = Bundle.main.url(forResource: code, withExtension: "txt", subdirectory: "Localization/quotes") else {
            return nil
        }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return raw
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}


