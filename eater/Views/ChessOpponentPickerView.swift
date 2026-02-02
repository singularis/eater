import SwiftUI

struct ChessOpponentPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var playerName: String
  @Binding var opponentName: String
  let onOpponentSelected: (String) -> Void
  
  @State private var friends: [(email: String, nickname: String)] = []
  @State private var isLoading = false
  @State private var totalCount = 0
  
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
            
            Text(Localization.shared.tr("activities.chess.no_friends", default: "No friends yet"))
              .font(.title3)
              .foregroundColor(AppTheme.textPrimary)
            
            Text(Localization.shared.tr("activities.chess.add_friends_hint", default: "Add friends to track your chess games together"))
              .font(.caption)
              .foregroundColor(AppTheme.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 40)
          }
        } else {
          ScrollView {
            VStack(spacing: 12) {
              ForEach(friends, id: \.email) { friend in
                friendRow(friend: friend)
              }
              
              if friends.count < totalCount {
                Button(action: loadMore) {
                  HStack {
                    Text(Localization.shared.tr("friends.more", default: "Load more"))
                    if isLoading {
                      ProgressView()
                        .scaleEffect(0.8)
                    }
                  }
                  .font(.headline)
                  .foregroundColor(.purple)
                  .padding()
                }
              }
            }
            .padding()
          }
        }
      }
      .navigationTitle(Localization.shared.tr("activities.chess.select_opponent", default: "Select Opponent"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            dismiss()
          }) {
            Text(Localization.shared.tr("common.cancel", default: "Cancel"))
              .foregroundColor(AppTheme.textPrimary)
          }
        }
      }
    }
    .onAppear {
      fetchFriends()
      
      // Set player name from UserDefaults if not set
      if playerName.isEmpty {
        if let nickname = UserDefaults.standard.string(forKey: "nickname"), !nickname.isEmpty {
          playerName = nickname
        } else if let email = UserDefaults.standard.string(forKey: "currentUserEmail") {
          playerName = email
        }
      }
    }
  }
  
  private func friendRow(friend: (email: String, nickname: String)) -> some View {
    Button(action: {
      selectOpponent(friend: friend)
    }) {
      HStack {
        Image(systemName: "person.circle.fill")
          .font(.title)
          .foregroundColor(.purple)
        
        VStack(alignment: .leading, spacing: 4) {
          Text(friend.nickname.isEmpty ? friend.email : friend.nickname)
            .font(.headline)
            .foregroundColor(AppTheme.textPrimary)
          
          if !friend.nickname.isEmpty {
            Text(friend.email)
              .font(.caption)
              .foregroundColor(AppTheme.textSecondary)
          }
        }
        
        Spacer()
        
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)
      }
      .padding()
      .background(AppTheme.surface)
      .cornerRadius(12)
      .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
  }
  
  private func selectOpponent(friend: (email: String, nickname: String)) {
    opponentName = friend.nickname.isEmpty ? friend.email : friend.nickname
    HapticsService.shared.success()
    onOpponentSelected(opponentName)
  }
  
  private func fetchFriends() {
    guard !isLoading else { return }
    isLoading = true
    
    GRPCService().getFriends(offset: 0, limit: 20) { [self] fetchedFriends, total in
      DispatchQueue.main.async {
        self.isLoading = false
        self.friends = fetchedFriends
        self.totalCount = total
      }
    }
  }
  
  private func loadMore() {
    guard !isLoading else { return }
    isLoading = true
    
    GRPCService().getFriends(offset: friends.count, limit: 20) { [self] fetchedFriends, total in
      DispatchQueue.main.async {
        self.isLoading = false
        self.friends.append(contentsOf: fetchedFriends)
        self.totalCount = total
      }
    }
  }
}
