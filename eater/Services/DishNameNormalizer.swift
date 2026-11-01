import Foundation

/// Client-side cleanup for dish names the user types. The backend still has the final say.
enum DishNameNormalizer {
  /// Long names break the card and the stock-photo lookup.
  static let maxLength = 48

  /// "  my   pizza and bear.. " -> "My pizza and bear"
  static func dishName(_ raw: String) -> String {
    var name = collapseSpaces(raw)
      .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?-–—_/\\|\"'`").union(.whitespaces))
    if name.count > maxLength {
      let cut = String(name.prefix(maxLength))
      if let lastSpace = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: lastSpace) > maxLength / 2 {
        name = String(cut[..<lastSpace])
      } else {
        name = cut
      }
      name = dropTrailingJoiners(name)
    }
    if name == name.lowercased(), let first = name.first {
      name = first.uppercased() + name.dropFirst()
    }
    return name
  }

  /// Typed meal text keeps its wording; only whitespace is tidied.
  static func mealText(_ raw: String) -> String {
    collapseSpaces(raw)
  }

  /// Suggestions from the server: tidy, drop empties, the current name, and duplicates.
  static func suggestions(_ raw: [String], excluding current: String, limit: Int = 12) -> [String] {
    var seen: Set<String> = [collapseSpaces(current).lowercased()]
    var result: [String] = []
    for item in raw {
      let name = dishName(item)
      let key = name.lowercased()
      guard !name.isEmpty, !seen.contains(key) else { continue }
      seen.insert(key)
      result.append(name)
      if result.count == limit { break }
    }
    return result
  }

  private static let joiners: Set<String> = [
    "and", "with", "or", "of", "in", "on", "the", "a", "&", "+",
    "und", "mit", "et", "avec", "y", "con", "e", "i", "z", "ze", "oraz", "та", "і", "й", "з", "із", "зі", "и", "с", "со",
  ]

  /// A cut name must not end on "and" / "with" / "з".
  private static func dropTrailingJoiners(_ name: String) -> String {
    var words = name.split(separator: " ").map(String.init)
    while words.count > 1, let last = words.last,
      joiners.contains(last.lowercased().trimmingCharacters(in: .punctuationCharacters))
        || last.trimmingCharacters(in: .punctuationCharacters).isEmpty
    {
      words.removeLast()
    }
    return words.joined(separator: " ")
      .trimmingCharacters(in: CharacterSet(charactersIn: ",;:-–—&+").union(.whitespaces))
  }

  private static func collapseSpaces(_ raw: String) -> String {
    raw.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
  }
}
