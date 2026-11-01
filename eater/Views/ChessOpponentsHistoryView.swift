import SwiftUI

struct ChessOpponentsHistoryView: View {
  let opponentsJSON: String
  @Binding var isPresented: Bool
  var startOnHistory: Bool = false

  @State private var selectedTab = 0
  @State private var games: [[String: Any]] = []
  @State private var isLoadingHistory = false
  @State private var historyLoaded = false
  @State private var pieceCounts: [String: Int] = [:]
  @State private var gameKinds: [String: Int] = [:]

  init(
    opponentsJSON: String,
    isPresented: Binding<Bool>,
    startOnHistory: Bool = false
  ) {
    self.opponentsJSON = opponentsJSON
    self._isPresented = isPresented
    self.startOnHistory = startOnHistory
    _selectedTab = State(initialValue: startOnHistory ? 1 : 0)
  }
  
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
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            historyList
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          colorSummary
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(Localization.shared.tr("activities.chess.history.title", default: "Chess History"))
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundColor(AppTheme.textPrimary)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: {
            isPresented = false
          }) {
            Text(Localization.shared.tr("common.done", default: "Done"))
              .bold()
              .lineLimit(1)
          }
          .fixedSize(horizontal: true, vertical: false)
        }
      }
      .onAppear {
        if startOnHistory && selectedTab != 1 {
          selectedTab = 1
        }
        if !historyLoaded {
          loadHistory()
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
            HStack(alignment: .center, spacing: 8) {
              VStack(alignment: .leading, spacing: 4) {
                Text(opponent.email)
                  .font(.headline)
                  .foregroundColor(AppTheme.textPrimary)
                  .lineLimit(2)
                  .minimumScaleFactor(0.7)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              
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
    
    let piece = game["color"] as? String
    return HStack(alignment: .top, spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 22))
        .foregroundColor(color)
        .frame(width: 28)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(opponentName)
          .font(.headline)
          .foregroundColor(AppTheme.textPrimary)
          .lineLimit(2)
          .minimumScaleFactor(0.7)
        
        Text("\(dateStr) • \(timeStr)")
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 8) {
        if let piece, piece == "black" || piece == "white" || piece == "red" {
          playedPawn(piece)
        }

        Text(result.uppercased())
          .font(.subheadline.bold())
          .foregroundColor(color)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
    }
    .padding(.vertical, 4)
    .listRowBackground(color.opacity(0.18))
  }

  /// Filled pawn in the color the player used in that game. No pawn when color is missing.
  private func playedPawn(_ piece: String) -> some View {
    PlayedPawnMark(fill: pawnFill(piece), outline: pawnOutline(piece))
      .frame(width: 16, height: 22)
      .accessibilityLabel(piece)
  }
  
  private func loadHistory() {
    isLoadingHistory = true
    GRPCService().getChessHistory(limit: 50, offset: 0) { success, _, fetchedGames, pieces, kinds in
      DispatchQueue.main.async {
        self.isLoadingHistory = false
        if success {
          self.games = fetchedGames
          self.pieceCounts = pieces
          self.gameKinds = kinds
          self.historyLoaded = true
        }
      }
    }
  }

  /// Server totals for every game, not just this page. A zero count is left off.
  @ViewBuilder
  private var colorSummary: some View {
    let unknown = Localization.shared.tr("chess.summary.unknown", default: "Unknown")
    let pieces = summaryLine([
      (Localization.shared.tr("activities.chess.color.white", default: "White"), pieceCounts["white"] ?? 0),
      (Localization.shared.tr("activities.chess.color.black", default: "Black"), pieceCounts["black"] ?? 0),
      (Localization.shared.tr("activities.chess.color.red", default: "Red"), pieceCounts["red"] ?? 0),
      (unknown, pieceCounts["unknown"] ?? 0),
    ])
    let kinds = summaryLine([
      (Localization.shared.tr("activities.chess.name", default: "Chess"), gameKinds["chess"] ?? 0),
      (Localization.shared.tr("activities.chess.color.xiangqi", default: "Xiangqi"), gameKinds["xiangqi"] ?? 0),
      (unknown, gameKinds["unknown"] ?? 0),
    ])
    if pieces != nil || kinds != nil {
      VStack(alignment: .leading, spacing: 4) {
        if let pieces {
          Text(pieces)
        }
        if let kinds {
          Text(kinds)
        }
      }
      .font(.subheadline)
      .foregroundColor(AppTheme.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .background(AppTheme.surface)
    }
  }

  private func summaryLine(_ items: [(String, Int)]) -> String? {
    let shown = items.filter { $0.1 > 0 }
    guard !shown.isEmpty else { return nil }
    return shown.map { "\($0.0) \($0.1)" }.joined(separator: ", ")
  }
}

func pawnFill(_ piece: String) -> Color {
  switch piece {
  case "black": return .black
  case "white": return .white
  default: return .red
  }
}

func pawnOutline(_ piece: String) -> Color {
  switch piece {
  case "white": return Color.black.opacity(0.55)
  case "black": return Color.white.opacity(0.75)
  default: return Color.black.opacity(0.35)
  }
}

/// Filled pawn. White and black get a thin edge so they stay visible on the row.
struct PlayedPawnMark: View {
  let fill: Color
  var outline: Color = .clear

  var body: some View {
    PlayedPawnShape()
      .fill(fill)
      .overlay(PlayedPawnShape().stroke(outline, lineWidth: 1))
  }
}

/// Staunton-style pawn: round head, narrow neck, wide base.
struct PlayedPawnShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let w = rect.width
    let h = rect.height
    let cx = rect.midX
    let head = min(w * 0.48, h * 0.40)

    path.addEllipse(
      in: CGRect(x: cx - head / 2, y: rect.minY + h * 0.02, width: head, height: head)
    )

    let neckY = rect.minY + h * 0.02 + head * 0.70
    let bellyY = rect.minY + h * 0.68
    let footY = rect.maxY - h * 0.16

    path.move(to: CGPoint(x: cx - w * 0.14, y: neckY))
    path.addQuadCurve(
      to: CGPoint(x: cx - w * 0.30, y: bellyY),
      control: CGPoint(x: cx - w * 0.38, y: (neckY + bellyY) / 2)
    )
    path.addLine(to: CGPoint(x: cx - w * 0.42, y: footY))
    path.addLine(to: CGPoint(x: cx + w * 0.42, y: footY))
    path.addLine(to: CGPoint(x: cx + w * 0.30, y: bellyY))
    path.addQuadCurve(
      to: CGPoint(x: cx + w * 0.14, y: neckY),
      control: CGPoint(x: cx + w * 0.38, y: (neckY + bellyY) / 2)
    )
    path.closeSubpath()

    let baseH = max(2.5, h * 0.14)
    path.addRoundedRect(
      in: CGRect(x: cx - w * 0.48, y: rect.maxY - baseH, width: w * 0.96, height: baseH),
      cornerSize: CGSize(width: baseH / 2, height: baseH / 2)
    )
    return path
  }
}
