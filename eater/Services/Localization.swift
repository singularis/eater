import Foundation

final class Localization {
  static let shared = Localization()

  private var cache: [String: [String: String]] = [:]
  private let queue = DispatchQueue(label: "LocalizationQueue")

  /// Maps API food names (often English) to localization keys for display
  private static let foodNameToKey: [String: String] = [
    "Apple": "food.apple",
    "Banana": "food.banana",
    "Orange": "food.orange",
    "Bread": "food.bread",
    "Chicken": "food.chicken",
    "Egg": "food.egg",
    "Eggs": "food.eggs",
    "Milk": "food.milk",
    "Rice": "food.rice",
    "Salad": "food.salad",
    "Tomato": "food.tomato",
    "Cheese": "food.cheese",
    "Fish": "food.fish",
    "Meat": "food.meat",
    "Potato": "food.potato",
    "Potatoes": "food.potatoes",
    "Pasta": "food.pasta",
    "Yogurt": "food.yogurt",
    "Coffee": "food.coffee",
    "Tea": "food.tea",
  ]

  /// Returns localized food name when we have a key, otherwise the original name
  func translateFoodName(_ name: String) -> String {
    let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return name }
    if let key = Self.foodNameToKey[t] {
      return tr(key, default: t)
    }
    return name
  }

  func tr(_ key: String, default defaultValue: String? = nil) -> String {
    let code = LanguageService.shared.currentCode
    let map = translations(for: code)
    if let v = map[key] {
      return v
    }
    // Fallback to English map
    let en = translations(for: "en")
    if let v = en[key] {
      return v
    }
    return defaultValue ?? key
  }

  private func translations(for code: String) -> [String: String] {
    if let m = cache[code] {
      return m
    }
    let dict = loadTranslations(code: code)
    cache[code] = dict
    return dict
  }

  private func loadTranslations(code: String) -> [String: String] {
    // 1) Try within 'Localization' folder reference
    if let url = Bundle.main.url(
      forResource: code, withExtension: "json", subdirectory: "Localization"),
      let data = try? Data(contentsOf: url),
      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    {
      return obj
    }
    // 2) Try at bundle root (resources may be flattened by Xcode)
    if let url = Bundle.main.url(forResource: code, withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    {
      return obj
    }
    // 3) Enumerate any JSON in bundle and match filename
    if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
      if let match = urls.first(where: {
        $0.lastPathComponent.lowercased() == "\(code.lowercased()).json"
      }),
        let data = try? Data(contentsOf: match),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String]
      {
        return obj
      }
    }
    return [:]
  }
}

@inline(__always)
func loc(_ key: String, _ def: String? = nil) -> String {
  Localization.shared.tr(key, default: def)
}
