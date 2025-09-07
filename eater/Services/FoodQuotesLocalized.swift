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
    if let url = Bundle.main.url(forResource: code, withExtension: "txt", subdirectory: "quotes"),
      let arr = readQuotes(at: url)
    {
      return arr
    }
    if let url = Bundle.main.url(
      forResource: code, withExtension: "txt", subdirectory: "Localization/quotes"),
      let arr = readQuotes(at: url)
    {
      return arr
    }
    if let url = Bundle.main.url(forResource: code, withExtension: "txt"),
      let arr = readQuotes(at: url)
    {
      return arr
    }
    // Recursively search bundle resources to find nested files (e.g., in folder references)
    if let match = findResourceRecursively(fileName: "\(code.lowercased()).txt") {
      if let arr = readQuotes(at: match) { return arr }
    }
    return nil
  }

  private static func readQuotes(at url: URL) -> [String]? {
    guard var raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    // Remove UTF-8 BOM if present
    if raw.hasPrefix("\u{FEFF}") { raw.removeFirst() }
    return
      raw
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func findResourceRecursively(fileName: String) -> URL? {
    guard let root = Bundle.main.resourceURL else { return nil }
    let fm = FileManager.default
    if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
      for case let fileURL as URL in enumerator {
        if fileURL.lastPathComponent.lowercased() == fileName.lowercased() { return fileURL }
      }
    }
    return nil
  }
}
