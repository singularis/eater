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

  @Published var pendingMeal: PendingMeal?
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

  @Published var cameraTutorialRequested = false
  @Published var pendingCaptureIsUpload = false
  /// After the first-time camera explainer, open the capture UI.
  @Published var openCaptureAfterTutorial = false
  /// After the first-time stats explainer, open the Stats tab.
  @Published var openStatsAfterTutorial = false

  private var toastHideTask: Task<Void, Never>?

  func openCamera() {
    pendingCaptureIsUpload = false
    if !KeychainHelper.shared.getBool("hasSeenCameraTutorial") {
      openCaptureAfterTutorial = true
      cameraTutorialRequested = true
      return
    }
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      cameraUnavailableAlert = true
      return
    }
    showFoodCamera = true
  }

  func openPhotoLibrary() {
    pendingCaptureIsUpload = true
    if !KeychainHelper.shared.getBool("hasSeenCameraTutorial") {
      openCaptureAfterTutorial = true
      cameraTutorialRequested = true
      return
    }
    guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
      photoLibraryUnavailableAlert = true
      return
    }
    showPhotoLibrary = true
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
    toastHideTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run { self?.toastMessage = nil }
    }
  }

}
