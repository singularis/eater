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

  /// Localized label shown instead of Guest / anon_* emails.
  static var trialUsageLabel: String {
    loc("profile.trial_usage", "Trial usage")
  }

  static func excludingAnonymous(
    _ friends: [(email: String, nickname: String)]
  ) -> [(email: String, nickname: String)] {
    friends.filter { !isAnonymous(email: $0.email, nickname: $0.nickname) }
  }

  static func excludingAnonymous(_ users: [UserSearchResult]) -> [UserSearchResult] {
    users.filter { !isAnonymous(email: $0.email, nickname: $0.nickname) }
  }
}
