import SwiftUI

struct AddFriendsView: View {
  @Binding var isPresented: Bool

  @State private var query: String = ""
  @State private var suggestions: [UserSearchResult] = []
  @State private var statusText: String = loc("search.type3", "Type at least 3 letters to search")
  @State private var isConnected: Bool = false
  @State private var isAuthenticated: Bool = false
  @State private var isSearching: Bool = false
  @State private var isAddingFriend: Bool = false

  @State private var socket: FriendsSearchWebSocket? = nil

  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)
        VStack(spacing: 12) {
        TextField(loc("friends.search.placeholder", "Search by email or nickname..."), text: $query)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled(true)
          .padding(12)
          .background(AppTheme.surface)
          .cornerRadius(AppTheme.smallRadius)
          .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
          }

        if isSearching {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.textPrimary))
        }

        if !suggestions.isEmpty {
          List {
            ForEach(suggestions, id: \.email) { user in
              VStack(spacing: 6) {
                HStack {
                  Image(systemName: "person.crop.circle.badge.plus")
                    .foregroundColor(AppTheme.accent)
                  
                  VStack(alignment: .leading, spacing: 2) {
                    // Display nickname if available, otherwise email
                    if let nickname = user.nickname, !nickname.isEmpty {
                      Text(nickname)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                      
                      // Show email as secondary info if not Apple hidden email
                      if !isAppleHiddenEmail(user.email) {
                        Text(user.email)
                          .font(.system(size: 13))
                          .foregroundColor(AppTheme.textSecondary)
                      }
                    } else {
                      // No nickname, show email as primary
                      Text(user.email)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    }
                  }
                  
                  Spacer()
                }
                .padding(12)
                .cardContainer(padding: 0)

                Rectangle()
                  .fill(AppTheme.divider)
                  .frame(height: 0.5)
                  .opacity(0.8)
                  .padding(.horizontal, 16)
              }
              .contentShape(Rectangle())
              .onTapGesture {
                HapticsService.shared.lightImpact()
                select(user: user)
              }
              .disabled(isAddingFriend)
              .listRowSeparator(.hidden)
              .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
            }
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
          .listRowBackground(Color.clear)
          .background(Color.clear)
        } else {
          EmptyStateView(
            systemImage: "person.2.fill",
            title: statusText,
            subtitle: nil
          )
          .frame(maxWidth: .infinity)
          .padding(.top, 8)
        }

        Spacer()
        }
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
                Text(loc("overlay.adding_friend", "Adding friend..."))
                  .foregroundColor(AppTheme.textPrimary)
              }
              .padding(20)
              .background(AppTheme.surface)
              .cornerRadius(AppTheme.smallRadius)
            }
          }
        }
      )
      .navigationTitle(loc("nav.addfriends", "Add Friends"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(loc("common.close", "Close")) {
            HapticsService.shared.select()
            isPresented = false
          }
            .foregroundColor(AppTheme.textPrimary)
            .disabled(isAddingFriend)
        }
      }
      .onAppear { setupSocket() }
      .onDisappear { teardownSocket() }
    }
  }
  
  private func isAppleHiddenEmail(_ email: String) -> Bool {
    return email.contains("@privaterelay.appleid.com")
  }

  private func setupSocket() {
    let socket = FriendsSearchWebSocket(tokenProvider: {
      UserDefaults.standard.string(forKey: "auth_token")
    })
    self.socket = socket
    socket.onStateChange = { state in
      switch state {
      case .connecting:
        isConnected = false
        statusText = loc("search.connecting", "Connecting...")
      case .connected:
        isConnected = true
        statusText = loc("search.connected_authenticating", "Connected. Authenticating...")
      case .authenticated:
        isAuthenticated = true
        statusText =
          suggestions.isEmpty
          ? loc("search.type3", "Type at least 3 letters to search") : statusText
      case let .failed(message):
        isConnected = false
        isAuthenticated = false
        statusText = message
      case .disconnected:
        isConnected = false
        isAuthenticated = false
        statusText = suggestions.isEmpty ? loc("search.disconnected", "Disconnected") : statusText
      }
    }
    socket.onResults = { users in
      isSearching = false
      suggestions = users
      if users.isEmpty {
        statusText = loc("search.no_results", "No results found")
      }
    }
  }

  private func teardownSocket() {
    socket?.disconnect()
    suggestions = []
    statusText = loc("search.type3", "Type at least 3 letters to search")
    isSearching = false
    isConnected = false
    isAuthenticated = false
    socket = nil
  }

  private func handleQueryChange(_ newValue: String) {
    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count < 3 {
      suggestions = []
      statusText = loc("search.type3", "Type at least 3 letters to search")
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

  private func select(user: UserSearchResult) {
    isAddingFriend = true
    GRPCService().addFriend(email: user.email) { success in
      DispatchQueue.main.async {
        isAddingFriend = false
        
        // Display name for feedback: nickname if available, otherwise email
        let displayName = (user.nickname != nil && !user.nickname!.isEmpty) ? user.nickname! : user.email
        
        if success {
          AlertHelper.showAlert(
            title: loc("friends.add.success.title", "You have a new friend!"),
            message: String(
              format: loc("friends.add.success.msg", "%@ added to your friends list"), displayName))
        } else {
          AlertHelper.showAlert(
            title: loc("friends.add.fail.title", "Failed"),
            message: String(
              format: loc("friends.add.fail.msg", "Could not send a friend request to %@"), displayName))
        }
        isPresented = false
      }
    }
  }
}
