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
  let mealRemaining: MealPlannerRemaining
  let mealsToday: Int
  let languageCode: String
  var onPhotoSuccess: (() -> Void)?
  var onPhotoFailure: (() -> Void)?
  var onPhotoStarted: ((UIImage?) -> Void)?
  var onReturnToToday: (() -> Void)?
  var onRequestTutorial: ((String) -> Void)?
  /// Toggled externally (e.g. swipe-right on Home) to trigger the same
  /// camera flow as tapping "Take Food Photo", including backdating checks.
  var externalCameraTrigger: Binding<Bool> = .constant(false)

  @State private var showMealPlanner = false
  @State private var mealPlannerCycle = 0
  @State private var plannerBeatScale: CGFloat = 1.0
  @ObservedObject private var themeService = ThemeService.shared

  init(
    isLoadingFoodPhoto: Bool,
    selectedDate: Date = Date(),
    isViewingCustomDate: Bool = false,
    mealRemaining: MealPlannerRemaining = MealPlannerRemaining(kcal: 0, protein: 0, carbs: 0, fats: 0, sugar: 0),
    mealsToday: Int = 0,
    languageCode: String = "en",
    onPhotoSuccess: (() -> Void)?,
    onPhotoFailure: (() -> Void)?,
    onPhotoStarted: ((UIImage?) -> Void)?,
    onReturnToToday: (() -> Void)? = nil,
    onRequestTutorial: ((String) -> Void)? = nil,
    externalCameraTrigger: Binding<Bool> = .constant(false)
  ) {
    self.isLoadingFoodPhoto = isLoadingFoodPhoto
    self.selectedDate = selectedDate
    self.isViewingCustomDate = isViewingCustomDate
    self.mealRemaining = mealRemaining
    self.mealsToday = mealsToday
    self.languageCode = languageCode
    self.onPhotoSuccess = onPhotoSuccess
    self.onPhotoFailure = onPhotoFailure
    self.onPhotoStarted = onPhotoStarted
    self.onReturnToToday = onReturnToToday
    self.onRequestTutorial = onRequestTutorial
    self.externalCameraTrigger = externalCameraTrigger
  }

  var body: some View {
    cameraActionRow
      .frame(height: 80)
      .onAppear { startPlannerPulse() }
      .onChange(of: themeService.currentMascot) { _, _ in
        startPlannerPulse()
      }
      .onChange(of: externalCameraTrigger.wrappedValue) { _, _ in
        checkBackdating(sourceType: .camera)
      }
      .modifier(CameraButtonSheets(
        showCamera: $showCamera,
        showPhotoLibrary: $showPhotoLibrary,
        showMealPlanner: $showMealPlanner,
        isViewingCustomDate: isViewingCustomDate,
        selectedDate: selectedDate,
        mealRemaining: mealRemaining,
        mealsToday: mealsToday,
        languageCode: languageCode,
        mealPlannerCycle: mealPlannerCycle,
        onPhotoSuccess: onPhotoSuccess,
        onPhotoFailure: onPhotoFailure,
        onPhotoStarted: onPhotoStarted
      ))
      .modifier(CameraButtonAlerts(
        cameraUnavailableAlert: $cameraUnavailableAlert,
        photoLibraryUnavailableAlert: $photoLibraryUnavailableAlert,
        showBackdatingAlert: $showBackdatingAlert,
        pendingSourceType: $pendingSourceType,
        backdatingStatusEmoji: backdatingStatusEmoji,
        backdatingMessage: backdatingMessage,
        onConfirmBackdate: {
          if let type = pendingSourceType {
            openCamera(sourceType: type)
          }
        },
        onReturnToToday: onReturnToToday
      ))
  }

  private var cameraActionRow: some View {
    GeometryReader { geo in
      let totalWidth = geo.size.width
      let rowHeight = geo.size.height
      let usesPlannerImage = themeService.currentMascot != .none
      let uploadWidth = totalWidth * 0.26
      let plannerWidth = usesPlannerImage
        ? min(rowHeight, totalWidth * 0.22)
        : uploadWidth
      let gapWidth = totalWidth * 0.03
      let takeWidth = totalWidth - uploadWidth - plannerWidth - gapWidth * 2

      HStack(alignment: .center, spacing: 0) {
        uploadButton(width: uploadWidth, height: rowHeight)
        Color.clear.frame(width: gapWidth, height: rowHeight)
        plannerButton(width: plannerWidth, height: rowHeight)
        Color.clear.frame(width: gapWidth, height: rowHeight)
        takePhotoButton(width: takeWidth, height: rowHeight)
      }
      .frame(width: totalWidth, height: rowHeight, alignment: .center)
    }
  }

  private func uploadButton(width: CGFloat, height: CGFloat) -> some View {
    Button(action: {
      if let req = onRequestTutorial, !KeychainHelper.shared.getBool("hasSeenCameraTutorial") {
        req("hasSeenCameraTutorial")
        return
      }
      HapticsService.shared.select()
      checkBackdating(sourceType: .photoLibrary)
    }) {
      HStack(spacing: 3) {
        Image(systemName: "photo.fill")
          .font(.system(size: 16))
        Text(loc("camera.upload", "Upload"))
          .font(.system(size: 15, weight: .medium, design: .rounded))
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
      }
      .foregroundColor(AppTheme.textPrimary)
      .frame(width: width, height: height)
      .background(quietBarFill)
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(isLoadingFoodPhoto)
  }

  private func plannerButton(width: CGFloat, height: CGFloat) -> some View {
    Button(action: {
      HapticsService.shared.select()
      if showMealPlanner {
        mealPlannerCycle += 1
      } else {
        showMealPlanner = true
      }
    }) {
      plannerButtonLabel(width: width, height: height)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel(loc("camera.mealplan", "Meal"))
  }

  private func takePhotoButton(width: CGFloat, height: CGFloat) -> some View {
    Button(action: {
      if let req = onRequestTutorial, !KeychainHelper.shared.getBool("hasSeenCameraTutorial") {
        req("hasSeenCameraTutorial")
        return
      }
      HapticsService.shared.select()
      checkBackdating(sourceType: .camera)
    }) {
      HStack(spacing: 5) {
        Image(systemName: "camera.fill")
          .font(.system(size: 18))
        Text(loc("camera.takefood", "Take Food Photo"))
          .font(.system(size: 15, weight: .medium, design: .rounded))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .foregroundColor(.white)
      .frame(width: width, height: height)
      .background(primaryBarFill)
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(isLoadingFoodPhoto)
  }

  private var shouldPulsePlanner: Bool {
    mealsToday < 1 && !AppSettingsService.shared.reduceMotion
  }

  private var quietBarFill: some View {
    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
      .fill(AppTheme.surface)
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
          .stroke(AppTheme.divider, lineWidth: 1)
      )
  }

  private var primaryBarFill: some View {
    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
      .fill(AppTheme.primaryButtonFill)
      .appCardShadow()
  }

  /// Cat/dog theme: meal-advice artwork. Default theme: quiet Meal word, like Upload.
  @ViewBuilder
  private func plannerButtonLabel(width: CGFloat, height: CGFloat) -> some View {
    if themeService.currentMascot != .none {
      Image("meal_planner")
        .resizable()
        .interpolation(.high)
        .scaledToFill()
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .scaleEffect(shouldPulsePlanner ? plannerBeatScale : 1.0)
        .appCardShadow()
    } else {
      HStack(spacing: 3) {
        Image(systemName: "fork.knife")
          .font(.system(size: 16))
        Text(loc("camera.mealplan", "Meal"))
          .font(.system(size: 15, weight: .medium, design: .rounded))
          .multilineTextAlignment(.center)
          .lineLimit(1)
      }
      .foregroundColor(AppTheme.textPrimary)
      .frame(width: width, height: height)
      .background(quietBarFill)
    }
  }

  private func startPlannerPulse() {
    // Pulse only the themed picture. Scaling the word button makes the text look low-res.
    guard shouldPulsePlanner, themeService.currentMascot != .none else {
      plannerBeatScale = 1.0
      return
    }
    plannerBeatScale = 1.0
    withAnimation(
      .easeInOut(duration: 0.45)
      .repeatForever(autoreverses: true)
    ) {
      plannerBeatScale = 1.12
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

private struct CameraButtonSheets: ViewModifier {
  @Binding var showCamera: Bool
  @Binding var showPhotoLibrary: Bool
  @Binding var showMealPlanner: Bool
  let isViewingCustomDate: Bool
  let selectedDate: Date
  let mealRemaining: MealPlannerRemaining
  let mealsToday: Int
  let languageCode: String
  let mealPlannerCycle: Int
  let onPhotoSuccess: (() -> Void)?
  let onPhotoFailure: (() -> Void)?
  let onPhotoStarted: ((UIImage?) -> Void)?

  func body(content: Content) -> some View {
    content
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
      .sheet(isPresented: $showMealPlanner) {
        MealPlannerView(
          remaining: mealRemaining,
          mealsToday: mealsToday,
          languageCode: languageCode,
          cycleToken: mealPlannerCycle
        )
      }
  }
}

private struct CameraButtonAlerts: ViewModifier {
  @Binding var cameraUnavailableAlert: Bool
  @Binding var photoLibraryUnavailableAlert: Bool
  @Binding var showBackdatingAlert: Bool
  @Binding var pendingSourceType: UIImagePickerController.SourceType?
  let backdatingStatusEmoji: String
  let backdatingMessage: String
  let onConfirmBackdate: () -> Void
  let onReturnToToday: (() -> Void)?

  func body(content: Content) -> some View {
    content
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
          onConfirmBackdate()
        }
        Button(loc("backdating.alert.log_today", "Log Today's Food")) {
          pendingSourceType = nil
          onReturnToToday?()
        }
      } message: {
        Text(
          backdatingStatusEmoji + " " + backdatingMessage + "\n\n"
            + loc("backdating.alert.tip", "Tip: You can log today's food instead."))
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
            if overLimit {
              ThemeService.shared.playSound(for: "bad_food")
            } else if let added = products.first(where: { $0.time == tempTimestamp })
              ?? products.max(by: { $0.time < $1.time }) {
              ThemeService.shared.playSoundForFood(healthRating: added.healthRating >= 0 ? added.healthRating : 70)
            } else {
              ThemeService.shared.playSound(for: "good_food")
            }
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
            if overLimit {
              ThemeService.shared.playSound(for: "bad_food")
            } else if let added = products.first(where: { $0.time == tempTimestamp })
              ?? products.max(by: { $0.time < $1.time }) {
              ThemeService.shared.playSoundForFood(healthRating: added.healthRating >= 0 ? added.healthRating : 70)
            } else {
              ThemeService.shared.playSound(for: "good_food")
            }
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
