import SwiftUI
import AVFoundation

enum MascotState {
  case happy      // General happiness (good food, wins)
  case angry      // General anger (loss)
  case badFood    // Bad/unhealthy food (chips, burger)
  case gym        // Gym/sport activity
  case alcohol    // Drinking alcohol
}

enum AppMascot: String, CaseIterable {
  case none = "none"
  case cat = "cat"
  case dog = "dog"
  
  var displayName: String {
    switch self {
    case .none: return "Default"
    case .cat: return "Cat"
    case .dog: return "Root"
    }
  }
  
  var icon: String {
    switch self {
    case .none: return "star.fill"
    case .cat: return "🐱"
    case .dog: return "🐶"
    }
  }

  var mealPlannerMascotImage: String? {
    switch self {
    case .none: return nil
    case .cat: return "british_cat_food_bowl"
    case .dog: return "french_bulldog_happy"
    }
  }
  
  // All available images for each state (for rotation)
  func images(for state: MascotState) -> [String] {
    switch (self, state) {
    case (.none, _): 
      return []
      
    case (.cat, .happy):
      // 3-frame rotation: salad, excited, bowl
      return ["british_cat_happy",
              "british_cat_excited",
              "british_cat_food_bowl"]
      
    case (.cat, .badFood):
      // Separate state for unhealthy food
      return ["british_cat_bad_food"]
      
    case (.cat, .angry):
      // For losses/anger also show bad_food
      return ["british_cat_bad_food"]
      
    case (.cat, .gym):
      return ["british_cat_gym"]
      
    case (.cat, .alcohol):
      return ["british_cat_alcohol"]
      
    case (.dog, .happy):
      // 4-frame rotation: salad, toys, duck, coconut
      return ["french_bulldog_happy",
              "french_bulldog_toys",
              "french_bulldog_duck",
              "french_bulldog_coconut"]
      
    case (.dog, .badFood):
      return ["french_bulldog_bad_food"]
      
    case (.dog, .angry):
      return ["french_bulldog_bad_food"]
      
    case (.dog, .gym):
      return ["french_bulldog_gym", "french_bulldog_towel"]
      
    case (.dog, .alcohol):
      return ["french_bulldog_alcohol"]
    }
  }
  
  // Get single image for state (with rotation)
  func image(for state: MascotState) -> String? {
    let availableImages = images(for: state)
    guard !availableImages.isEmpty else { return nil }
    
    // If only one image, return it
    if availableImages.count == 1 {
      return availableImages[0]
    }
    
    // Get current rotation index from UserDefaults
    let key = "mascot_rotation_\(self.rawValue)_\(state)"
    let currentIndex = UserDefaults.standard.integer(forKey: key)
    
    // Get image at current index
    let imageIndex = currentIndex % availableImages.count
    let selectedImage = availableImages[imageIndex]
    
    // Increment index for next time
    UserDefaults.standard.set(currentIndex + 1, forKey: key)
    
    return selectedImage
  }
  
  // Legacy support
  func happyImage() -> String? {
    return image(for: .happy)
  }
  
  func angryImage() -> String? {
    return image(for: .angry)
  }
  
  // Theme-specific icons
  func icon(for systemIcon: String) -> String {
    switch self {
    case .none:
      return systemIcon
    case .cat:
      // Cat themed icons (paws, fish, bunny instead of default)
      switch systemIcon {
      case "checkmark.circle.fill": return "pawprint.circle.fill"
      case "flame.fill": return "fish.fill"
      case "figure.run": return "hare.fill"  // cat chasing
      case "trophy.fill": return "crown.fill"
      case "heart.fill": return "suit.heart.fill"
      case "wineglass", "wineglass.fill": return "pawprint.circle.fill"  // alcohol → paw
      default: return systemIcon
      }
    case .dog:
      // Dog themed icons (paws, bone, bunny)
      switch systemIcon {
      case "checkmark.circle.fill": return "pawprint.circle.fill"
      // NOTE: `bone.fill` is not available on some iOS/SF Symbols versions → icon may disappear.
      // Use a universally-available dog-themed symbol instead.
      case "flame.fill": return "pawprint.fill"
      case "figure.run": return "hare.fill"  // dog playing
      case "trophy.fill": return "medal.fill"
      case "heart.fill": return "suit.heart.fill"
      case "wineglass", "wineglass.fill": return "pawprint.circle.fill"  // alcohol → paw
      default: return systemIcon
      }
    }
  }
}

