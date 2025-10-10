import UIKit

final class HapticsService {
  static let shared = HapticsService()
  private init() {}

  private let impactLight = UIImpactFeedbackGenerator(style: .light)
  private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
  private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
  private let notification = UINotificationFeedbackGenerator()
  private let selection = UISelectionFeedbackGenerator()

  func lightImpact() {
    impactLight.impactOccurred()
  }

  func mediumImpact() {
    impactMedium.impactOccurred()
  }

  func heavyImpact() {
    impactHeavy.impactOccurred()
  }

  func success() {
    notification.notificationOccurred(.success)
  }

  func warning() {
    notification.notificationOccurred(.warning)
  }

  func error() {
    notification.notificationOccurred(.error)
  }

  func select() {
    selection.selectionChanged()
  }
}


