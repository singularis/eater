import Foundation
import UIKit

struct Product: Identifiable, Codable, Equatable {
  let id = UUID()
  let time: Int64
  let name: String
  let calories: Int
  let weight: Int
  let ingredients: [String]
  let healthRating: Int
  let imageId: String  // Backend MinIO object path for the food photo
  let addedSugarTsp: Float  // Tracking added sugar in teaspoons
  let extras: [String: Int]  // Local-only extras (lemon/wasabi/etc) per dish

  // Custom initializer for creating products
  init(
    time: Int64,
    name: String,
    calories: Int,
    weight: Int,
    ingredients: [String],
    healthRating: Int = -1,
    imageId: String = "",
    addedSugarTsp: Float = 0,
    extras: [String: Int] = [:]
  ) {
    self.time = time
    self.name = name
    self.calories = calories
    self.weight = weight
    self.ingredients = ingredients
    self.healthRating = healthRating
    self.imageId = imageId
    self.addedSugarTsp = addedSugarTsp
    self.extras = extras
  }

  var image: UIImage? {
    // First try to load by timestamp (local storage - from camera capture)
    if let image = ImageStorageService.shared.loadImage(forTime: time) {
      return image
    }

    // Second: try to load cached image fetched from backend
    if let image = ImageStorageService.shared.loadCachedImage(forImageId: imageId) {
      return image
    }

    // Fallback: try to load by name
    return ImageStorageService.shared.loadImageByName(name)
  }

  var hasImage: Bool {
    return ImageStorageService.shared.imageExists(forTime: time) 
      || (!imageId.isEmpty && ImageStorageService.shared.cachedImageExists(forImageId: imageId))
  }

  var needsRemoteFetch: Bool {
    // Needs remote fetch if we have an imageId but no local image
    return !imageId.isEmpty 
      && !ImageStorageService.shared.imageExists(forTime: time)
      && !ImageStorageService.shared.cachedImageExists(forImageId: imageId)
  }

  private static let extraDefinitions = FoodExtrasStore.definitions

  var sugarCalories: Int {
    Int(addedSugarTsp * 20)  // 1 tsp sugar (5g) ≈ 20 calories
  }

  var sugarGrams: Int {
    Int(addedSugarTsp * 5)  // 1 tsp sugar ≈ 5g
  }

  var extrasCalories: Int {
    extras.reduce(0) { acc, entry in
      let (key, count) = entry
      let cal = Product.extraDefinitions[key]?.calories ?? 0
      return acc + cal * count
    }
  }

  var extrasGrams: Int {
    extras.reduce(0) { acc, entry in
      let (key, count) = entry
      let grams = Product.extraDefinitions[key]?.grams ?? 0
      return acc + grams * count
    }
  }

  var effectiveHealthRating: Int {
    // Local adjustment so UI updates immediately when extras are added.
    // Base rating comes from backend; we apply small penalties/bonuses for extras.
    var delta = 0

    // Added sugar: strong penalty
    delta -= Int(15 * addedSugarTsp)

    // Honey: mild penalty (still sugar, but "healthier" than white sugar)
    delta -= (extras["honey_10g"] ?? 0) * 5

    // Soy sauce: mild penalty (sodium)
    delta -= (extras["soy_sauce_15g"] ?? 0) * 6

    // Lemon: small positive bump
    delta += (extras["lemon_5g"] ?? 0) * 1

    // Wasabi / spicy pepper: tiny positive bump (negligible, but user expects change)
    delta -= (extras["wasabi_3g"] ?? 0) * 1
    delta += (extras["spicy_pepper_5g"] ?? 0) * 0

    return max(0, min(100, healthRating + delta))
  }

  // Computed property for total calories including added sugar + extras
  var totalCalories: Int {
    calories + sugarCalories + extrasCalories
  }

  var totalWeight: Int {
    weight + sugarGrams + extrasGrams
  }

  /// Heuristic classification: treat certain items as drinks (for extras like sugar/lemon).
  var isDrink: Bool {
    let lower = name.lowercased()
    let drinkKeywords = [
      "coffee",
      "tea",
      "latte",
      "cappuccino",
      "espresso",
      "americano",
      "mocha",
      "milk",
      "smoothie",
      "juice",
      "lemonade",
      "soda",
      "cola",
      "water"
    ]
    if drinkKeywords.contains(where: { lower.contains($0) }) {
      return true
    }
    return false
  }

  /// Heuristic: fruit or vegetable — no "Additional" extras (no sugar, no soy/wasabi/pepper).
  var isFruitOrVegetable: Bool {
    let lower = name.lowercased()
    let fruitVegKeywords = [
      "apple", "banana", "orange", "fruit", "salad", "tomato", "carrot", "cucumber",
      "avocado", "grape", "berries", "berry", "peach", "pear", "plum", "mango", "pineapple",
      "watermelon", "melon", "broccoli", "spinach", "lettuce", "onion", "pepper", "bell pepper",
      "strawberry", "blueberry", "raspberry", "blackberry", "cherry", "kiwi", "lemon", "lime",
      "potato", "sweet potato", "corn", "pea", "bean", "cabbage", "celery", "zucchini",
      "eggplant", "beet", "radish", "garlic", "ginger", "pumpkin", "squash", "grapefruit",
      "apricot", "fig", "date", "coconut", "papaya", "dragon fruit", "persimmon", "pomegranate"
    ]
    if fruitVegKeywords.contains(where: { lower.contains($0) }) {
      return true
    }
    return false
  }

  // Codable implementation
  private enum CodingKeys: String, CodingKey {
    case time, name, calories, weight, ingredients, healthRating, imageId, addedSugarTsp, extras
  }
}