class ThemeService: ObservableObject {
  static let shared = ThemeService()
  
  @Published var currentMascot: AppMascot {
    didSet {
      UserDefaults.standard.set(currentMascot.rawValue, forKey: "app_mascot")
      objectWillChange.send()
    }
  }
  
  @Published var soundEnabled: Bool {
    didSet {
      UserDefaults.standard.set(soundEnabled, forKey: "theme_sound_enabled")
    }
  }
  
  private var audioPlayer: AVAudioPlayer?
  
  private init() {
    let savedMascot = UserDefaults.standard.string(forKey: "app_mascot") ?? "none"
    self.currentMascot = AppMascot(rawValue: savedMascot) ?? .none
    self.soundEnabled = UserDefaults.standard.object(forKey: "theme_sound_enabled") as? Bool ?? true
  }
  
  // MARK: - Motivational Messages
  
  func getMotivationalMessage(for action: String, language: String = "en") -> String {
    switch currentMascot {
    case .none:
      return getDefaultMessage(for: action, language: language)
    case .cat:
      return getCatMessage(for: action, language: language)
    case .dog:
      return getDogMessage(for: action, language: language)
    }
  }
  
  private func getDefaultMessage(for action: String, language: String) -> String {
    switch action {
    case "food_logged": return language == "uk" ? "Їжа записана!" : "Food Logged!"
    case "activity_recorded": return language == "uk" ? "Активність записана!" : "Activity Recorded!"
    case "goal_reached": return language == "uk" ? "Мета досягнута!" : "Goal Reached!"
    default: return language == "uk" ? "Чудово!" : "Great!"
    }
  }
  
  private func getCatMessage(for action: String, language: String) -> String {
    switch action {
    case "food_logged", "good_food": return language == "uk" ? "Мур-мур! Смачного! 🐱" : "Meow! Enjoy your meal! 🐱"
    case "bad_food", "sugar", "alcohol": return language == "uk" ? "Фр-р-р! Це не здорова їжа! 😾" : "Hiss! That's not healthy! 😾"
    case "activity_recorded": return language == "uk" ? "Гарний котик! Продовжуй рухатись! 🐾" : "Good kitty! Keep moving! 🐾"
    case "goal_reached": return language == "uk" ? "Мур-р-р! Ти досяг мети! 👑" : "Purr-fect! Goal achieved! 👑"
    case "water_logged": return language == "uk" ? "Лап лап! Води ковток! 💧" : "Lap lap! Water break! 💧"
    case "chess_won": return language == "uk" ? "Мяу! Котик перехитрив! 🐱♟️" : "Meow! Cat outsmarted them! 🐱♟️"
    case "loss": return language == "uk" ? "Мур-р... Наступного разу! 🐾" : "Meow... Next time! 🐾"
    default: return language == "uk" ? "Мур-р! Чудово! 🐱" : "Purr-fect! 🐱"
    }
  }
  
  private func getDogMessage(for action: String, language: String) -> String {
    switch action {
    case "food_logged", "good_food": return language == "uk" ? "Гав-гав! Смачна їжа! 🐶" : "Woof! Yummy food! 🐶"
    case "bad_food", "sugar", "alcohol": return language == "uk" ? "Гр-р-р! Це погана їжа! 😠" : "Grr! That's bad food! 😠"
    case "activity_recorded": return language == "uk" ? "Гарна робота! Ще гуляти! 🐾" : "Good job! More walkies! 🐾"
    case "goal_reached": return language == "uk" ? "Гав! Ти найкращий! 🏆" : "Woof! You're the best! 🏆"
    case "water_logged": return language == "uk" ? "Хап-хап! Ковток води! 💧" : "Slurp slurp! Water time! 💧"
    case "chess_won": return language == "uk" ? "Гав! Собака виграв! 🐶♟️" : "Woof! Doggo wins! 🐶♟️"
    case "loss": return language == "uk" ? "Гав-гав... Спробуй ще! 🐾" : "Woof... Try again! 🐾"
    default: return language == "uk" ? "Гав! Молодець! 🐶" : "Woof! Great job! 🐶"
    }
  }
  
  // MARK: - Sound Effects
  
  func playSound(for action: String) {
    guard soundEnabled else { return }
    guard let soundName = Self.soundFileName(mascot: currentMascot, action: action) else { return }

    // Session changes and playback stay off the main thread. The sync
    // setCategory/setActive/play calls were hanging the UI.
    Task.detached {
      guard let player = await ThemeService.makePlayer(named: soundName) else { return }
      await MainActor.run { [weak self] in
        self?.audioPlayer = player
      }
    }
  }

