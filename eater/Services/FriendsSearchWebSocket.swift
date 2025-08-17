import Foundation

final class FriendsSearchWebSocket: NSObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case authenticated
        case failed(String)
    }

    private let url = URL(string: "wss://chater.singularis.work/autocomplete")!
    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var isListening = false
    private var isAuthSent = false
    private var isAuthenticated = false

    private let tokenProvider: () -> String?

    var onStateChange: ((ConnectionState) -> Void)?
    var onResults: (([String]) -> Void)?

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
        super.init()
    }

    func connectIfNeeded() {
        if webSocketTask != nil { return }
        connect()
    }

    func connect() {
        disconnect()
        onStateChange?(.connecting)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        let session = URLSession(configuration: config)
        self.session = session
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        onStateChange?(.connected)
        listen()
        sendAuthIfNeeded()
    }

    func search(query: String, limit: Int = 10) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        connectIfNeeded()
        sendAuthIfNeeded()
        let payload: [String: Any] = [
            "type": "search",
            "query": query,
            "limit": limit
        ]
        send(json: payload)
    }

    func disconnect() {
        isListening = false
        isAuthSent = false
        isAuthenticated = false
        if let task = webSocketTask {
            task.cancel(with: .goingAway, reason: nil)
        }
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        onStateChange?(.disconnected)
    }

    private func sendAuthIfNeeded() {
        guard !isAuthSent else { return }
        isAuthSent = true
        guard let token = tokenProvider() else {
            onStateChange?(.failed("Missing auth token"))
            return
        }
        let payload: [String: Any] = [
            "type": "auth",
            "token": token
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
                        self?.onStateChange?(.failed(error.localizedDescription))
                    }
                }
            }
        } catch {
            onStateChange?(.failed("Failed to encode JSON"))
        }
    }

    private func listen() {
        guard let task = webSocketTask else { return }
        isListening = true
        task.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.onStateChange?(.failed(error.localizedDescription))
                self.disconnect()
            case .success(let message):
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
        case .data(let d):
            data = d
        case .string(let s):
            data = s.data(using: .utf8)
        @unknown default:
            data = nil
        }
        guard let data = data else { return }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }

        if type == "connection" {
            if let status = obj["status"] as? String, status == "connected" {
                isAuthenticated = true
                onStateChange?(.authenticated)
            }
            return
        }

        if type == "results" {
            if let results = obj["results"] as? [[String: Any]] {
                let emails = results.compactMap { $0["email"] as? String }
                onResults?(emails)
            } else {
                onResults?([])
            }
            return
        }
    }
}


