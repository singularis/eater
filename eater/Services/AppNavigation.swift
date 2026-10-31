import SwiftUI
import UIKit

enum AppTab: Hashable {
  case today
  case ideas
  case camera
  case upload
  case stats
}

struct PendingMeal: Identifiable {
  let id = UUID()
  let image: UIImage
  let startedAt = Date()
}

/// One "Type food" sheet. The time is fixed when the sheet opens.
struct TypeFoodRequest: Identifiable {
  let id = UUID()
  /// Nil logs the meal now.
  let timestampMillis: Int64?
  /// Shown in the sheet when logging for a past day.
  let dayLabel: String?
}

/// Shared shell state for the tab bar, camera, and cross-tab sheets.
final class AppNavigation: ObservableObject {
  static let shared = AppNavigation()

  @Published var selectedTab: AppTab = .today

  @Published var showFoodCamera = false
  @Published var showPhotoLibrary = false
  @Published var showWeightMenu = false
  @Published var showWeightCamera = false
  @Published var showManualWeight = false
  @Published var showActivities = false
  @Published var showAlcohol = false
  @Published var showInPlaceLogin = false
  @Published var showAnonymousLoginPrompt = false
  /// Set while a capture sheet is up so the guest login ask waits until the camera closes.
  var pendingAnonymousLoginPrompt = false
  @Published var showHowItWorks = false
  @Published var cameraUnavailableAlert = false
  @Published var photoLibraryUnavailableAlert = false
  @Published var showBackdatingAlert = false
  @Published var backdatingStatusEmoji = ""
  @Published var backdatingMessage = ""

  @Published var pendingMeal: PendingMeal?
  @Published var typeFoodRequest: TypeFoodRequest?
  /// The past-date question was asked for typed food, not for a photo.
  private var backdatingForTypedFood = false
  @Published var toastMessage: String?
  @Published var isLoadingFoodPhoto = false
  @Published var isLoadingWeightPhoto = false

  @Published var selectedDate = Date()
  @Published var isViewingCustomDate = false
  @Published var mealsToday = 0
  @Published var mealRemaining = MealPlannerRemaining(
    kcal: 0, protein: 0, carbs: 0, fats: 0, sugar: 0
  )
  @Published var languageCode = "en"
  @Published var activitiesDateISO = ""

  @Published var photoSuccessToken = 0
  @Published var photoFailureToken = 0
  @Published var todayRefreshToken = 0
  @Published var weightSuccessToken = 0
  @Published var returnToTodayToken = 0
  /// Bumped after a guest signs in, so Home reloads the merged meals.
  @Published var accountMergedToken = 0

  @Published var cameraTutorialRequested = false
  @Published var pendingCaptureIsUpload = false
  /// After the first-time camera explainer, open the capture UI.
  @Published var openCaptureAfterTutorial = false
  /// After the first-time stats explainer, open the Stats tab.
  @Published var openStatsAfterTutorial = false

  private var toastHideTask: Task<Void, Never>?

  func openCamera() {
    pendingCaptureIsUpload = false
    backdatingForTypedFood = false
    if !KeychainHelper.shared.getBool("hasSeenCameraTutorial") {
      openCaptureAfterTutorial = true
      cameraTutorialRequested = true
      return
    }
    if needsBackdatingConfirm {
      presentBackdatingPrompt()
      return
    }
    presentPendingCapture()
  }

  func openPhotoLibrary() {
    pendingCaptureIsUpload = true
    backdatingForTypedFood = false
    if !KeychainHelper.shared.getBool("hasSeenCameraTutorial") {
      openCaptureAfterTutorial = true
      cameraTutorialRequested = true
      return
    }
    if needsBackdatingConfirm {
      presentBackdatingPrompt()
      return
    }
    presentPendingCapture()
  }

  var needsBackdatingConfirm: Bool {
    isViewingCustomDate && !Calendar.current.isDateInToday(selectedDate)
  }

  /// Typed food asks the same past-date question as a photo.
  func openTypeFood() {
    if needsBackdatingConfirm {
      backdatingForTypedFood = true
      presentBackdatingPrompt()
      return
    }
    typeFoodRequest = TypeFoodRequest(timestampMillis: nil, dayLabel: nil)
  }

  func confirmPastDateCapture() {
    if backdatingForTypedFood {
      backdatingForTypedFood = false
      presentTypeFoodAfterNotice(TypeFoodRequest(
        timestampMillis: Self.backdatedTimestampMillis(for: selectedDate),
        dayLabel: Self.dayLabel(for: selectedDate)
      ))
      return
    }
    presentPendingCapture()
  }

  func captureForTodayInstead() {
    isViewingCustomDate = false
    selectedDate = Date()
    returnToTodayToken += 1
    if backdatingForTypedFood {
      backdatingForTypedFood = false
      presentTypeFoodAfterNotice(TypeFoodRequest(timestampMillis: nil, dayLabel: nil))
      return
    }
    presentPendingCapture()
  }