  private static func soundFileName(mascot: AppMascot, action: String) -> String? {
    switch (mascot, action) {
    case (.cat, "success"), (.cat, "happy"), (.cat, "good_food"), (.cat, "activity"):
      return "cat_happy"
    case (.dog, "success"), (.dog, "happy"), (.dog, "good_food"), (.dog, "activity"):
      return "dog_happy"
    case (.cat, "error"), (.cat, "angry"), (.cat, "bad_food"), (.cat, "sugar"), (.cat, "alcohol"), (.cat, "loss"):
      return "cat_hiss"
    case (.dog, "error"), (.dog, "angry"), (.dog, "bad_food"), (.dog, "sugar"), (.dog, "alcohol"), (.dog, "loss"):
      return "dog_growl"
    default:
      return nil
    }
  }

  nonisolated private static func makePlayer(named soundName: String) async -> AVAudioPlayer? {
    let session = AVAudioSession.sharedInstance()
    do {
      // Ambient mixes with other audio and leaves the food buzz alone.
      try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
      try await session.setActive(true)
    } catch {
      print("Failed to activate audio session: \(error)")
      return nil
    }

    for ext in ["m4a", "mp3", "wav"] {
      guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: ext) else { continue }
      do {
        let player = try AVAudioPlayer(contentsOf: soundURL)
        player.volume = 0.5
        player.prepareToPlay()
        player.play()
        return player
      } catch {
        print("Failed to play sound \(soundName).\(ext): \(error)")
      }
    }
    print("⚠️ Sound file not found: \(soundName) (tried: m4a, mp3, wav)")
    return nil
  }
  
  /// Quality buzz, then the pet sound. Waits until at least 0.4s after the upload tap.
  func playSoundForFood(healthRating: Int, uploadTap: Date = Date()) {
    let wait = max(0, 0.4 - Date().timeIntervalSince(uploadTap))
    DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
      HapticsService.shared.foodQuality(rating: healthRating)
      guard let self else { return }
      if healthRating <= 50 {
        self.playSound(for: "bad_food")
      } else {
        self.playSound(for: "good_food")
      }
    }
  }
  
  // Get mascot image for display (happy or angry based on context) - Legacy
  func getMascotImage(isHappy: Bool) -> String? {
    return isHappy ? currentMascot.happyImage() : currentMascot.angryImage()
  }
  
  // Get mascot image for specific state
  func getMascotImage(for state: MascotState) -> String? {
    return currentMascot.image(for: state)
  }
  
  // Get mascot image based on action
  func getMascotImageForAction(_ action: String) -> String? {
    switch action {
    case "gym", "activity_recorded": return getMascotImage(for: .gym)
    case "alcohol": return getMascotImage(for: .alcohol)
    case "bad_food": return getMascotImage(for: .badFood)
    case "sugar", "loss", "error", "angry": return getMascotImage(for: .angry)
    default: return getMascotImage(for: .happy)
    }
  }

  /// Returns `count` unique preview images for the current mascot.
  /// Used in Profile → Theme to avoid showing repeated photos.
  func getUniquePreviewImageNames(count: Int = 5) -> [String] {
    guard currentMascot != .none else { return [] }

    // Build a unique pool (avoid angry because it often duplicates badFood).
    let poolStates: [MascotState] = [.happy, .gym, .badFood, .alcohol]
    var unique: [String] = []
    var seen = Set<String>()
    for state in poolStates {
      for name in currentMascot.images(for: state) {
        if !seen.contains(name) {
          unique.append(name)
          seen.insert(name)
        }
      }
    }

    guard !unique.isEmpty else { return [] }

    // Rotate across sessions so previews vary, but keep uniqueness within a row.
    let key = "mascot_preview_rotation_\(currentMascot.rawValue)"
    let start = UserDefaults.standard.integer(forKey: key) % unique.count
    let take = min(count, unique.count)

    var result: [String] = []
    result.reserveCapacity(take)
    for i in 0..<take {
      result.append(unique[(start + i) % unique.count])
    }

    UserDefaults.standard.set((start + take) % unique.count, forKey: key)
    return result
  }
  
  // MARK: - Helper
  
  func icon(for systemIcon: String) -> String {
    return currentMascot.icon(for: systemIcon)
  }
}
