import Foundation
import UIKit

struct LocalProfile: Codable, Equatable {
  var nickname: String = ""
  var firstName: String = ""
  var lastName: String = ""
  var pictureId: String = ""
}

final class ProfileLocalStore {
  static let shared = ProfileLocalStore()

  private let fm = FileManager.default
  private let rootURL: URL
  private var ensuredFolders = Set<String>()
  private var lastSaved: (email: String, profile: LocalProfile)?

  private init() {
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    rootURL = docs.appendingPathComponent("EateriaProfile", isDirectory: true)
    ensureFolder(rootURL)
  }

  private func ensureFolder(_ url: URL) {
    let path = url.path
    if ensuredFolders.contains(path) { return }
    if !fm.fileExists(atPath: path) {
      try? fm.createDirectory(at: url, withIntermediateDirectories: true)
    }
    ensuredFolders.insert(path)
  }

  private func folder(for email: String) -> URL {
    let safe = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      .replacingOccurrences(of: "@", with: "_at_")
      .replacingOccurrences(of: "/", with: "_")
    let url = rootURL.appendingPathComponent(safe, isDirectory: true)
    ensureFolder(url)
    return url
  }

  private func profileURL(for email: String) -> URL {
    folder(for: email).appendingPathComponent("profile.json")
  }

  func avatarURL(for email: String) -> URL {
    folder(for: email).appendingPathComponent("avatar.jpg")
  }

  func load(email: String) -> LocalProfile {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
      let data = try? Data(contentsOf: profileURL(for: trimmed)),
      let profile = try? JSONDecoder().decode(LocalProfile.self, from: data)
    else {
      return LocalProfile()
    }
    return profile
  }

  func save(_ profile: LocalProfile, email: String) {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    if lastSaved?.email == trimmed, lastSaved?.profile == profile { return }
    guard let data = try? JSONEncoder().encode(profile) else { return }
    try? data.write(to: profileURL(for: trimmed), options: .atomic)
    lastSaved = (trimmed, profile)
  }

  func saveAvatar(_ image: UIImage, email: String) {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
      let data = image.normalizedUp().jpegData(compressionQuality: 0.9)
    else { return }
    try? data.write(to: avatarURL(for: trimmed), options: .atomic)
  }

  func loadAvatar(email: String) -> UIImage? {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
      let data = try? Data(contentsOf: avatarURL(for: trimmed)),
      let image = UIImage(data: data)
    else { return nil }
    return image
  }

  func restore(email: String) {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let profile = load(email: trimmed)
    let defaults = UserDefaults.standard
    if !profile.nickname.isEmpty {
      defaults.set(profile.nickname, forKey: "user_nickname")
    }
    if !profile.firstName.isEmpty {
      defaults.set(profile.firstName, forKey: "user_first_name")
    }
    if !profile.lastName.isEmpty {
      defaults.set(profile.lastName, forKey: "user_last_name")
    }
    if !profile.pictureId.isEmpty {
      defaults.set(profile.pictureId, forKey: "user_profile_picture_id")
    }
    let display = [profile.firstName, profile.lastName].filter { !$0.isEmpty }.joined(separator: " ")
    if !display.isEmpty {
      defaults.set(display, forKey: "user_name")
    }
    ProfilePhotoStore.shared.loadFromDisk(email: trimmed)
  }

  func persistFromUserDefaults(email: String) {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let defaults = UserDefaults.standard
    var profile = load(email: trimmed)
    profile.nickname = defaults.string(forKey: "user_nickname") ?? profile.nickname
    profile.firstName = defaults.string(forKey: "user_first_name") ?? profile.firstName
    profile.lastName = defaults.string(forKey: "user_last_name") ?? profile.lastName
    profile.pictureId = defaults.string(forKey: "user_profile_picture_id") ?? profile.pictureId
    save(profile, email: trimmed)
  }

  func wipe(email: String) {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let url = folder(for: trimmed)
    try? fm.removeItem(at: url)
    ensuredFolders.remove(url.path)
    if lastSaved?.email == trimmed { lastSaved = nil }
  }
}
