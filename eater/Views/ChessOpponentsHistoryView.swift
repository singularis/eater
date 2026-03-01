import SwiftUI

struct ChessOpponentsHistoryView: View {
  let opponentsJSON: String
  @Binding var isPresented: Bool
  
  @State private var selectedTab = 0
  @State private var games: [[String: Any]] = []
  @State private var isLoadingHistory = false
  @State private var historyLoaded = false
  
  private var parsedOpponents: [(email: String, wins: Int, losses: Int)] {
    guard let data = opponentsJSON.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
      return []
    }
    
    return dict.map { email, score -> (String, Int, Int) in
      let parts = score.split(separator: ":")
      let wins = parts.count == 2 ? Int(parts[0]) ?? 0 : 0
      let losses = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
      return (email, wins, losses)
    }.sorted { $0.wins > $1.wins } // Sort by wins descending
  }
  
  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        
        VStack(spacing: 0) {
          Picker("View", selection: $selectedTab) {
            Text(Localization.shared.tr("chess.tab.opponents", default: "Opponents")).tag(0)
            Text(Localization.shared.tr("chess.tab.history", default: "History")).tag(1)
          }
          .pickerStyle(SegmentedPickerStyle())
          .padding()
          .background(AppTheme.surfaceAlt)
          
          if selectedTab == 0 {
            opponentsList
          } else {
            historyList
          }
        }
      }
      .navigationTitle(Localization.shared.tr("activities.chess.history.title", default: "Chess History"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            isPresented = false
          }) {
            Text(Localization.shared.tr("common.done", default: "Done"))
              .bold()
          }
        }
      }
      .onChange(of: selectedTab) { _, newValue in
        if newValue == 1 && !historyLoaded {
          loadHistory()
        }
      }
    }
    .environment(\.locale, Locale(identifier: LanguageService.shared.currentCode))
  }
  
  private var opponentsList: some View {
    Group {
      if parsedOpponents.isEmpty {
        VStack(spacing: 16) {
          Spacer()
          Image(systemName: "person.2.slash.fill")
            .font(.system(size: 50))
            .foregroundColor(AppTheme.textSecondary)
          Text(Localization.shared.tr("activities.chess.history.empty", default: "No opponents yet"))
            .font(.headline)
            .foregroundColor(AppTheme.textSecondary)
          Spacer()
        }
      } else {
        List {
          ForEach(parsedOpponents, id: \.email) { opponent in
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(opponent.email)
                  .font(.headline)
                  .foregroundColor(AppTheme.textPrimary)
              }
              
              Spacer()
              
              HStack(spacing: 12) {
                VStack(spacing: 0) {
                  Text("\(opponent.wins)")
                    .font(.title3.bold())
                    .foregroundColor(.green)
                  Text("W")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                }
                
                Text("-")
                  .foregroundColor(AppTheme.textSecondary)
                
                VStack(spacing: 0) {
                  Text("\(opponent.losses)")
                    .font(.title3.bold())
                    .foregroundColor(.red)
                  Text("L")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                }
              }
              .padding(.leading, 8)
            }
            .padding(.vertical, 4)
            .listRowBackground(AppTheme.surface)
          }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
      }
    }
  }
  
  private var historyList: some View {
    Group {
      if isLoadingHistory {
        VStack {
          Spacer()
          ProgressView()
          Spacer()
        }
      } else if games.isEmpty {
        VStack(spacing: 16) {
          Spacer()
          Image(systemName: "clock.arrow.circlepath")
            .font(.system(size: 50))
            .foregroundColor(AppTheme.textSecondary)
          Text(Localization.shared.tr("chess.history.empty", default: "No games played yet"))
            .font(.headline)
            .foregroundColor(AppTheme.textSecondary)
          Spacer()
        }
      } else {
        List {
          ForEach(0..<games.count, id: \.self) { index in
            let game = games[index]
            gameRow(for: game)
          }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable {
          loadHistory()
        }
      }
    }
  }
  
  private func gameRow(for game: [String: Any]) -> some View {
    let result = game["result"] as? String ?? "unknown"
    let opponentName = game["opponent_nickname"] as? String ?? game["opponent_email"] as? String ?? "Unknown"
    let dateStr = game["date"] as? String ?? ""
    let timeStr = game["time"] as? String ?? ""
    
    // Determine color and icon based on result
    let color: Color
    let icon: String
    if result == "win" {
      color = .green
      icon = "trophy.fill"
    } else if result == "loss" {
      color = .red
      icon = "xmark.circle.fill"
    } else {
      color = .orange
      icon = "minus.circle.fill"
    }
    
    return HStack {
      Image(systemName: icon)
        .font(.system(size: 24))
        .foregroundColor(color)
        .frame(width: 32)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(opponentName)
          .font(.headline)
          .foregroundColor(AppTheme.textPrimary)
        
        Text("\(dateStr) • \(timeStr)")
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)
      }
      
      Spacer()
      
      Text(result.uppercased())
        .font(.subheadline.bold())
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    .padding(.vertical, 4)
    .listRowBackground(AppTheme.surface)
  }
  
  private func loadHistory() {
    isLoadingHistory = true
    GRPCService().getChessHistory(limit: 50, offset: 0) { success, total, fetchedGames in
      DispatchQueue.main.async {
        self.isLoadingHistory = false
        if success {
          self.games = fetchedGames
          self.historyLoaded = true
        }
      }
    }
  }
}
