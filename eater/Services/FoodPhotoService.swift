import Foundation
import UIKit

/// Service for fetching food photos from the backend
class FoodPhotoService {
  static let shared = FoodPhotoService()
  private init() {}


  
  // One in-flight loop per image. Extra callers wait for that loop instead of giving up.
  private var waiters: [String: [(UIImage?) -> Void]] = [:]
  private var retryWanted: Set<String> = []
  private let syncQueue = DispatchQueue(label: "com.eater.FoodPhotoService.sync", qos: .userInitiated)
  private let retryDelays: [TimeInterval] = [1, 2, 4, 8]

  /// Fetches a food photo by its image ID from the backend.
  /// `retry` is for a visible thumb. Prefetch stays a single attempt.
  func fetchPhoto(imageId: String, retry: Bool = false, completion: @escaping (UIImage?) -> Void) {
    guard !imageId.isEmpty else {
      completion(nil)
      return
    }

    if let cachedImage = ImageStorageService.shared.loadCachedImage(forImageId: imageId) {
      completion(cachedImage)
      return
    }

    var shouldFetch = false
    syncQueue.sync {
      if retry {
        retryWanted.insert(imageId)
      }
      if waiters[imageId] != nil {
        waiters[imageId, default: []].append(completion)
      } else {
        waiters[imageId] = [completion]
        shouldFetch = true
      }
    }

    guard shouldFetch else { return }
    loadPhoto(imageId: imageId, attempt: 0)
  }

  private func loadPhoto(imageId: String, attempt: Int) {
    var imageIdAllowed = CharacterSet.urlQueryAllowed
    imageIdAllowed.remove(charactersIn: "/@+&?=#")
    guard let encodedImageId = imageId.addingPercentEncoding(withAllowedCharacters: imageIdAllowed),
      let url = URL(string: "\(AppEnvironment.baseURL)/get_photo?image_id=\(encodedImageId)")
    else {
      finish(imageId: imageId, image: nil)
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    if let token = KeychainHelper.shared.read("auth_token") {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let self else { return }
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      if error == nil, status == 200, let data, let image = UIImage(data: data) {
        _ = ImageStorageService.shared.saveCachedImage(image, forImageId: imageId)
        self.finish(imageId: imageId, image: image)
        return
      }

      let delay = self.retryDelays.indices.contains(attempt) ? self.retryDelays[attempt] : nil
      var shouldRetry = false
      self.syncQueue.sync {
        shouldRetry = delay != nil && self.retryWanted.contains(imageId)
      }
      if shouldRetry, let delay {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
          self.loadPhoto(imageId: imageId, attempt: attempt + 1)
        }
      } else {
        self.finish(imageId: imageId, image: nil)
      }
    }.resume()
  }

  private func finish(imageId: String, image: UIImage?) {
    let callbacks: [(UIImage?) -> Void] = syncQueue.sync {
      retryWanted.remove(imageId)
      return waiters.removeValue(forKey: imageId) ?? []
    }
    DispatchQueue.main.async {
      callbacks.forEach { $0(image) }
    }
  }

  /// Async/await version for SwiftUI
  func fetchPhoto(imageId: String) async -> UIImage? {
    return await withCheckedContinuation { continuation in
      fetchPhoto(imageId: imageId, retry: false) { image in
        continuation.resume(returning: image)
      }
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

