import Foundation

/// Persists per-dish "extras" added locally (lemon/wasabi/etc).
/// Added sugar is also kept briefly for optimistic UI, then cleared once the
/// backend refresh lands (server already folds sugar into calories/contains).
final class FoodExtrasStore {
  static let shared = FoodExtrasStore()
  private init() {}

  private let userDefaults = UserDefaults.standard
  private let key = "food_extras_by_time"

  // time (as String) -> extraKey -> count
  private typealias Store = [String: [String: Int]]

  /// Extra definitions: grams + calories per 1 tap.
  /// (Values are approximate; tweak anytime.)
  static let definitions: [String: (grams: Int, calories: Int)] = [
    "lemon_5g": (grams: 5, calories: 1),
    "honey_10g": (grams: 10, calories: 30),
    "milk_50g": (grams: 50, calories: 32),
    "soy_sauce_15g": (grams: 15, calories: 10),
    "wasabi_3g": (grams: 3, calories: 8),
    "spicy_pepper_5g": (grams: 5, calories: 2),
  ]

  // Stored under the same dictionary, but applied into Product.addedSugarTsp (not Product.extras)
  static let sugarKey = "added_sugar_tsp"

  func addSugar(time: Int64, tsp: Int = 1) {
    guard tsp > 0 else { return }
    var store = load()
    let t = String(time)
    var extras = store[t] ?? [:]
    extras[FoodExtrasStore.sugarKey] = (extras[FoodExtrasStore.sugarKey] ?? 0) + tsp
    store[t] = extras
    save(store)
  }

  func addExtra(time: Int64, extraKey: String) {
    var store = load()
    let t = String(time)
    var extras = store[t] ?? [:]
    extras[extraKey] = (extras[extraKey] ?? 0) + 1
    store[t] = extras
    save(store)
  }

  func extras(for time: Int64) -> [String: Int] {
    load()[String(time)] ?? [:]
  }

  /// Drop optimistic local sugar once backend dish data is authoritative again.
  func clearSugar(for times: [Int64]) {
    guard !times.isEmpty else { return }
    var store = load()
    var changed = false
    for time in times {
      let t = String(time)
      guard var extras = store[t], extras[FoodExtrasStore.sugarKey] != nil else { continue }
      extras.removeValue(forKey: FoodExtrasStore.sugarKey)
      if extras.isEmpty {
        store.removeValue(forKey: t)
      } else {
        store[t] = extras
      }
      changed = true
    }
    if changed { save(store) }
  }

  /// Scale local sugar with portion % so icons stay consistent until refresh clears it.
  func scaleSugar(time: Int64, percentage: Int) {
    guard percentage > 0, percentage != 100 else { return }
    var store = load()
    let t = String(time)
    guard var extras = store[t], let tsp = extras[FoodExtrasStore.sugarKey], tsp > 0 else { return }
    let scaled = max(0, Int((Double(tsp) * Double(percentage) / 100.0).rounded()))
    if scaled == 0 {
      extras.removeValue(forKey: FoodExtrasStore.sugarKey)
    } else {
      extras[FoodExtrasStore.sugarKey] = scaled
    }
    if extras.isEmpty {
      store.removeValue(forKey: t)
    } else {
      store[t] = extras
    }
    save(store)
  }

  func apply(to products: [Product]) -> [Product] {
    products.map { p in
      var ex = extras(for: p.time)
      if ex.isEmpty { return p }
      let sugarTsp = ex.removeValue(forKey: FoodExtrasStore.sugarKey) ?? 0
      // Optimistic only: bump calories/macros locally until server refresh clears sugarKey.
      return Product(
        time: p.time,
        name: p.name,
        calories: p.calories + Int(sugarTsp) * 20,
        weight: p.weight + Int(sugarTsp) * 5,
        ingredients: p.ingredients,
        healthRating: p.healthRating,
        imageId: p.imageId,
        addedSugarTsp: Float(sugarTsp),
        extras: ex,
        proteins: p.proteins,
        fats: p.fats,
        carbohydrates: p.carbohydrates + Double(sugarTsp) * 5.0,
        sugar: p.sugar + Double(sugarTsp) * 5.0
      )
    }
  }

  /// Sum of calories contributed by extras (not including base dish calories).
  func totalExtrasCalories(for products: [Product]) -> Int {
    products.reduce(0) { $0 + $1.extrasCalories }
  }

  private func load() -> Store {
    guard let data = userDefaults.data(forKey: key) else { return [:] }
    return (try? JSONDecoder().decode(Store.self, from: data)) ?? [:]
  }

  private func save(_ store: Store) {
    guard let data = try? JSONEncoder().encode(store) else { return }
    userDefaults.set(data, forKey: key)
  }
}
