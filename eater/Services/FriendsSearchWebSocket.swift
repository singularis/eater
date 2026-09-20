import Foundation

struct UserSearchResult {
  let email: String
  let nickname: String?
}

final class FriendsSearchWebSocket: NSObject {
  enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case authenticated
    case failed(String)
  }

  private var session: URLSession?
  private var webSocketTask: URLSessionWebSocketTask?
  private var isListening = false
  private var isAuthSent = false
  private var isAuthenticated = false
  private var pendingSearch: (query: String, limit: Int)?
  private var lastFailureMessage: String?
  /// Bumped on every connect/teardown so callbacks from a dead socket are ignored.
  private var generation = 0

  private let tokenProvider: () -> String?

  var onStateChange: ((ConnectionState) -> Void)?
  var onResults: (([UserSearchResult]) -> Void)?

  init(tokenProvider: @escaping () -> String?) {
    self.tokenProvider = tokenProvider
    super.init()
  }

  func connectIfNeeded() {
    if webSocketTask != nil { return }
    connect()
  }

  func connect() {
    teardown(notifyDisconnected: false)
    lastFailureMessage = nil
    emit(.connecting)
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 30
    let session = URLSession(configuration: config)
    self.session = session
    let task = session.webSocketTask(with: AppEnvironment.webSocketURL)
    webSocketTask = task
    task.resume()
    emit(.connected)
    listen()
    sendAuthIfNeeded()
  }

  func search(query: String, limit: Int = 10) {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    connectIfNeeded()
    sendAuthIfNeeded()
    guard isAuthenticated else {
      pendingSearch = (query, limit)
      return
    }
    sendSearch(query: query, limit: limit)
  }

  func disconnect() {
    teardown(notifyDisconnected: true)
  }

  private func teardown(notifyDisconnected: Bool) {
    generation += 1
    isListening = false
    isAuthSent = false
    isAuthenticated = false
    pendingSearch = nil
    if let task = webSocketTask {
      task.cancel(with: .goingAway, reason: nil)
    }
    webSocketTask = nil
    session?.invalidateAndCancel()
    session = nil
    if notifyDisconnected {
      if let lastFailureMessage, !lastFailureMessage.isEmpty {
        emit(.failed(lastFailureMessage))
      } else {
        emit(.disconnected)
      }
    }
  }

  private func fail(_ message: String) {
    lastFailureMessage = message
    emit(.failed(message))
    teardown(notifyDisconnected: false)
  }

  /// SwiftUI state lives behind these callbacks, and URLSession delivers on its
  /// own queue.
  private func emit(_ state: ConnectionState) {
    DispatchQueue.main.async { [weak self] in
      self?.onStateChange?(state)
    }
  }

  /// Closing the sheet cancels in-flight sends and receives. Those errors describe
  /// our own teardown, not a search problem.
  private func isTeardownError(_ error: Error) -> Bool {
    let nsError = error as NSError
    guard nsError.domain == NSURLErrorDomain || nsError.domain == NSPOSIXErrorDomain else {
      return false
    }
    return [
      NSURLErrorCancelled,
      NSURLErrorNetworkConnectionLost,
      Int(ENOTCONN),
    ].contains(nsError.code)
  }

  private func sendAuthIfNeeded() {
    guard !isAuthSent else { return }
    isAuthSent = true
    guard var token = tokenProvider(), !token.isEmpty else {
      fail("Missing auth token")
      return
    }
    if token.lowercased().hasPrefix("bearer ") {
      token = String(token.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    }
    let payload: [String: Any] = [
      "type": "auth",
      "token": token,
    ]
    send(json: payload)
  }

  private func sendSearch(query: String, limit: Int) {
    let payload: [String: Any] = [
      "type": "search",
      "query": query,
      "limit": limit,
    ]
    send(json: payload)
  }

  private func send(json: [String: Any]) {
    guard let task = webSocketTask else { return }
    let sentGeneration = generation
    do {
      let data = try JSONSerialization.data(withJSONObject: json, options: [])
      guard let text = String(data: data, encoding: .utf8) else {
        fail("Failed to encode JSON")
        return
      }
      task.send(.string(text)) { [weak self] error in
        guard let error = error else { return }
        DispatchQueue.main.async {
          guard let self = self, self.generation == sentGeneration else { return }
          guard !self.isTeardownError(error) else { return }
          self.fail(error.localizedDescription)
        }
      }
    } catch {
      fail("Failed to encode JSON")
    }
  }

  private func listen() {
    guard let task = webSocketTask else { return }
    isListening = true
    let listenGeneration = generation
    task.receive { [weak self] result in
      DispatchQueue.main.async {
        guard let self = self, self.generation == listenGeneration else { return }
        switch result {
        case let .failure(error):
          guard !self.isTeardownError(error) else { return }
          self.fail(error.localizedDescription)
        case let .success(message):
          self.handle(message: message)
          if self.isListening, self.generation == listenGeneration {
            self.listen()
          }
        }
      }
    }
  }

  private func handle(message: URLSessionWebSocketTask.Message) {
    let data: Data?
    switch message {
    case let .data(d):
      data = d
    case let .string(s):
      data = s.data(using: .utf8)
    @unknown default:
      data = nil
    }
    guard let data = data else { return }
    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      #if DEBUG
      print("friend search: unexpected frame \(String(data: data, encoding: .utf8) ?? "<binary>")")
      #endif
      return
    }

    if let error = obj["error"] as? String {
      #if DEBUG
      print("friend search server error: \(error) | frame: \(obj)")
      #endif
      fail(error)
      return
    }

    guard let type = obj["type"] as? String else { return }

    if type == "error" {
      #if DEBUG
      print("friend search server error frame: \(obj)")
      #endif
      fail((obj["message"] as? String) ?? "Search failed")
      return
    }

    if type == "connection" {
      if let status = obj["status"] as? String, status == "connected" {
        isAuthenticated = true
        emit(.authenticated)
        if let pending = pendingSearch {
          pendingSearch = nil
          sendSearch(query: pending.query, limit: pending.limit)
        }
      }
      return
    }

    if type == "results" {
      if let results = obj["results"] as? [[String: Any]] {
        let userResults = results.compactMap { dict -> UserSearchResult? in
          guard let email = dict["email"] as? String else { return nil }
          let nickname = dict["nickname"] as? String
          return UserSearchResult(email: email, nickname: nickname)
        }
        let visible = AnonymousUserIdentity.addFriendVisible(userResults)
        DispatchQueue.main.async { [weak self] in self?.onResults?(visible) }
      } else {
        DispatchQueue.main.async { [weak self] in self?.onResults?([]) }
      }
      return
    }
  }
}