  /// The question sheet is still closing; a second sheet in the same moment can be dropped.
  private func presentTypeFoodAfterNotice(_ request: TypeFoodRequest) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
      self?.typeFoodRequest = request
    }
  }

  func cancelBackdating() {
    backdatingForTypedFood = false
  }

  /// Noon UTC of the chosen day, same as photo backdating, so no time zone moves it to another day.
  static func backdatedTimestampMillis(for day: Date) -> Int64 {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
    var utc = DateComponents()
    utc.year = components.year
    utc.month = components.month
    utc.day = components.day
    utc.hour = 12
    utc.timeZone = TimeZone(abbreviation: "UTC")
    let date = Calendar(identifier: .gregorian).date(from: utc) ?? day
    return Int64(date.timeIntervalSince1970 * 1000)
  }

  static func dayLabel(for day: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: LanguageService.shared.currentCode)
    formatter.dateFormat = "EEEE, d MMMM"
    return formatter.string(from: day)
  }

  func noteTypedFoodSuccess(dishName: String) {
    typeFoodRequest = nil
    photoSuccessToken += 1
    let name = DishNameNormalizer.dishName(dishName)
    if !name.isEmpty {
      presentToast(String(format: loc("type_food.logged_as", "Logged as %@"), name))
    }
  }

  func requestReturnToToday() {
    isViewingCustomDate = false
    selectedDate = Date()
    returnToTodayToken += 1
  }

  private func presentBackdatingPrompt() {
    let diff = Date().timeIntervalSince(selectedDate)
    let days = diff / 86400
    let hours = diff / 3600
    let dateString = Self.dayLabel(for: selectedDate)
    let timeAgo: String
    if days >= 1 {
      timeAgo = String(format: loc("backdating.time.days_ago", "%d days ago"), Int(days))
    } else {
      timeAgo = String(format: loc("backdating.time.hours_ago", "%d hours ago"), Int(hours))
    }
    if days > 30 {
      backdatingStatusEmoji = "🔴"
    } else if days < 5 {
      backdatingStatusEmoji = "🟢"
    } else {
      backdatingStatusEmoji = "🟠"
    }
    backdatingMessage = String(
      format: loc("backdating.message.submitting", "Submitting for %@\n(%@)"), dateString, timeAgo)
    showBackdatingAlert = true
  }

  private func presentPendingCapture() {
    if pendingCaptureIsUpload {
      guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
        photoLibraryUnavailableAlert = true
        return
      }
      showPhotoLibrary = true
    } else {
      guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
        cameraUnavailableAlert = true
        return
      }
      showFoodCamera = true
    }
  }

  func beginPendingMeal(image: UIImage?) {
    isLoadingFoodPhoto = true
    if let image {
      pendingMeal = PendingMeal(image: image)
    }
    selectedTab = .today
  }

  func clearPendingMeal() {
    pendingMeal = nil
    isLoadingFoodPhoto = false
  }

  func notePhotoSuccess() {
    clearPendingMeal()
    photoSuccessToken += 1
    todayRefreshToken += 1
  }

  func notePhotoFailure() {
    clearPendingMeal()
    photoFailureToken += 1
  }

  func requestTodayRefresh() {
    todayRefreshToken += 1
  }

  func noteWeightSuccess() {
    isLoadingWeightPhoto = false
    weightSuccessToken += 1
    todayRefreshToken += 1
  }

  /// The server moves guest data after sign-in, so reload now and once more a bit later.
  func noteAccountMerged() {
    pendingAnonymousLoginPrompt = false
    accountMergedToken += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      ProductStorageService.shared.clearCache()
      StatisticsService.shared.clearCache()
      self?.accountMergedToken += 1
    }
  }

  func queueAnonymousLoginPrompt() {
    pendingAnonymousLoginPrompt = true
    tryPresentAnonymousLoginPrompt()
  }

  func tryPresentAnonymousLoginPrompt() {
    guard pendingAnonymousLoginPrompt else { return }
    if showFoodCamera || showPhotoLibrary || showInPlaceLogin || showHowItWorks { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
      guard let self else { return }
      guard self.pendingAnonymousLoginPrompt else { return }
      if self.showFoodCamera || self.showPhotoLibrary || self.showInPlaceLogin || self.showHowItWorks {
        return
      }
      self.pendingAnonymousLoginPrompt = false
      self.showAnonymousLoginPrompt = true
    }
  }

  func presentToast(_ message: String) {
    toastHideTask?.cancel()
    toastMessage = message
    toastHideTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      guard !Task.isCancelled, let self else { return }
      self.toastMessage = nil
    }
  }

}
