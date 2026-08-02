import Foundation

/// Detects guest / "Let Me Try" accounts so they are never shown as real identities
/// or offered as friends (they have no nickname).
enum AnonymousUserIdentity {
  /// Matches emails created by anonymous auth, e.g. `anon_<uuid>@anonymous.local`.
  private static let emailRegex: NSRegularExpression = {
    try! NSRegularExpression(
      pattern: #"(?i)^anon_[0-9a-f\-]+@anonymous\.local$"#,
      options: []
    )
  }()

  /// Soft placeholder labels the backend or older clients may still emit.
  private static let anonymousNameRegex: NSRegularExpression = {
    try! NSRegularExpression(
      pattern: #"(?i)^(guest|anonymous([\s._-].*)?|anon([\s._-].*)?)$"#,
      options: []
    )
  }()

  static func isAnonymousEmail(_ email: String?) -> Bool {
    guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty
    else { return false }
    let range = NSRange(email.startIndex..<email.endIndex, in: email)
    if emailRegex.firstMatch(in: email, options: [], range: range) != nil {
      return true
    }
    // Broader safety net for any account on the anonymous local domain.
    return email.lowercased().hasSuffix("@anonymous.local")
  }

  static func isAnonymousDisplayName(_ name: String?) -> Bool {
    guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
    else { return false }
    let range = NSRange(name.startIndex..<name.endIndex, in: name)
    return anonymousNameRegex.firstMatch(in: name, options: [], range: range) != nil
  }

  static func isAnonymous(email: String?, nickname: String? = nil, name: String? = nil) -> Bool {
    if isAnonymousEmail(email) { return true }
    if isAnonymousDisplayName(name) { return true }
    if isAnonymousDisplayName(nickname) { return true }
    return false
  }

  /// Apple Hide My Email — not useful in friend lists unless a nickname is set.
  static func isPrivateRelayEmail(_ email: String?) -> Bool {
    guard let email = email?.lowercased() else { return false }
    return email.contains("@privaterelay.appleid.com")
  }

  static func hasUsableNickname(_ nickname: String?) -> Bool {
    guard let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
      !nickname.isEmpty
    else { return false }
    return !isAnonymousDisplayName(nickname)
  }

  /// Localized label shown instead of Guest / anon_* emails.
  static var trialUsageLabel: String {
    loc("profile.trial_usage", "Trial usage")
  }

  /// Friendly menu/profile title when the user has not set a real name or nickname.
  static var defaultDisplayName: String {
    loc("profile.default_display_name", "Health Eater")
  }

  static func isUsablePersonName(_ name: String?) -> Bool {
    guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
    else { return false }
    if isAnonymousDisplayName(name) { return false }
    if isAnonymousEmail(name) { return false }
    if isPrivateRelayEmail(name) { return false }
    // Avoid showing raw email local-parts / UUID-like anon tokens as a "name".
    if name.contains("@") { return false }
    if name.lowercased().hasPrefix("anon_") { return false }
    return true
  }

  /// Name shown in profile/menu: nickname → real name → "Health Eater".
  static func menuDisplayName(nickname: String?, userName: String?) -> String {
    if hasUsableNickname(nickname) {
      return nickname!.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if isUsablePersonName(userName) {
      return userName!.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return defaultDisplayName
  }

  /// Secondary line under the name — hide private relay / anonymous emails.
  static func menuEmailSubtitle(email: String?) -> String? {
    guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty
    else { return nil }
    if isAnonymousEmail(email) || isPrivateRelayEmail(email) { return nil }
    return email
  }

  /// Whether a person should appear in Add Friend / friend pickers.
  /// Nickname required; anonymous and private-relay-without-nickname stay out.
  static func isAddFriendVisible(email: String?, nickname: String?) -> Bool {
    guard hasUsableNickname(nickname) else { return false }
    return !isAnonymous(email: email, nickname: nickname)
  }

  static func excludingAnonymous(
    _ friends: [(email: String, nickname: String)]
  ) -> [(email: String, nickname: String)] {
    friends.filter { !isAnonymous(email: $0.email, nickname: $0.nickname) }
  }

  static func excludingAnonymous(_ users: [UserSearchResult]) -> [UserSearchResult] {
    users.filter { !isAnonymous(email: $0.email, nickname: $0.nickname) }
  }

  static func addFriendVisible(
    _ friends: [(email: String, nickname: String)]
  ) -> [(email: String, nickname: String)] {
    friends.filter { isAddFriendVisible(email: $0.email, nickname: $0.nickname) }
  }

  static func addFriendVisible(_ users: [UserSearchResult]) -> [UserSearchResult] {
    users.filter { isAddFriendVisible(email: $0.email, nickname: $0.nickname) }
  }
}
