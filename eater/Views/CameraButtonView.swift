import AVFoundation
import SwiftUI
import PhotosUI

struct CameraButtonView: View {
  @State private var showCamera = false
  @State private var showPhotoLibrary = false
  @State private var cameraUnavailableAlert = false
  @State private var photoLibraryUnavailableAlert = false
  
  // Backdating state
  @State private var showBackdatingAlert = false
  @State private var pendingSourceType: UIImagePickerController.SourceType? = nil
  @State private var backdatingMessage: String = ""
  @State private var backdatingStatusEmoji: String = ""

  let isLoadingFoodPhoto: Bool
  let selectedDate: Date
  let isViewingCustomDate: Bool
  var onPhotoSuccess: (() -> Void)?
  var onPhotoFailure: (() -> Void)?
  var onPhotoStarted: (() -> Void)?
  var onReturnToToday: (() -> Void)?

  init(
    isLoadingFoodPhoto: Bool,
    selectedDate: Date = Date(),
    isViewingCustomDate: Bool = false,
    onPhotoSuccess: (() -> Void)?,
    onPhotoFailure: (() -> Void)?,
    onPhotoStarted: (() -> Void)?,
    onReturnToToday: (() -> Void)? = nil
  ) {
    self.isLoadingFoodPhoto = isLoadingFoodPhoto
    self.selectedDate = selectedDate
    self.isViewingCustomDate = isViewingCustomDate
    self.onPhotoSuccess = onPhotoSuccess
    self.onPhotoFailure = onPhotoFailure
    self.onPhotoStarted = onPhotoStarted
    self.onReturnToToday = onReturnToToday
  }

