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
    onStateChange?(.connecting)
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 30
    let session = URLSession(configuration: config)
    self.session = session
    let task = session.webSocketTask(with: AppEnvironment.webSocketURL)
    webSocketTask = task
    task.resume()
    onStateChange?(.connected)
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
        onStateChange?(.failed(lastFailureMessage))
      } else {
        onStateChange?(.disconnected)
      }
    }
  }

  private func fail(_ message: String) {
    lastFailureMessage = message
    onStateChange?(.failed(message))
    teardown(notifyDisconnected: false)
  }

  private func sendAuthIfNeeded() {
    guard !isAuthSent else { return }
    isAuthSent = true
    guard let token = tokenProvider() else {
      fail("Missing auth token")
      return
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
    do {
      let data = try JSONSerialization.data(withJSONObject: json, options: [])
      if let text = String(data: data, encoding: .utf8) {
        task.send(.string(text)) { [weak self] error in
          if let error = error {
            self?.fail(error.localizedDescription)
          }
        }
      }
    } catch {
      fail("Failed to encode JSON")
    }
  }

  private func listen() {
    guard let task = webSocketTask else { return }
    isListening = true
    task.receive { [weak self] result in
      guard let self = self else { return }
      switch result {
      case let .failure(error):
        self.fail(error.localizedDescription)
      case let .success(message):
        self.handle(message: message)
        if self.isListening {
          self.listen()
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
    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

    if let error = obj["error"] as? String {
      fail(error)
      return
    }

    guard let type = obj["type"] as? String else { return }

    if type == "error" {
      fail((obj["message"] as? String) ?? "Search failed")
      return
    }

    if type == "connection" {
      if let status = obj["status"] as? String, status == "connected" {
        isAuthenticated = true
        onStateChange?(.authenticated)
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
        onResults?(AnonymousUserIdentity.addFriendVisible(userResults))
      } else {
        onResults?([])
      }
      return
    }
  }
}
