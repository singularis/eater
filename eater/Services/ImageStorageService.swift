import Foundation
import UIKit

class ImageStorageService {
  static let shared = ImageStorageService()
  private init() {}

  private var documentsDirectory: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  }

  private var imagesDirectory: URL {
    let url = documentsDirectory.appendingPathComponent("FoodImages")
    if !FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url
  }

  func saveImage(_ image: UIImage, forTime time: Int64) -> Bool {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
      return false
    }

    let filename = "\(time).jpg"
    let fileURL = imagesDirectory.appendingPathComponent(filename)

    do {
      try imageData.write(to: fileURL)
      return true
    } catch {
      return false
    }
  }

  func saveTemporaryImage(_ image: UIImage, forTime time: Int64) -> Bool {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
      return false
    }

    let filename = "temp_\(time).jpg"
    let fileURL = imagesDirectory.appendingPathComponent(filename)

    do {
      try imageData.write(to: fileURL)
      return true
    } catch {
      return false
    }
  }

  func moveTemporaryImage(fromTime tempTime: Int64, toTime finalTime: Int64) -> Bool {
    let tempFilename = "temp_\(tempTime).jpg"
    let finalFilename = "\(finalTime).jpg"
    let tempURL = imagesDirectory.appendingPathComponent(tempFilename)
    let finalURL = imagesDirectory.appendingPathComponent(finalFilename)

    guard FileManager.default.fileExists(atPath: tempURL.path) else {
      return false
    }

    do {
      try FileManager.default.moveItem(at: tempURL, to: finalURL)
      return true
    } catch {
      return false
    }
  }

  func deleteTemporaryImage(forTime time: Int64) -> Bool {
    let filename = "temp_\(time).jpg"
    let fileURL = imagesDirectory.appendingPathComponent(filename)

    do {
      try FileManager.default.removeItem(at: fileURL)
      return true
    } catch {
      return false
    }
  }

  func loadImage(forTime time: Int64) -> UIImage? {
    let filename = "\(time).jpg"
    let fileURL = imagesDirectory.appendingPathComponent(filename)

    guard FileManager.default.fileExists(atPath: fileURL.path),
      let imageData = try? Data(contentsOf: fileURL),
      let image = UIImage(data: imageData)
    else {
      return nil
    }

    return image
  }

  func deleteImage(forTime time: Int64) -> Bool {
    let filename = "\(time).jpg"
    let fileURL = imagesDirectory.appendingPathComponent(filename)

    do {
      try FileManager.default.removeItem(at: fileURL)
      return true
    } catch {
      return false
    }
  }

  func imageExists(forTime time: Int64) -> Bool {
    let filename = "\(time).jpg"
    let fileURL = imagesDirectory.appendingPathComponent(filename)
    return FileManager.default.fileExists(atPath: fileURL.path)
  }

  // MARK: - Load by Name (Fallback)

  func loadImageByName(_ name: String) -> UIImage? {
    // Clean the name to make it a valid filename
    let cleanName = name.replacingOccurrences(
      of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression
    )
    .replacingOccurrences(of: " ", with: "_")
    .lowercased()

    let filename = "\(cleanName).jpg"
    let fileURL = imagesDirectory.appendingPathComponent(filename)

    guard FileManager.default.fileExists(atPath: fileURL.path),
      let imageData = try? Data(contentsOf: fileURL),
      let image = UIImage(data: imageData)
    else {
      return nil
    }

    return image
  }

  func saveImageByName(_ image: UIImage, name: String) -> Bool {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
      return false
    }

    // Clean the name to make it a valid filename
    let cleanName = name.replacingOccurrences(
      of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression
    )
    .replacingOccurrences(of: " ", with: "_")
    .lowercased()

    let filename = "\(cleanName).jpg"
    let fileURL = imagesDirectory.appendingPathComponent(filename)

    do {
      try imageData.write(to: fileURL)
      return true
    } catch {
      return false
    }
  }

  // MARK: - Cached Remote Images (from backend)

  private var cachedImagesDirectory: URL {
    let url = documentsDirectory.appendingPathComponent("CachedFoodImages")
    if !FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    return url
  }

  /// Convert an imageId to a safe filename
  private func cacheFilename(forImageId imageId: String) -> String {
    // imageId format might be: "user@email.com/20260121_143052.jpg"
    // Convert to safe filename preserving uniqueness
    let safeFilename = imageId
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "@", with: "_at_")
    return safeFilename.hasSuffix(".jpg") ? safeFilename : "\(safeFilename).jpg"
  }

  /// Save an image fetched from backend to cache
  func saveCachedImage(_ image: UIImage, forImageId imageId: String) -> Bool {
    guard !imageId.isEmpty,
          let imageData = image.jpegData(compressionQuality: 0.9) else {
      return false
    }

    let filename = cacheFilename(forImageId: imageId)
    let fileURL = cachedImagesDirectory.appendingPathComponent(filename)

    do {
      try imageData.write(to: fileURL)
      return true
    } catch {
      return false
    }
  }

  /// Load an image from cache by its imageId
  func loadCachedImage(forImageId imageId: String) -> UIImage? {
    guard !imageId.isEmpty else {
      return nil
    }

    let filename = cacheFilename(forImageId: imageId)
    let fileURL = cachedImagesDirectory.appendingPathComponent(filename)

    guard FileManager.default.fileExists(atPath: fileURL.path),
          let imageData = try? Data(contentsOf: fileURL),
          let image = UIImage(data: imageData)
    else {
      return nil
    }

    return image
  }

  /// Check if a cached image exists for the given imageId
  func cachedImageExists(forImageId imageId: String) -> Bool {
    guard !imageId.isEmpty else {
      return false
    }

    let filename = cacheFilename(forImageId: imageId)
    let fileURL = cachedImagesDirectory.appendingPathComponent(filename)
    return FileManager.default.fileExists(atPath: fileURL.path)
  }

  /// Delete a cached image
  func deleteCachedImage(forImageId imageId: String) -> Bool {
    guard !imageId.isEmpty else {
      return false
    }

    let filename = cacheFilename(forImageId: imageId)
    let fileURL = cachedImagesDirectory.appendingPathComponent(filename)

    do {
      try FileManager.default.removeItem(at: fileURL)
      return true
    } catch {
      return false
    }
  }
}
