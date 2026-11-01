import CoreHaptics
import UIKit

final class HapticsService {
  static let shared = HapticsService()
  private init() {}

  private let impactLight = UIImpactFeedbackGenerator(style: .light)
  private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
  private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
  private let notification = UINotificationFeedbackGenerator()
  private let selection = UISelectionFeedbackGenerator()
  private var engine: CHHapticEngine?

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

  /// Buzz for the logged meal. Default, cat, and dog each feel different,
  /// and a poor score (50 or below) feels different from a good one.
  func foodQuality(rating: Int) {
    guard AppSettingsService.shared.vibrationEnabled else { return }
    let pleasant = rating > 50
    let mascot = ThemeService.shared.currentMascot
    if playFoodPattern(events: foodEvents(mascot: mascot, pleasant: pleasant)) { return }
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    generator.notificationOccurred(pleasant ? .success : .error)
  }

  private func foodEvents(mascot: AppMascot, pleasant: Bool) -> [CHHapticEvent] {
    switch (mascot, pleasant) {
    case (.none, true):
      // One clean tap, then a short soft follow.
      return [
        transient(time: 0, intensity: 0.55, sharpness: 0.35),
        continuous(time: 0.08, duration: 0.12, intensity: 0.28, sharpness: 0.15),
      ]
    case (.none, false):
      return [
        transient(time: 0, intensity: 0.9, sharpness: 0.95),
        transient(time: 0.09, intensity: 0.7, sharpness: 0.8),
      ]
    case (.cat, true):
      // Light fast ticks, like a purr.
      return [
        transient(time: 0, intensity: 0.22, sharpness: 0.7),
        transient(time: 0.07, intensity: 0.28, sharpness: 0.65),
        transient(time: 0.14, intensity: 0.34, sharpness: 0.55),
        transient(time: 0.22, intensity: 0.22, sharpness: 0.45),
      ]
    case (.cat, false):
      // One sharp scratch.
      return [
        continuous(time: 0, duration: 0.07, intensity: 1, sharpness: 1),
        transient(time: 0.16, intensity: 0.35, sharpness: 0.9),
      ]
    case (.dog, true):
      // Two heavier thumps, like a woof.
      return [
        transient(time: 0, intensity: 0.9, sharpness: 0.08),
        transient(time: 0.2, intensity: 0.75, sharpness: 0.05),
      ]
    case (.dog, false):
      // A low rumble.
      return [
        continuous(time: 0, duration: 0.38, intensity: 0.85, sharpness: 0.02),
      ]
    }
  }

  private func playFoodPattern(events: [CHHapticEvent]) -> Bool {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
    if engine == nil {
      engine = try? CHHapticEngine()
      engine?.isAutoShutdownEnabled = true
      engine?.resetHandler = { [weak self] in
        try? self?.engine?.start()
      }
    }
    guard let engine else { return false }
    do {
      try engine.start()
      let pattern = try CHHapticPattern(events: events, parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
      return true
    } catch {
      return false
    }
  }

  private func transient(time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
    CHHapticEvent(
      eventType: .hapticTransient,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
      ],
      relativeTime: time
    )
  }

  private func continuous(
    time: TimeInterval,
    duration: TimeInterval,
    intensity: Float,
    sharpness: Float
  ) -> CHHapticEvent {
    CHHapticEvent(
      eventType: .hapticContinuous,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
      ],
      relativeTime: time,
      duration: duration
    )
  }
}


