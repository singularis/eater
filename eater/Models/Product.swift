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

  // Custom initializer for creating products
  init(time: Int64, name: String, calories: Int, weight: Int, ingredients: [String], healthRating: Int = -1) {
    self.time = time
    self.name = name
    self.calories = calories
    self.weight = weight
    self.ingredients = ingredients
    self.healthRating = healthRating
  }

  var image: UIImage? {
    // First try to load by timestamp
    if let image = ImageStorageService.shared.loadImage(forTime: time) {
      return image
    }

    // Fallback: try to load by name
    return ImageStorageService.shared.loadImageByName(name)
  }

  var hasImage: Bool {
    return ImageStorageService.shared.imageExists(forTime: time)
  }

  // Codable implementation
  private enum CodingKeys: String, CodingKey {
    case time, name, calories, weight, ingredients, healthRating
  }
}
