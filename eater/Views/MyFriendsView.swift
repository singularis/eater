import SwiftUI

struct MyFriendsView: View {
  @Binding var isPresented: Bool
  @State private var friends: [(email: String, nickname: String)] = []
  @State private var isLoading = false
  @State private var totalCount = 0
  @State private var showAddFriends = false

  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()

        if isLoading && friends.isEmpty {
          ProgressView()
            .scaleEffect(1.5)
        } else if friends.isEmpty {
          VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
              .font(.system(size: 60))
              .foregroundColor(AppTheme.textSecondary)

            Text(loc("friends.list.empty", "No friends yet"))
              .font(.title3)
              .foregroundColor(AppTheme.textPrimary)

            Text(loc("friends.list.empty_hint", "Add friends to share meals and play chess together"))
              .font(.caption)
              .foregroundColor(AppTheme.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 40)

            Button(action: { showAddFriends = true }) {
              Text(loc("friends.add", "Add Friend"))
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.accent)
                .cornerRadius(10)
            }
          }
        } else {
          ScrollView {
            VStack(spacing: 12) {
              ForEach(friends, id: \.email) { friend in
                friendRow(friend)
              }

              if friends.count < totalCount {
                Button(action: loadMore) {
                  HStack {
                    Text(loc("friends.more", "Load more"))
                    if isLoading {
                      ProgressView().scaleEffect(0.8)
                    }
                  }
                  .font(.headline)
                  .foregroundColor(AppTheme.accent)
                  .padding()
                }
              }
            }
            .padding()
          }
        }
      }
      .navigationTitle(loc("friends.list.title", "My friends"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: { showAddFriends = true }) {
            Image(systemName: "person.badge.plus")
              .foregroundColor(AppTheme.textPrimary)
          }
          .accessibilityLabel(loc("friends.add", "Add Friend"))
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(loc("common.done", "Done")) {
            isPresented = false
          }
          .foregroundColor(AppTheme.textPrimary)
        }
      }
      .sheet(isPresented: $showAddFriends) {
        AddFriendsView(isPresented: $showAddFriends)
          .onDisappear { fetchFriends() }
      }
    }
    .onAppear { fetchFriends() }
  }

  private func friendRow(_ friend: (email: String, nickname: String)) -> some View {
    let title = friend.nickname.isEmpty ? friend.email : friend.nickname
    return HStack(spacing: 12) {
      Image(systemName: "person.circle.fill")
        .font(.title)
        .foregroundColor(AppTheme.accent)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
          .foregroundColor(AppTheme.textPrimary)
        if !friend.nickname.isEmpty {
          Text(friend.email)
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
        }
      }

      Spacer()
    }
    .padding()
    .background(AppTheme.surface)
    .cornerRadius(12)
  }

  private func fetchFriends() {
    guard !isLoading else { return }
    isLoading = true
    GRPCService().getFriends(offset: 0, limit: 50) { fetched, total in
      DispatchQueue.main.async {
        isLoading = false
        friends = AnonymousUserIdentity.excludingAnonymous(fetched)
        totalCount = total
      }
    }
  }

  private func loadMore() {
    guard !isLoading else { return }
    isLoading = true
    GRPCService().getFriends(offset: friends.count, limit: 20) { fetched, total in
      DispatchQueue.main.async {
        isLoading = false
        friends.append(contentsOf: AnonymousUserIdentity.excludingAnonymous(fetched))
        totalCount = total
      }
    }
  }
}
