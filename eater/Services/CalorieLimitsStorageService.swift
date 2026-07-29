import Foundation

/// Persist and retrieve user calorie limits using a JSON file in Application Support.
/// We avoid relying solely on UserDefaults to ensure the data does not get purged and
/// remains independent of transient memory; JSON file is human-inspectable for debugging.
final class CalorieLimitsStorageService {
  static let shared = CalorieLimitsStorageService()
  private init() {}

  private let fileName = "calorie_limits.json"

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
  }

  func load() -> Limits? {
    do {
      let url = fileURL
      guard FileManager.default.fileExists(atPath: url.path) else { return nil }
      let data = try Data(contentsOf: url)
      let limits = try JSONDecoder().decode(Limits.self, from: data)
      return limits
    } catch {
      return nil
    }
  }

  func save(_ limits: Limits) {
    do {
      let data = try JSONEncoder().encode(limits)
      try data.write(to: fileURL, options: [.atomic])
    } catch {
    }
  }
}


