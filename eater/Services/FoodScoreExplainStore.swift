import Foundation

/// Saved explain text, reused only while the dish time it was based on still matches.
final class FoodScoreExplainStore {
  static let shared = FoodScoreExplainStore()
  private init() {}

  struct Entry: Codable {
    let text: String
    let basisDishTime: Int64
  }

  private let defaults = UserDefaults.standard
  private let storageKey = "food_score_explain_cache_v1"

  func dayEntry(email: String, day: String) -> Entry? {
    load()[dayKey(email: email, day: day)]
  }

  func saveDay(email: String, day: String, text: String, basisDishTime: Int64) {
    var all = load()
    all[dayKey(email: email, day: day)] = Entry(text: text, basisDishTime: basisDishTime)
    save(all)
  }

  func dishEntry(email: String, dishTime: Int64) -> Entry? {
    load()[dishKey(email: email, dishTime: dishTime)]
  }

  func saveDish(email: String, dishTime: Int64, text: String, basisDishTime: Int64) {
    var all = load()
    all[dishKey(email: email, dishTime: dishTime)] = Entry(text: text, basisDishTime: basisDishTime)
    save(all)
  }

  private func dayKey(email: String, day: String) -> String {
    "day|\(email)|\(day)"
  }

  private func dishKey(email: String, dishTime: Int64) -> String {
    "dish|\(email)|\(dishTime)"
  }

  private func load() -> [String: Entry] {
    guard let data = defaults.data(forKey: storageKey),
      let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
    else {
      return [:]
    }
    return decoded
  }

  private func save(_ entries: [String: Entry]) {
    guard let data = try? JSONEncoder().encode(entries) else { return }
    defaults.set(data, forKey: storageKey)
  }
}
