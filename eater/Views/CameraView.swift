import AVFoundation
import SwiftUI
import PhotosUI

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
  var photoType: String
  var targetDate: Date?

  init(photoType: String, targetDate: Date? = nil) {
    self.photoType = photoType
    self.targetDate = targetDate
  }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    picker.mediaTypes = ["public.image"]
    picker.allowsEditing = false
    picker.modalPresentationStyle = .fullScreen
    return picker
  }

  func updateUIViewController(_: UIImagePickerController, context: Context) {
    context.coordinator.parent = self
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator(self)
  }

  class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var parent: CameraView
    var temporaryTimestamp: Int64?
    var uploadTap = Date()

    init(_ parent: CameraView) {
      self.parent = parent
      super.init()
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      guard let image = info[.originalImage] as? UIImage else {
        HapticsService.shared.error()
        DispatchQueue.main.async { CameraCallbackManager.shared.callPhotoFailure() }
        picker.dismiss(animated: true)
        return
      }

      // Save to Photo Library (Memories) if enabled in settings
      if AppSettingsService.shared.savePhotosToLibrary {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
      }

      DispatchQueue.main.async {
        HapticsService.shared.mediumImpact()
        CameraCallbackManager.shared.callPhotoStarted(image: image)
      }

      // Show loading overlay on top of picker instead of dismissing
      showLoadingOverlay(on: picker)

      // Calculate timestamp. If targetDate is set (backdating), force it to Noon UTC to avoid timezone issues on backend.
      let dateToUse: Date
      if let targetTitle = parent.targetDate {
          let components = Calendar.current.dateComponents([.year, .month, .day], from: targetTitle)
          var utcComponents = DateComponents()
          utcComponents.year = components.year
          utcComponents.month = components.month
          utcComponents.day = components.day
          utcComponents.hour = 12
          utcComponents.minute = 0
          utcComponents.second = 0
          utcComponents.timeZone = TimeZone(abbreviation: "UTC")
          dateToUse = Calendar(identifier: .gregorian).date(from: utcComponents) ?? targetTitle
      } else {
          dateToUse = Date()
      }
      
      let currentTimeMillis = Int64(dateToUse.timeIntervalSince1970 * 1000)
      temporaryTimestamp = currentTimeMillis

      let imageSaved = ImageStorageService.shared.saveTemporaryImage(
        image, forTime: currentTimeMillis)
      if !imageSaved {
        // Failed to save temporary image locally
      }

      GRPCService().sendPhoto(
        image: image, photoType: parent.photoType, timestampMillis: currentTimeMillis
      ) { [weak self] success in
        DispatchQueue.main.async {
          // Dismiss picker now that processing is complete
          picker.dismiss(animated: true)

          if success {
            HapticsService.shared.success()
            self?.uploadTap = Date()
            self?.handlePhotoSuccess()
          } else {
            HapticsService.shared.error()
            self?.handlePhotoFailure()
          }
        }
      }
    }

    private func showLoadingOverlay(on picker: UIImagePickerController) {
      let overlay = UIView(frame: picker.view.bounds)
      overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
      overlay.tag = 999  // For easy removal later

      let activityIndicator = UIActivityIndicatorView(style: .large)
      activityIndicator.color = .white
      activityIndicator.center = overlay.center
      activityIndicator.startAnimating()

      let label = UILabel()
      label.text = loc("loading.photo", "Analyzing food photo...")
      label.textColor = .white
      label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
      label.textAlignment = .center
      label.frame = CGRect(
        x: 0, y: activityIndicator.center.y + 40, width: overlay.bounds.width, height: 30)

      overlay.addSubview(activityIndicator)
      overlay.addSubview(label)
      picker.view.addSubview(overlay)
    }

    private func handlePhotoSuccess() {
      guard let tempTimestamp = temporaryTimestamp else {
        CameraCallbackManager.shared.callPhotoFailure()
        return
      }

      // Clear today's statistics cache since new food was added
      let dateString = parent.targetDate.map { StatisticsService.dateString(for: $0) }
      StatisticsService.shared.invalidateDay(dateString)

      // Use the new unified approach: fetch + map + store + callback
      ProductStorageService.shared.fetchAndProcessProducts(tempImageTime: tempTimestamp) {
        [weak self] products, calories, weight, _ in
        DispatchQueue.main.async {
            NotificationService.shared.recordFoodSnap()
            let limit = CalorieLimitsStorageService.shared.load()?.softLimit ?? UserDefaults.standard.integer(forKey: "softLimit")
            let overLimit = limit > 0 && calories > limit
            let rating: Int
            if overLimit {
              rating = 0
            } else if let added = products.first(where: { $0.time == tempTimestamp })
              ?? products.max(by: { $0.time < $1.time }) {
              rating = added.healthRating >= 0 ? added.effectiveHealthRating : 70
            } else {
              rating = 100
            }
            ThemeService.shared.playSoundForFood(
              healthRating: rating, uploadTap: self?.uploadTap ?? Date())
            CameraCallbackManager.shared.callPhotoSuccess()

            self?.temporaryTimestamp = nil
        }
      }
    }

    private func handlePhotoFailure() {
      if let tempTimestamp = temporaryTimestamp {
        _ = ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
        temporaryTimestamp = nil
      }
      CameraCallbackManager.shared.callPhotoFailure()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      picker.dismiss(animated: true)
    }
  }
}

