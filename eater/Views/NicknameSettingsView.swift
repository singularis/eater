import PhotosUI
import SwiftUI

struct NicknameSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var authService: AuthenticationService

  @State private var nickname: String = ""
  @State private var firstName: String = ""
  @State private var lastName: String = ""
  @State private var isLoading: Bool = false
  @State private var isUploadingPhoto: Bool = false
  @State private var errorMessage: String = ""
  @State private var showAlert: Bool = false
  @State private var alertMessage: String = ""
  @State private var alertTitle: String = ""
  @State private var selectedPhotoItem: PhotosPickerItem? = nil
  @State private var localPhoto: UIImage? = nil
  @State private var remotePhoto: UIImage? = nil

  @AppStorage("user_email") private var userEmail: String = ""
  @AppStorage("user_nickname") private var savedNickname: String = ""
  @AppStorage("user_first_name") private var savedFirstName: String = ""
  @AppStorage("user_last_name") private var savedLastName: String = ""
  @AppStorage("user_profile_picture_id") private var savedProfilePictureId: String = ""

  private var displayPhotoURL: String? {
    if localPhoto != nil || remotePhoto != nil || !savedProfilePictureId.isEmpty {
      return nil  // custom image handled separately
    }
    return authService.userProfilePictureURL
  }

  private var composedDisplayName: String {
    let parts = [firstName, lastName]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    return parts.joined(separator: " ")
  }

  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient
          .edgesIgnoringSafeArea(.all)

        ScrollView {
          VStack(spacing: 24) {
            photoSection
              .padding(.top, 20)

            VStack(spacing: 8) {
              Text(loc("profile.edit_title", "Edit Profile"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

              Text(
                loc(
                  "profile.edit_description",
                  "Add a photo and your name if you want. Nickname is still used for friends."
                )
              )
              .font(.system(size: 16))
              .foregroundColor(AppTheme.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 16) {
              profileTextField(
                label: loc("profile.first_name", "First name (optional)"),
                placeholder: loc("profile.first_name_placeholder", "First name"),
                text: $firstName,
                capitalizeWords: true
              )

              profileTextField(
                label: loc("profile.last_name", "Last name (optional)"),
                placeholder: loc("profile.last_name_placeholder", "Last name"),
                text: $lastName,
                capitalizeWords: true
              )

              VStack(alignment: .leading, spacing: 8) {
                Text(loc("nickname.label", "Nickname (optional, a-z 0-9)"))
                  .font(.system(size: 14, weight: .medium))
                  .foregroundColor(AppTheme.textSecondary)

                TextField(loc("nickname.placeholder", "Enter your nickname"), text: $nickname)
                  .textFieldStyle(.plain)
                  .padding(16)
                  .background(AppTheme.surface)
                  .cornerRadius(AppTheme.cornerRadius)
                  .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                      .stroke(errorMessage.isEmpty ? AppTheme.divider : AppTheme.danger, lineWidth: 1)
                  )
                  .autocapitalization(.none)
                  .disableAutocorrection(true)
                  .disabled(isLoading)
                  .onChange(of: nickname) { errorMessage = "" }

                if !errorMessage.isEmpty {
                  Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.danger)
                    .padding(.leading, 4)
                }

                Text("\(nickname.count)/50")
                  .font(.system(size: 12))
                  .foregroundColor(nickname.count > 50 ? AppTheme.danger : AppTheme.textSecondary)
                  .frame(maxWidth: .infinity, alignment: .trailing)
              }
            }
            .cardContainer(padding: 16)
            .padding(.horizontal, 20)

            if isAppleHiddenEmail(userEmail) {
              HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .font(.system(size: 20))
                  .foregroundColor(AppTheme.warning)

                VStack(alignment: .leading, spacing: 4) {
                  Text(loc("nickname.apple_warning", "Apple ID Detected"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                  Text(
                    loc(
                      "nickname.apple_warning_desc",
                      "Since you're using Sign in with Apple, setting a nickname will help friends identify you."
                    )
                  )
                  .font(.system(size: 12))
                  .foregroundColor(AppTheme.textSecondary)
                }
              }
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(AppTheme.warning.opacity(0.1))
              .cornerRadius(AppTheme.smallRadius)
              .overlay(
                RoundedRectangle(cornerRadius: AppTheme.smallRadius)
                  .stroke(AppTheme.warning.opacity(0.3), lineWidth: 1)
              )
              .padding(.horizontal, 20)
            }

            Button(action: saveProfile) {
              if isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .frame(maxWidth: .infinity)
              } else {
                Text(loc("profile.save", "Save Profile"))
                  .frame(maxWidth: .infinity)
              }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading || isUploadingPhoto || !canSave)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarItems(
        leading: Button(action: {
          persistProfileLocally(
            nick: nickname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            first: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            last: lastName.trimmingCharacters(in: .whitespacesAndNewlines)
          )
          dismiss()
        }) {
          Image(systemName: "xmark")
            .foregroundColor(AppTheme.textPrimary)
        }
      )
      .onAppear(perform: loadInitialState)
      .onChange(of: selectedPhotoItem) { _, newItem in
        guard let newItem else { return }
        Task { await handlePickedPhoto(newItem) }
      }
      .alert(alertTitle, isPresented: $showAlert) {
        Button(loc("common.ok", "OK")) {}
      } message: {
        Text(alertMessage)
      }
    }
  }

  private var canSave: Bool {
    let nick = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    return nick.count <= 50
  }

  @ViewBuilder
  private var photoSection: some View {
    VStack(spacing: 12) {
      ZStack(alignment: .bottomTrailing) {
        Group {
          if let localPhoto {
            Image(uiImage: localPhoto)
              .resizable()
              .aspectRatio(contentMode: .fill)
          } else if let remotePhoto {
            Image(uiImage: remotePhoto)
              .resizable()
              .aspectRatio(contentMode: .fill)
          } else if let stored = ProfilePhotoStore.shared.image {
            Image(uiImage: stored)
              .resizable()
              .aspectRatio(contentMode: .fill)
          } else {
            ProfileImageView(
              profilePictureURL: displayPhotoURL,
              size: 110,
              userName: composedDisplayName.isEmpty ? authService.userName : composedDisplayName,
              userEmail: userEmail
            )
          }
        }
        .frame(width: 110, height: 110)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppTheme.divider, lineWidth: 1))

        if isUploadingPhoto {
          Circle()
            .fill(Color.black.opacity(0.45))
            .frame(width: 110, height: 110)
            .overlay(ProgressView().tint(.white))
        }

        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
          Image(systemName: "camera.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(10)
            .background(AppTheme.accent)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.surface, lineWidth: 2))
        }
        .disabled(isUploadingPhoto || isLoading)
      }

      Text(loc("profile.photo_hint", "Tap the camera to upload a photo"))
        .font(.caption)
        .foregroundColor(AppTheme.textSecondary)
    }
  }

  private func profileTextField(
    label: String,
    placeholder: String,
    text: Binding<String>,
    capitalizeWords: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(AppTheme.textSecondary)

      TextField(placeholder, text: text)
        .textFieldStyle(.plain)
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.cornerRadius)
        .overlay(
          RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            .stroke(AppTheme.divider, lineWidth: 1)
        )
        .autocapitalization(capitalizeWords ? .words : .none)
        .disableAutocorrection(true)
        .disabled(isLoading)
    }
  }

  private func isAppleHiddenEmail(_ email: String) -> Bool {
    return email.contains("@privaterelay.appleid.com")
  }

  /// Only Latin lowercase letters and digits (a-z, 0-9).
  private static func isNicknameValid(_ s: String) -> Bool {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
    return s.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  private func loadInitialState() {
    nickname = savedNickname
    firstName = savedFirstName
    lastName = savedLastName
    if localPhoto == nil {
      localPhoto = ProfilePhotoStore.shared.image
    }

    GRPCService().fetchProfile { profile in
      DispatchQueue.main.async {
        guard let profile else { return }
        if let nick = profile.nickname, !nick.isEmpty {
          savedNickname = nick
          nickname = nick
        }
        if let first = profile.firstName, !first.isEmpty {
          savedFirstName = first
          firstName = first
        }
        if let last = profile.lastName, !last.isEmpty {
          savedLastName = last
          lastName = last
        }
        if let pictureId = profile.profilePictureId, !pictureId.isEmpty {
          savedProfilePictureId = pictureId
          fetchRemoteProfilePhoto(imageId: pictureId)
        }
      }
    }

    if !savedProfilePictureId.isEmpty {
      fetchRemoteProfilePhoto(imageId: savedProfilePictureId)
    }
  }

  private func fetchRemoteProfilePhoto(imageId: String) {
    FoodPhotoService.shared.fetchPhoto(imageId: imageId) { image in
      DispatchQueue.main.async {
        guard let image else { return }
        if localPhoto == nil {
          remotePhoto = image
        }
        ProfilePhotoStore.shared.setFromServer(image, imageId: imageId)
      }
    }
  }

  private func handlePickedPhoto(_ item: PhotosPickerItem) async {
    await MainActor.run { isUploadingPhoto = true }
    do {
      guard let data = try await item.loadTransferable(type: Data.self),
        let image = UIImage(data: data)
      else {
        await MainActor.run {
          isUploadingPhoto = false
          errorMessage = loc("profile.photo_error", "Could not read the selected photo")
        }
        return
      }

      let upright = image.normalizedUp()
      await MainActor.run {
        localPhoto = upright
        ProfilePhotoStore.shared.setLocal(upright)
      }

      GRPCService().uploadProfilePhoto(image: upright) { success, pictureId, errorMsg in
        DispatchQueue.main.async {
          isUploadingPhoto = false
          if success, let pictureId, !pictureId.isEmpty {
            savedProfilePictureId = pictureId
            remotePhoto = image
            ProfilePhotoStore.shared.setFromServer(image, imageId: pictureId)
            HapticsService.shared.success()
          } else {
            HapticsService.shared.error()
            errorMessage =
              errorMsg ?? loc("profile.photo_error", "Could not upload profile photo")
          }
        }
      }
    } catch {
      await MainActor.run {
        isUploadingPhoto = false
        errorMessage = loc("profile.photo_error", "Could not upload profile photo")
      }
    }
  }

  private func saveProfile() {
    let trimmedNick = nickname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

    if !trimmedNick.isEmpty {
      guard trimmedNick.count <= 50 else {
        errorMessage = loc("nickname.length_error", "Nickname must be 50 characters or less")
        return
      }
      guard Self.isNicknameValid(trimmedNick) else {
        errorMessage = loc(
          "nickname.latin_lowercase_error",
          "Only Latin lowercase letters and digits (a-z, 0-9)"
        )
        return
      }
    }

    let previousNick = savedNickname
    let nickChanged = trimmedNick != savedNickname
    let namesChanged = trimmedFirst != savedFirstName || trimmedLast != savedLastName
    let photoId = savedProfilePictureId.trimmingCharacters(in: .whitespacesAndNewlines)
    let shouldPersistProfile = namesChanged || !photoId.isEmpty

    // Local first — same as photo. App exit must not lose what the user typed.
    persistProfileLocally(nick: trimmedNick, first: trimmedFirst, last: trimmedLast)

    errorMessage = ""
    isLoading = true
    HapticsService.shared.select()

    // Empty name/nickname is allowed. Skip API only when there is nothing to persist.
    if !nickChanged && !shouldPersistProfile {
      finishProfileSaveSuccess()
      return
    }

    let group = DispatchGroup()
    var nicknameFailedMessage: String? = nil
    var profileFailedMessage: String? = nil

    if nickChanged {
      group.enter()
      GRPCService().updateNickname(nickname: trimmedNick) { success, errorMsg in
        if !success {
          nicknameFailedMessage = errorMsg
        }
        group.leave()
      }
    }

    if shouldPersistProfile {
      group.enter()
      GRPCService().updateProfile(
        firstName: trimmedFirst,
        lastName: trimmedLast,
        profilePictureId: photoId.isEmpty ? nil : photoId
      ) { success, errorMsg in
        if !success {
          profileFailedMessage = errorMsg
        }
        group.leave()
      }
    }

    group.notify(queue: .main) {
      isLoading = false
      if let nickError = nicknameFailedMessage, !nickError.isEmpty {
        let raw = nickError.lowercased()
        HapticsService.shared.error()
        if raw.contains("already taken") || raw.contains("taken") {
          persistProfileLocally(nick: previousNick, first: trimmedFirst, last: trimmedLast)
          nickname = trimmedNick
          errorMessage = loc("nickname.taken_error", "This nickname is already taken")
        } else if raw.contains("latin") || raw.contains("lowercase") {
          errorMessage = loc(
            "nickname.latin_lowercase_error",
            "Only Latin lowercase letters and digits (a-z, 0-9)"
          )
        } else if isAuthNoise(raw) {
          finishProfileSaveSuccess()
        } else {
          errorMessage = nickError
        }
        return
      }

      if let profileError = profileFailedMessage, !profileError.isEmpty {
        let raw = profileError.lowercased()
        if isAuthNoise(raw) {
          finishProfileSaveSuccess()
          return
        }
        HapticsService.shared.error()
        errorMessage = profileError
        return
      }

      finishProfileSaveSuccess()
    }
  }

  private func isAuthNoise(_ raw: String) -> Bool {
    raw.contains("invalid token")
      || raw.contains("token is missing")
      || raw.contains("expired")
      || raw.contains("status code 401")
  }

  private func persistProfileLocally(nick: String, first: String, last: String) {
    savedNickname = nick
    nickname = nick
    savedFirstName = first
    savedLastName = last
    firstName = first
    lastName = last
    let display = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
    if !display.isEmpty {
      authService.userName = display
      UserDefaults.standard.set(display, forKey: "user_name")
    }
    UserDefaults.standard.synchronize()
    let email = userEmail.isEmpty ? (authService.userEmail ?? "") : userEmail
    if !email.isEmpty {
      ProfileLocalStore.shared.save(
        LocalProfile(
          nickname: nick,
          firstName: first,
          lastName: last,
          pictureId: savedProfilePictureId
        ),
        email: email
      )
    }
  }

  private func finishProfileSaveSuccess() {
    isLoading = false
    HapticsService.shared.success()
    alertTitle = loc("success.title", "Success")
    alertMessage = loc("profile.save_success", "Your profile has been updated.")
    showAlert = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
      dismiss()
    }
  }
}
