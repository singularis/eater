import Foundation
import UIKit

/// Service for fetching food photos from the backend
class FoodPhotoService {
  static let shared = FoodPhotoService()
  private init() {}


  
  // Track in-flight requests to prevent duplicate fetches
  private var inFlightRequests: Set<String> = []
  private let syncQueue = DispatchQueue(label: "com.eater.FoodPhotoService.sync", qos: .userInitiated)

  /// Fetches a food photo by its image ID from the backend
  /// - Parameters:
  ///   - imageId: The image_id from a Dish/Product object
  ///   - completion: Callback with the UIImage if successful, nil otherwise
  func fetchPhoto(imageId: String, completion: @escaping (UIImage?) -> Void) {
    // Skip if no image ID
    guard !imageId.isEmpty else {
      completion(nil)
      return
    }

    // Check disk cache first
    if let cachedImage = ImageStorageService.shared.loadCachedImage(forImageId: imageId) {
      completion(cachedImage)
      return
    }

    // Check and update in-flight requests synchronously
    var shouldFetch = false
    syncQueue.sync {
      if inFlightRequests.contains(imageId) {
        shouldFetch = false
      } else {
        inFlightRequests.insert(imageId)
        shouldFetch = true
      }
    }

    guard shouldFetch else {
      // Already fetching, wait and try cache again after a delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        if let cachedImage = ImageStorageService.shared.loadCachedImage(forImageId: imageId) {
          completion(cachedImage)
        } else {
          completion(nil)
        }
      }
      return
    }

    // URL encode the image_id
    guard let encodedImageId = imageId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      removeInFlightRequest(imageId)
      completion(nil)
      return
    }

    // Construct URL
    guard let url = URL(string: "\(AppEnvironment.baseURL)/get_photo?image_id=\(encodedImageId)") else {
      removeInFlightRequest(imageId)
      completion(nil)
      return
    }

    // Create request with auth header
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    if let token = UserDefaults.standard.string(forKey: "auth_token") {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    // Fetch data
    let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      defer {
        self?.removeInFlightRequest(imageId)
      }

      if let error = error {
        print("📷 Failed to fetch photo: \(error.localizedDescription)")
        DispatchQueue.main.async {
          completion(nil)
        }
        return
      }

      // Validate response
      guard let httpResponse = response as? HTTPURLResponse else {
        DispatchQueue.main.async {
          completion(nil)
        }
        return
      }

      guard httpResponse.statusCode == 200 else {
        print("📷 Photo fetch failed with status: \(httpResponse.statusCode)")
        DispatchQueue.main.async {
          completion(nil)
        }
        return
      }

      guard let data = data, let image = UIImage(data: data) else {
        print("📷 Failed to create image from data")
        DispatchQueue.main.async {
          completion(nil)
        }
        return
      }

      // Cache the image to disk
      _ = ImageStorageService.shared.saveCachedImage(image, forImageId: imageId)

      DispatchQueue.main.async {
        completion(image)
      }
    }
    task.resume()
  }

  /// Async/await version for SwiftUI
  func fetchPhoto(imageId: String) async -> UIImage? {
    return await withCheckedContinuation { continuation in
      fetchPhoto(imageId: imageId) { image in
        continuation.resume(returning: image)
      }
    }
  }

  private func removeInFlightRequest(_ imageId: String) {
    syncQueue.async { [weak self] in
      self?.inFlightRequests.remove(imageId)
    }
  }

  /// Prefetch photos for a list of products that need remote images
  func prefetchPhotos(for products: [Product]) {
    for product in products where product.needsRemoteFetch {
      fetchPhoto(imageId: product.imageId) { _ in
        // Just prefetching, no callback needed
      }
    }
  }
}