// MARK: - Photo Library View

struct PhotoLibraryView: UIViewControllerRepresentable {
  var photoType: String
  var targetDate: Date?

  init(photoType: String, targetDate: Date? = nil) {
    self.photoType = photoType
    self.targetDate = targetDate
  }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .photoLibrary
    picker.delegate = context.coordinator
    picker.mediaTypes = ["public.image"]
    picker.allowsEditing = false
    picker.modalPresentationStyle = .fullScreen
    return picker
  }

  func updateUIViewController(_: UIImagePickerController, context: Context) {
    context.coordinator.parent = self
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator(self)
  }

  class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var parent: PhotoLibraryView
    var temporaryTimestamp: Int64?
    var uploadTap = Date()

    init(_ parent: PhotoLibraryView) {
      self.parent = parent
      super.init()
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      guard let image = info[.originalImage] as? UIImage else {
        HapticsService.shared.error()
        DispatchQueue.main.async { CameraCallbackManager.shared.callPhotoFailure() }
        picker.dismiss(animated: true)
        return
      }

      DispatchQueue.main.async {
        HapticsService.shared.mediumImpact()
        CameraCallbackManager.shared.callPhotoStarted(image: image)
      }

      // Show loading overlay on top of picker instead of dismissing
      showLoadingOverlay(on: picker)

      // Calculate timestamp. If targetDate is set (backdating), force it to Noon UTC to avoid timezone issues on backend.
      let dateToUse: Date
      if let targetTitle = parent.targetDate {
          let components = Calendar.current.dateComponents([.year, .month, .day], from: targetTitle)
          var utcComponents = DateComponents()
          utcComponents.year = components.year
          utcComponents.month = components.month
          utcComponents.day = components.day
          utcComponents.hour = 12
          utcComponents.minute = 0
          utcComponents.second = 0
          utcComponents.timeZone = TimeZone(abbreviation: "UTC")
          dateToUse = Calendar(identifier: .gregorian).date(from: utcComponents) ?? targetTitle
      } else {
          dateToUse = Date()
      }

      let currentTimeMillis = Int64(dateToUse.timeIntervalSince1970 * 1000)
      temporaryTimestamp = currentTimeMillis

      let imageSaved = ImageStorageService.shared.saveTemporaryImage(
        image, forTime: currentTimeMillis)
      if !imageSaved {
        // Failed to save temporary image locally
      }

      GRPCService().sendPhoto(
        image: image, photoType: parent.photoType, timestampMillis: currentTimeMillis
      ) { [weak self] success in
        DispatchQueue.main.async {
          // Dismiss picker now that processing is complete
          picker.dismiss(animated: true)

          if success {
            HapticsService.shared.success()
            self?.uploadTap = Date()
            self?.handlePhotoSuccess()
          } else {
            HapticsService.shared.error()
            self?.handlePhotoFailure()
          }
        }
      }
    }

    private func showLoadingOverlay(on picker: UIImagePickerController) {
      let overlay = UIView(frame: picker.view.bounds)
      overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
      overlay.tag = 999  // For easy removal later

      let activityIndicator = UIActivityIndicatorView(style: .large)
      activityIndicator.color = .white
      activityIndicator.center = overlay.center
      activityIndicator.startAnimating()

      let label = UILabel()
      label.text = loc("loading.photo", "Analyzing food photo...")
      label.textColor = .white
      label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
      label.textAlignment = .center
      label.frame = CGRect(
        x: 0, y: activityIndicator.center.y + 40, width: overlay.bounds.width, height: 30)

      overlay.addSubview(activityIndicator)
      overlay.addSubview(label)
      picker.view.addSubview(overlay)
    }

    private func handlePhotoSuccess() {
      guard let tempTimestamp = temporaryTimestamp else {
        CameraCallbackManager.shared.callPhotoFailure()
        return
      }

      // Clear today's statistics cache since new food was added
      let dateString = parent.targetDate.map { StatisticsService.dateString(for: $0) }
      StatisticsService.shared.invalidateDay(dateString)

      // Use the new unified approach: fetch + map + store + callback
      ProductStorageService.shared.fetchAndProcessProducts(tempImageTime: tempTimestamp) {
        [weak self] products, calories, weight, _ in
        DispatchQueue.main.async {
            NotificationService.shared.recordFoodSnap()
            let limit = CalorieLimitsStorageService.shared.load()?.softLimit ?? UserDefaults.standard.integer(forKey: "softLimit")
            let overLimit = limit > 0 && calories > limit
            let rating: Int
            if overLimit {
              rating = 0
            } else if let added = products.first(where: { $0.time == tempTimestamp })
              ?? products.max(by: { $0.time < $1.time }) {
              rating = added.healthRating >= 0 ? added.effectiveHealthRating : 70
            } else {
              rating = 100
            }
            ThemeService.shared.playSoundForFood(
              healthRating: rating, uploadTap: self?.uploadTap ?? Date())
            CameraCallbackManager.shared.callPhotoSuccess()

            self?.temporaryTimestamp = nil
        }
      }
    }

    private func handlePhotoFailure() {
      if let tempTimestamp = temporaryTimestamp {
        _ = ImageStorageService.shared.deleteTemporaryImage(forTime: tempTimestamp)
        temporaryTimestamp = nil
      }
      CameraCallbackManager.shared.callPhotoFailure()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      picker.dismiss(animated: true)
    }
  }
}
