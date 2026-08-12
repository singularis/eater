import Combine
import UIKit

/// Custom profile photo. Files live under Documents/EateriaProfile/<email>/avatar.jpg
/// so ForceLogout / app kill cannot wipe the last saved avatar.
final class ProfilePhotoStore: ObservableObject {
  static let shared = ProfilePhotoStore()

  @Published private(set) var image: UIImage?

  private init() {
    if let email = UserDefaults.standard.string(forKey: "user_email") {
      loadFromDisk(email: email)
    }
  }

  func loadFromDisk(email: String) {
    if let photo = ProfileLocalStore.shared.loadAvatar(email: email) {
      image = photo
      return
    }
    // Migrate the old single-file avatar once.
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let legacy = docs.appendingPathComponent("user_profile_avatar.jpg")
    if let data = try? Data(contentsOf: legacy), let photo = UIImage(data: data) {
      image = photo
      ProfileLocalStore.shared.saveAvatar(photo, email: email)
      try? FileManager.default.removeItem(at: legacy)
    }
  }

  func setLocal(_ photo: UIImage) {
    let upright = photo.normalizedUp()
    image = upright
    if let email = UserDefaults.standard.string(forKey: "user_email"), !email.isEmpty {
      ProfileLocalStore.shared.saveAvatar(upright, email: email)
    }
  }

  func setFromServer(_ photo: UIImage, imageId: String?) {
    setLocal(photo)
    if let imageId, !imageId.isEmpty {
      UserDefaults.standard.set(imageId, forKey: "user_profile_picture_id")
      _ = ImageStorageService.shared.saveCachedImage(photo, forImageId: imageId)
      if let email = UserDefaults.standard.string(forKey: "user_email") {
        var profile = ProfileLocalStore.shared.load(email: email)
        profile.pictureId = imageId
        ProfileLocalStore.shared.save(profile, email: email)
      }
    }
  }

  func clear() {
    image = nil
  }
}
