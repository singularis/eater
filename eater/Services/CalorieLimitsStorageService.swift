import Foundation

/// Persist and retrieve user calorie limits using a JSON file in Application Support.
/// We avoid relying solely on UserDefaults to ensure the data does not get purged and
/// remains independent of transient memory; JSON file is human-inspectable for debugging.
final class CalorieLimitsStorageService {
  static let shared = CalorieLimitsStorageService()
  private init() {}

  private let fileName = "calorie_limits.json"
  private let proteinDefaultsKey = "customProteinGoal"
  private let fatDefaultsKey = "customFatGoal"
  private let carbsDefaultsKey = "customCarbsGoal"

  private var supportDirectoryURL: URL {
    let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    let appSupport = urls.first!
    let bundleId = Bundle.main.bundleIdentifier ?? "eater.app"
    let dir = appSupport.appendingPathComponent(bundleId, isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  private var fileURL: URL { supportDirectoryURL.appendingPathComponent(fileName) }

  struct Limits: Codable {
    var softLimit: Int
    var hardLimit: Int
    var hasManualCalorieLimits: Bool
    /// Custom macro goals in grams. When nil, the app derives a target from
    /// softLimit using the default 20% protein / 30% fat / 50% carbs split.
    var customProteinGoal: Double? = nil
    var customFatGoal: Double? = nil
    var customCarbsGoal: Double? = nil
  }

  func load() -> Limits? {
    var limits: Limits?
    do {
      let url = fileURL
      if FileManager.default.fileExists(atPath: url.path) {
        let data = try Data(contentsOf: url)
        limits = try JSONDecoder().decode(Limits.self, from: data)
      }
    } catch {
      limits = nil
    }
    guard var loaded = limits else { return nil }
    if loaded.customProteinGoal == nil {
      loaded.customProteinGoal = doubleIfPresent(proteinDefaultsKey)
    }
    if loaded.customFatGoal == nil {
      loaded.customFatGoal = doubleIfPresent(fatDefaultsKey)
    }
    if loaded.customCarbsGoal == nil {
      loaded.customCarbsGoal = doubleIfPresent(carbsDefaultsKey)
    }
    return loaded
  }

  func save(_ limits: Limits, preserveCustomMacros: Bool = true) {
    var toSave = limits
    if preserveCustomMacros, let existing = load() {
      if toSave.customProteinGoal == nil { toSave.customProteinGoal = existing.customProteinGoal }
      if toSave.customFatGoal == nil { toSave.customFatGoal = existing.customFatGoal }
      if toSave.customCarbsGoal == nil { toSave.customCarbsGoal = existing.customCarbsGoal }
    }
    do {
      let data = try JSONEncoder().encode(toSave)
      try data.write(to: fileURL, options: [.atomic])
    } catch {
    }
    writeMacroDefaults(toSave, clearMissing: !preserveCustomMacros)
  }

  private func doubleIfPresent(_ key: String) -> Double? {
    guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
    return UserDefaults.standard.double(forKey: key)
  }

  private func writeMacroDefaults(_ limits: Limits, clearMissing: Bool) {
    if let protein = limits.customProteinGoal {
      UserDefaults.standard.set(protein, forKey: proteinDefaultsKey)
    } else if clearMissing {
      UserDefaults.standard.removeObject(forKey: proteinDefaultsKey)
    }
    if let fat = limits.customFatGoal {
      UserDefaults.standard.set(fat, forKey: fatDefaultsKey)
    } else if clearMissing {
      UserDefaults.standard.removeObject(forKey: fatDefaultsKey)
    }
    if let carbs = limits.customCarbsGoal {
      UserDefaults.standard.set(carbs, forKey: carbsDefaultsKey)
    } else if clearMissing {
      UserDefaults.standard.removeObject(forKey: carbsDefaultsKey)
    }
  }
}


