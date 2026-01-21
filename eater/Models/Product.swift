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

  // Custom initializer for creating products
  init(time: Int64, name: String, calories: Int, weight: Int, ingredients: [String], healthRating: Int = -1, imageId: String = "") {
    self.time = time
    self.name = name
    self.calories = calories
    self.weight = weight
    self.ingredients = ingredients
    self.healthRating = healthRating
    self.imageId = imageId
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

  // Codable implementation
  private enum CodingKeys: String, CodingKey {
    case time, name, calories, weight, ingredients, healthRating, imageId
  }
}
