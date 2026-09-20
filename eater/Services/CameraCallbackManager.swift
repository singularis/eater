import Foundation
import UIKit

class CameraCallbackManager {
  static let shared = CameraCallbackManager()
  private init() {}

  private var onPhotoSuccess: (() -> Void)?
  private var onPhotoFailure: (() -> Void)?
  private var onPhotoStarted: ((UIImage?) -> Void)?

  func setCallbacks(
    onPhotoSuccess: (() -> Void)?,
    onPhotoFailure: (() -> Void)?,
    onPhotoStarted: ((UIImage?) -> Void)?
  ) {
    self.onPhotoSuccess = onPhotoSuccess
    self.onPhotoFailure = onPhotoFailure
    self.onPhotoStarted = onPhotoStarted
  }

  func callPhotoSuccess() {
    let callback = onPhotoSuccess
    clearCallbacks()
    callback?()
  }

  func callPhotoFailure() {
    let callback = onPhotoFailure
    clearCallbacks()
    callback?()
  }

  func callPhotoStarted(image: UIImage? = nil) {
    onPhotoStarted?(image)
  }

  func clearCallbacks() {
    onPhotoSuccess = nil
    onPhotoFailure = nil
    onPhotoStarted = nil
  }
}