  var body: some View {
    VStack(spacing: 10) {
      // First row: Single upload and Camera
      GeometryReader { geo in
        let totalWidth = geo.size.width
        let uploadWidth = totalWidth * 0.30
        let gapWidth = totalWidth * 0.05
        let takeWidth = totalWidth - uploadWidth - gapWidth

        HStack(spacing: 0) {
          Button(action: {
            HapticsService.shared.select()
            checkBackdating(sourceType: .photoLibrary)
          }) {
            HStack(spacing: 4) {
              Image(systemName: "photo.fill")
                .font(.system(size: 18))
              Text(loc("camera.upload", "Upload"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 24)
            .frame(width: uploadWidth)
            .background(AppTheme.primaryButtonGradient)
            .cornerRadius(AppTheme.cornerRadius)
            .foregroundColor(.white)
            .overlay(
              RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(
                  LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.9), Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ),
                  lineWidth: 2
                )
            )
            .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.4), radius: 6, x: 0, y: 3)
          }
          .buttonStyle(.plain)
          .disabled(isLoadingFoodPhoto)
          .buttonStyle(PressScaleButtonStyle())

          Color.clear
            .frame(width: gapWidth)

          Button(action: {
            HapticsService.shared.select()
            checkBackdating(sourceType: .camera)
          }) {
            HStack(spacing: 6) {
              Image(systemName: "camera.fill")
                .font(.system(size: 20))
              Text(loc("camera.takefood", "Take Food Photo"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 24)
            .frame(width: takeWidth)
            .background(AppTheme.primaryButtonGradient)
            .cornerRadius(AppTheme.cornerRadius)
            .foregroundColor(.white)
            .overlay(
              RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(
                  LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.0, green: 0.8, blue: 0.9).opacity(0.9), Color(red: 0.0, green: 0.8, blue: 0.9).opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ),
                  lineWidth: 2.5
                )
            )
            .shadow(color: Color(red: 0.0, green: 0.8, blue: 0.9).opacity(0.5), radius: 8, x: 0, y: 3)
          }
          .buttonStyle(.plain)
          .disabled(isLoadingFoodPhoto)
          .buttonStyle(PressScaleButtonStyle())
        }
        .frame(height: 100)
      }
      .frame(height: 100)
    }
    .frame(height: 100)
    .sheet(isPresented: $showCamera) {
      CameraView(photoType: "default_prompt", targetDate: isViewingCustomDate ? selectedDate : nil)
        .onAppear {
          CameraCallbackManager.shared.setCallbacks(
            onPhotoSuccess: onPhotoSuccess,
            onPhotoFailure: onPhotoFailure,
            onPhotoStarted: onPhotoStarted
          )
        }
    }
    .sheet(isPresented: $showPhotoLibrary) {
      PhotoLibraryView(photoType: "default_prompt", targetDate: isViewingCustomDate ? selectedDate : nil)
        .onAppear {
          CameraCallbackManager.shared.setCallbacks(
            onPhotoSuccess: onPhotoSuccess,
            onPhotoFailure: onPhotoFailure,
            onPhotoStarted: onPhotoStarted
          )
        }
    }
    .alert(
      loc("camera.unavailable.title", "Camera Unavailable"), isPresented: $cameraUnavailableAlert
    ) {
      Button(loc("common.ok", "OK")) {}
    } message: {
      Text(loc("camera.unavailable.msg", "Your device does not have a camera."))
    }
    .alert(
      loc("library.unavailable.title", "Photo Library Unavailable"),
      isPresented: $photoLibraryUnavailableAlert
    ) {
      Button(loc("common.ok", "OK")) {}
    } message: {
      Text(loc("library.unavailable.msg", "Photo library is not available."))
    }
    .alert(loc("backdating.alert.title", "Confirm Past Date"), isPresented: $showBackdatingAlert) {
      Button(loc("backdating.alert.cancel", "Cancel"), role: .cancel) {
        pendingSourceType = nil
      }
      Button(loc("backdating.alert.confirm", "Confirm")) {
        if let type = pendingSourceType {
          openCamera(sourceType: type)
        }
      }
      Button(loc("backdating.alert.log_today", "Log Today's Food")) {
        pendingSourceType = nil
        onReturnToToday?()
      }
    } message: {
      Text(backdatingStatusEmoji + " " + backdatingMessage + "\n\n" + loc("backdating.alert.tip", "Tip: You can log today's food instead."))
    }
  }

  private func checkBackdating(sourceType: UIImagePickerController.SourceType) {
    if isViewingCustomDate && !Calendar.current.isDateInToday(selectedDate) {
      let diff = Date().timeIntervalSince(selectedDate)
      let days = diff / 86400
      let hours = diff / 3600
      
      let formatter = DateFormatter()
      formatter.dateFormat = "EEEE, d 'of' MMMM"
      let dateString = formatter.string(from: selectedDate)
      
      let timeAgo: String
      if days >= 1 {
        timeAgo = String(format: loc("backdating.time.days_ago", "%d days ago"), Int(days))
      } else {
        timeAgo = String(format: loc("backdating.time.hours_ago", "%d hours ago"), Int(hours))
      }
      
      if days > 30 {
        backdatingStatusEmoji = "🔴" // Red/Danger
      } else if days < 5 {
        backdatingStatusEmoji = "🟢" // Green/Safe
      } else {
        backdatingStatusEmoji = "🟠" // Orange/Warning
      }

      backdatingMessage = String(format: loc("backdating.message.submitting", "Submitting for %@\n(%@)"), dateString, timeAgo)

      
      pendingSourceType = sourceType
      showBackdatingAlert = true
    } else {
      openCamera(sourceType: sourceType)
    }
  }

  private func openCamera(sourceType: UIImagePickerController.SourceType) {
    if sourceType == .camera {
      if UIImagePickerController.isSourceTypeAvailable(.camera) {
        showCamera = true
      } else {
        HapticsService.shared.error()
        cameraUnavailableAlert = true
      }
    } else {
      if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
        showPhotoLibrary = true
      } else {
        HapticsService.shared.error()
        photoLibraryUnavailableAlert = true
      }
    }
  }
  
}

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
        CameraCallbackManager.shared.callPhotoStarted()
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
      StatisticsService.shared.clearExpiredCache()

      // Use the new unified approach: fetch + map + store + callback
      ProductStorageService.shared.fetchAndProcessProducts(tempImageTime: tempTimestamp) {
        [weak self] _, _, _ in
        // Record that user snapped food today and cancel remaining reminders
        NotificationService.shared.recordFoodSnap()
        // Call the success callback through the manager
        CameraCallbackManager.shared.callPhotoSuccess()

        self?.temporaryTimestamp = nil
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
        CameraCallbackManager.shared.callPhotoStarted()
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
      StatisticsService.shared.clearExpiredCache()

      // Use the new unified approach: fetch + map + store + callback
      ProductStorageService.shared.fetchAndProcessProducts(tempImageTime: tempTimestamp) {
        [weak self] _, _, _ in
        // Record that user snapped food today and cancel remaining reminders
        NotificationService.shared.recordFoodSnap()
        // Call the success callback through the manager
        CameraCallbackManager.shared.callPhotoSuccess()

        self?.temporaryTimestamp = nil
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
