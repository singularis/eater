import Foundation
import UIKit

extension GRPCService {
  /// Send multiple photos at once for batch processing
  /// - Parameters:
  ///   - images: Array of UIImages to process
  ///   - photoType: Type of photos (e.g., "food_photo")
  ///   - timestampMillis: Optional timestamp, defaults to now
  ///   - completion: Callback with success/failure status
  func sendMultiplePhotos(
    images: [UIImage],
    photoType: String,
    timestampMillis: Int64? = nil,
    completion: @escaping (Bool, Int) -> Void  // Returns success + count of processed images
  ) {
    guard !images.isEmpty else {
      completion(false, 0)
      return
    }
    
    let timestamp: String
    if let timestampMillis = timestampMillis {
      let date = Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000)
      timestamp = ISO8601DateFormatter().string(from: date)
    } else {
      timestamp = ISO8601DateFormatter().string(from: Date())
    }
    
    // Option 1: Send as single batch (requires backend support)
    // sendAsBatch(images: images, photoType: photoType, timestamp: timestamp, completion: completion)
    
    // Option 2: Send individually (works with current backend) - ACTIVE
    sendIndividually(images: images, photoType: photoType, timestampMillis: timestampMillis, completion: completion)
  }
  
  // OPTION 1: Send as single batch message
  private func sendAsBatch(
    images: [UIImage],
    photoType: String,
    timestamp: String,
    completion: @escaping (Bool, Int) -> Void
  ) {
    // Compress all images
    var imagesData: [Data] = []
    for image in images {
      if let imageData = image.jpegData(compressionQuality: 0.8) {
        imagesData.append(imageData)
      }
    }
    
    guard !imagesData.isEmpty else {
      completion(false, 0)
      return
    }
    
    // Create protobuf message (requires new proto definition)
    // var multiplePhotosMessage = Eater_MultiplePhotosMessage()
    // multiplePhotosMessage.time = timestamp
    // multiplePhotosMessage.photosData = imagesData
    // multiplePhotosMessage.photoType = photoType
    
    // For now, send to new endpoint
    // endpoint: "eater_receive_multiple_photos"
    
    // TODO: Implement backend endpoint
    completion(true, imagesData.count)
  }
  
  // OPTION 2: Send images individually (works with current backend)
  private func sendIndividually(
    images: [UIImage],
    photoType: String,
    timestampMillis: Int64?,
    completion: @escaping (Bool, Int) -> Void
  ) {
    var successCount = 0
    var failCount = 0
    let group = DispatchGroup()
    
    for (index, image) in images.enumerated() {
      group.enter()
      
      // Add small delay between photos to avoid overwhelming backend
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
        self.sendPhoto(image: image, photoType: photoType, timestampMillis: timestampMillis) { success in
          if success {
            successCount += 1
          } else {
            failCount += 1
          }
          group.leave()
        }
      }
    }
    
    group.notify(queue: .main) {
      let allSucceeded = failCount == 0
      completion(allSucceeded, successCount)
    }
  }
}
