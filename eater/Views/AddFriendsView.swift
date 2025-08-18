import SwiftUI

struct AddFriendsView: View {
    @Binding var isPresented: Bool

    @State private var query: String = ""
    @State private var suggestions: [String] = []
    @State private var statusText: String = "Type at least 3 letters to search"
    @State private var isConnected: Bool = false
    @State private var isAuthenticated: Bool = false
    @State private var isSearching: Bool = false
    @State private var isAddingFriend: Bool = false

    @State private var socket: FriendsSearchWebSocket? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                TextField("Search by email...", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .onChange(of: query) { _, newValue in
                        handleQueryChange(newValue)
                    }

                if isSearching {
                    ProgressView()
                }

                if !suggestions.isEmpty {
                    List {
                        ForEach(suggestions, id: \.self) { email in
                            Button(action: { select(email: email) }) {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                    Text(email)
                                }
                            }
                            .disabled(isAddingFriend)
                        }
                    }
                    .listStyle(.plain)
                } else {
                    Text(statusText)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
            .disabled(isAddingFriend)
            .overlay(
                Group {
                    if isAddingFriend {
                        ZStack {
                            Color.black.opacity(0.3).ignoresSafeArea()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Adding friend...")
                                    .foregroundColor(.white)
                            }
                            .padding(20)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(12)
                        }
                    }
                }
            )
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { isPresented = false }
                        .disabled(isAddingFriend)
                }
            }
            .onAppear { setupSocket() }
            .onDisappear { teardownSocket() }
        }
    }

    private func setupSocket() {
        let socket = FriendsSearchWebSocket(tokenProvider: { UserDefaults.standard.string(forKey: "auth_token") })
        self.socket = socket
        socket.onStateChange = { state in
            switch state {
            case .connecting:
                isConnected = false
                statusText = "Connecting..."
            case .connected:
                isConnected = true
                statusText = "Connected. Authenticating..."
            case .authenticated:
                isAuthenticated = true
                statusText = suggestions.isEmpty ? "Type at least 3 letters to search" : statusText
            case .failed(let message):
                isConnected = false
                isAuthenticated = false
                statusText = message
            case .disconnected:
                isConnected = false
                isAuthenticated = false
                statusText = suggestions.isEmpty ? "Disconnected" : statusText
            }
        }
        socket.onResults = { emails in
            isSearching = false
            suggestions = emails
            if emails.isEmpty {
                statusText = "No emails found"
            }
        }
    }

    private func teardownSocket() {
        socket?.disconnect()
        suggestions = []
        statusText = "Type at least 3 letters to search"
        isSearching = false
        isConnected = false
        isAuthenticated = false
        self.socket = nil
    }

    private func handleQueryChange(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 {
            suggestions = []
            statusText = "Type at least 3 letters to search"
            return
        }
        isSearching = true
        // Debounce basic: dispatch after small delay and send latest
        let current = trimmed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if current == self.query.trimmingCharacters(in: .whitespacesAndNewlines) {
                socket?.search(query: current, limit: 10)
            }
        }
    }

    private func select(email: String) {
        isAddingFriend = true
        GRPCService().addFriend(email: email) { success in
            DispatchQueue.main.async {
                isAddingFriend = false
                if success {
                    AlertHelper.showAlert(title: "You have a new friend!", message: "\(email) added to your friends list")
                } else {
                    AlertHelper.showAlert(title: "Failed", message: "Could not send a friend request to \(email)")
                }
                isPresented = false
            }
        }
    }
}

#Preview {
    AddFriendsView(isPresented: .constant(true))
        .environmentObject({
            let authService = AuthenticationService()
            authService.setPreviewState(
                email: "preview@example.com",
                profilePictureURL: "https://lh3.googleusercontent.com/a/default-user=s120-c"
            )
            return authService
        }())
}


