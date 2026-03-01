import SwiftUI
import Combine

// Flat-top hexagon for honeycomb layout
private struct HexagonShape: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    let cx = w / 2
    let r = min(w / 2, h / sqrt(3))
    var path = Path()
    for i in 0..<6 {
      let angle = CGFloat(i) * .pi / 3 - .pi / 6
      let x = cx + r * cos(angle)
      let y = h / 2 + r * sin(angle)
      if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
      else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
  }
}

enum ActivityType: CaseIterable {
  case chess
  case gym
  case steps
  case treadmill
  case elliptical
  case yoga
}

struct ActivitiesView: View {
  @Environment(\.dismiss) private var dismiss
  @AppStorage("chessTotalWins") private var chessTotalWins = 0
  @AppStorage("chessOpponents") private var chessOpponents = "{}" // JSON: {"opponent@email.com": "3:2"}
  @AppStorage("lastChessDate") private var lastChessDate = ""
  @AppStorage("chessWinsStartOfDay") private var chessWinsStartOfDay = 0
  @AppStorage("chessOpponentsStartOfDay") private var chessOpponentsStartOfDay = "{}" // JSON snapshot
  @AppStorage("chessPlayerName") private var chessPlayerName = ""
  @AppStorage("chessOpponentName") private var chessOpponentName = ""
  @AppStorage("chessOpponentEmail") private var chessOpponentEmail = ""
  @AppStorage("todayActivityDate") private var todayActivityDate = ""
  @AppStorage("todaySportCalories") private var todaySportCalories = 0
  @AppStorage("todaySportCaloriesDate") private var todaySportCaloriesDate = ""
  @AppStorage("todayTrackedActivityTypes") private var todayTrackedActivityTypes = ""  // e.g. "gym,yoga"
  
  /// Date (UTC, yyyy-MM-dd) for which we are showing and logging activities.
  let dateISO: String
  
  @State private var showChessWinnerSheet = false
  @State private var showOpponentPicker = false
  @State private var showActivityInputSheet = false
  @State private var showStatistics = false
  @State private var selectedActivityType: ActivityType = .treadmill
  @State private var inputValue = ""
  @State private var pendingGameResult: String = "" // "me", "draw", or "opponent"
  @State private var isSyncingChess = false
  @State private var showChessHistory = false
  @State private var showChessSheet = false
  @State private var cachedFriends: [(email: String, nickname: String)]? = nil
  
  // Activity summary for the selected date (for calories card + chips)
  @State private var summaryTotalCalories: Int = 0
  @State private var summaryActivityTypes: [String] = []
  
  var body: some View {
    return NavigationView {
      ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 20) {
            // Burned Calories Counter
            burnedCaloriesCard
            
            Divider()
              .padding(.vertical, 10)
            
            // Activities as honeycomb: filled = tracked, outline = not yet
            honeycombActivitiesView
          }
          .padding()
        }

        // Inline, compact activity input dialog over Activities background (without covering it)
        if showActivityInputSheet {
          VStack {
            Spacer()
            activityInputSheet
              .padding(.horizontal, 24)
              .padding(.bottom, 40)
          }
        }
      }
      .navigationTitle(Localization.shared.tr("activities.title", default: "Activities"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            dismiss()
          }) {
            Text(Localization.shared.tr("common.done", default: "Done"))
              .foregroundColor(AppTheme.textPrimary)
          }
        }
      }
      .sheet(isPresented: $showStatistics) {
        ActivityStatisticsView(isPresented: $showStatistics)
      }
      .sheet(isPresented: $showChessWinnerSheet) {
        chessWinnerSheet
      }
      .sheet(isPresented: $showOpponentPicker) {
        ChessOpponentPickerView(
          playerName: $chessPlayerName,
          opponentName: $chessOpponentName,
          onOpponentSelected: { opponentNickname, opponentEmail in
            chessOpponentEmail = opponentEmail
            showOpponentPicker = false
            recordChessGame(winner: pendingGameResult)
          },
          initialFriends: cachedFriends
        )
      }
      .sheet(isPresented: $showActivityInputSheet) {
        activityInputSheet
      }
      .sheet(isPresented: $showChessSheet) {
        NavigationView {
          ScrollView {
            chessActivityCard
              .padding(.bottom, 24)
          }
          .background(AppTheme.backgroundGradient.ignoresSafeArea())
          .navigationTitle(Localization.shared.tr("activities.chess.name", default: "Chess"))
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
              Button(Localization.shared.tr("common.done", default: "Done")) {
                showChessSheet = false
              }
              .foregroundColor(AppTheme.textPrimary)
            }
          }
        }
      }
      .onAppear {
        // Initialize player name if not set
        if chessPlayerName.isEmpty {
          if let nickname = UserDefaults.standard.string(forKey: "nickname"), !nickname.isEmpty {
            chessPlayerName = nickname
          } else if let email = UserDefaults.standard.string(forKey: "user_email") {
            chessPlayerName = email.components(separatedBy: "@").first ?? email
          }
        }
        // Migration: Clean up old score system (ONE TIME ONLY)
        let migrationKey = "chessLeagueMigrationDone"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
          UserDefaults.standard.removeObject(forKey: "chessScore")
          UserDefaults.standard.removeObject(forKey: "chessScoreStartOfDay")
          UserDefaults.standard.set(true, forKey: migrationKey)
        }
        prefetchFriends()
        syncChessDataFromBackend()
        loadActivitySummary()
      }
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnvironmentChanged"))) { _ in
        resetChessDataForEnvironmentSwitch()
      }
      .sheet(isPresented: $showChessHistory) {
        ChessOpponentsHistoryView(opponentsJSON: chessOpponents, isPresented: $showChessHistory)
      }
    }
  }
  
  // MARK: - Burned Calories Card
  
  private var burnedCaloriesCard: some View {
    let isToday = dateISO == getCurrentUTCDateString()
    let cardTitle: String = isToday
      ? Localization.shared.tr("activities.burned.title", default: "Today's Burned Calories")
      : Localization.shared.tr("activities.burned.title.date", default: "Burned calories for %@").replacingOccurrences(of: "%@", with: formatDateForDisplay(dateISO))
    return VStack(spacing: 15) {
      HStack {
        Image(systemName: "flame.fill")
          .font(.title2)
          .foregroundColor(.orange)
        
        Text(cardTitle)
          .font(.title3.bold())
          .foregroundColor(AppTheme.textPrimary)
        
        Spacer()
      }
      
      // Calories Display
      HStack(spacing: 8) {
        Text("\(summaryTotalCalories)")
          .font(.system(size: 48, weight: .bold))
          .foregroundColor(.orange)
        
        Text("kcal")
          .font(.title3)
          .foregroundColor(AppTheme.textSecondary)
          .padding(.top, 10)
      }
      
      if summaryTotalCalories > 0 {
        if isToday {
          Text(Localization.shared.tr("activities.burned.today", default: "Added to today's limit"))
            .font(.caption)
            .foregroundColor(.green)
        }
        
        // Reset: for today resets AppStorage + summary; for past date clears cache + summary for that date
        Button(action: {
          if isToday {
            resetTodayActivities()
            summaryTotalCalories = 0
            summaryActivityTypes = []
          } else {
            summaryTotalCalories = 0
            summaryActivityTypes = []
            saveActivitySummaryToCache(dateISO: dateISO, total: 0, types: [])
            // Notify ContentView so the main screen updates limit/calories for this date immediately
            NotificationCenter.default.post(
              name: NSNotification.Name("ActivityCaloriesAddedForDate"),
              object: nil,
              userInfo: ["dateISO": dateISO]
            )
            HapticsService.shared.warning()
            AlertHelper.showAlert(
              title: Localization.shared.tr("activities.burned.reset.title", default: "Activities Reset"),
              message: Localization.shared.tr("activities.burned.reset.date.msg", default: "Activities for this date have been reset."),
              haptic: .success
            )
          }
        }) {
          HStack {
            Image(systemName: "arrow.counterclockwise")
              .font(.system(size: 14))
            Text(isToday
                 ? Localization.shared.tr("activities.burned.reset", default: "Reset Today's Activities")
                 : Localization.shared.tr("activities.burned.reset.date", default: "Reset"))
              .font(.caption)
          }
          .foregroundColor(.red)
          .padding(.vertical, 8)
          .padding(.horizontal, 16)
          .background(Color.red.opacity(0.15))
          .cornerRadius(10)
        }
        .padding(.top, 5)
        
        // Activity source chips: Yoga, Gym, …
        if !summaryActivityTypes.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(summaryActivityTypes, id: \.self) { key in
                  Text(activitySummaryDisplayName(for: key))
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                      Capsule()
                        .fill(LinearGradient(
                          colors: [.green.opacity(0.9), .purple.opacity(0.8)],
                          startPoint: .leading,
                          endPoint: .trailing
                        ))
                    )
                }
              }
              .padding(.top, 2)
          }
          .padding(.top, 4)
        }
      } else {
        Text(Localization.shared.tr("activities.burned.none", default: "No activities recorded today"))
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)
      }
    }
    .padding()
    .background(AppTheme.surface)
    .cornerRadius(16)
    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    .padding(.horizontal)
    .id("burned-\(summaryTotalCalories)-\(summaryActivityTypes.joined(separator: ","))")
  }
  
  // MARK: - Honeycomb layout
  
  // +20% size (88→106, 76→91)
  private static let hexWidth: CGFloat = 106
  private static let hexHeight: CGFloat = 91
  
  private var honeycombActivitiesView: some View {
    let w = Self.hexWidth
    let h = Self.hexHeight
    
    // Gap between cells so they don't overlap
    let gap: CGFloat = 18
    let stepX = w + gap
    let stepY = h * CGFloat(sqrt(3)) / 2 + gap
    
    // Offset-grid: position (row, col) with step stepX, stepY
    func gridX(row: Int, col: Int) -> CGFloat {
      CGFloat(col) * stepX + CGFloat(row % 2) * (stepX / 2)
    }
    func gridY(row: Int) -> CGFloat {
      CGFloat(row) * stepY
    }
    
    // Grid center — statistics (reduced by 10%)
    let centerRow = 1
    let centerCol = 1
    let centerScale: CGFloat = 1.35 * 0.9   // −10%
    let centerW = w * centerScale
    let centerH = h * centerScale
    // Activities +5% size
    let activityW = w * 1.05
    let activityH = h * 1.05
    let originX = gridX(row: centerRow, col: centerCol)
    let originY = gridY(row: centerRow)
    
    // Neighbors for odd row (centerRow=1): left (1,0), right (1,2), up-left (0,1), up-right (0,2), down-left (2,1), down-right (2,2)
    
    return ZStack {
      // Center: Statistics
      honeycombCellStatistics()
        .frame(width: centerW, height: centerH)
        .offset(x: 0, y: 0)
      
      // Neighbors on offset-grid (+5% size)
      honeycombCell(type: .elliptical, title: Localization.shared.tr("activities.elliptical", default: "Elliptical"), icon: "figure.elliptical", color: .purple)
        .frame(width: activityW, height: activityH)
        .offset(x: gridX(row: 1, col: 0) - originX, y: gridY(row: 1) - originY)
      
      honeycombCell(type: .gym, title: Localization.shared.tr("activities.gym", default: "Gym"), icon: "dumbbell.fill", color: .orange)
        .frame(width: activityW, height: activityH)
        .offset(x: gridX(row: 0, col: 1) - originX, y: gridY(row: 0) - originY)
      
      honeycombCell(type: .steps, title: Localization.shared.tr("activities.steps", default: "Steps"), icon: "figure.walk", color: .green)
        .frame(width: activityW, height: activityH)
        .offset(x: gridX(row: 0, col: 2) - originX, y: gridY(row: 0) - originY)
      
      honeycombCell(type: .treadmill, title: Localization.shared.tr("activities.treadmill", default: "Treadmill"), icon: "figure.run", color: .blue)
        .frame(width: activityW, height: activityH)
        .offset(x: gridX(row: 1, col: 2) - originX, y: gridY(row: 1) - originY)
      
      honeycombCell(type: .yoga, title: Localization.shared.tr("activities.yoga", default: "Yoga"), icon: "figure.mind.and.body", color: Color(red: 0.4, green: 0.6, blue: 0.5))
        .frame(width: activityW, height: activityH)
        .offset(x: gridX(row: 2, col: 1) - originX, y: gridY(row: 2) - originY)
      
      honeycombCellChess()
        .frame(width: activityW, height: activityH)
        .offset(x: gridX(row: 2, col: 2) - originX, y: gridY(row: 2) - originY)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 3 * stepY + h)
    .padding(.vertical, 8)
  }
  
  private func honeycombCellStatistics() -> some View {
    Button(action: {
      HapticsService.shared.select()
      showStatistics = true
    }) {
      ZStack {
        HexagonShape()
          .fill(AppTheme.surface)
        HexagonShape()
          .stroke(Color.green.opacity(0.6), lineWidth: 2)
        VStack(spacing: 8) {
          Image(systemName: "chart.bar.fill")
            .font(.title)
            .foregroundColor(.green)
          Text(Localization.shared.tr("activities.stats.short", default: "Stats"))
            .font(.subheadline.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundColor(AppTheme.textPrimary)
        }
        .scaleEffect(1.25)
      }
      .clipShape(HexagonShape())
      .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
    .buttonStyle(.plain)
  }
  
  private func honeycombCell(type: ActivityType, title: String, icon: String, color: Color) -> some View {
    let tracked = isTrackedForViewedDate(type)
    return Button(action: {
      HapticsService.shared.select()
      selectedActivityType = type
      inputValue = ""
      showActivityInputSheet = true
    }) {
      ZStack {
        if tracked {
          HexagonShape()
            .fill(LinearGradient(colors: [.green, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
          HexagonShape()
            .fill(AppTheme.surface)
          HexagonShape()
            .stroke(Color.green.opacity(0.6), lineWidth: 2)
        }
        VStack(spacing: 4) {
          Image(systemName: ThemeService.shared.icon(for: icon))
            .font(.title2)
            .foregroundColor(tracked ? .white : color)
          Text(title)
            .font(.caption.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundColor(tracked ? .white : AppTheme.textPrimary)
        }
      }
      .clipShape(HexagonShape())
      .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
    .buttonStyle(.plain)
  }
  
  private func honeycombCellChess() -> some View {
    let tracked = isTrackedForViewedDate(.chess)
    return Button(action: {
      HapticsService.shared.select()
      showChessSheet = true
    }) {
      ZStack {
        if tracked {
          HexagonShape()
            .fill(LinearGradient(colors: [.green, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
          HexagonShape()
            .fill(AppTheme.surface)
          HexagonShape()
            .stroke(Color.green.opacity(0.6), lineWidth: 2)
        }
        VStack(spacing: 4) {
          Image(systemName: ThemeService.shared.icon(for: "square.grid.3x3.fill"))
            .font(.title2)
            .foregroundColor(tracked ? .white : .purple)
          Text(Localization.shared.tr("activities.chess.name", default: "Chess"))
            .font(.caption.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundColor(tracked ? .white : AppTheme.textPrimary)
        }
      }
      .clipShape(HexagonShape())
      .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
    .buttonStyle(.plain)
  }
  
  // MARK: - Chess Activity Card
  
  private var chessActivityCard: some View {
    return VStack(spacing: 15) {
      HStack {
        Image(systemName: "square.grid.3x3.fill")
          .font(.title2)
          .foregroundColor(.purple)
        
        Text(Localization.shared.tr("activities.chess.name", default: "Chess"))
          .font(.title3.bold())
          .foregroundColor(AppTheme.textPrimary)
        
        Button(action: {
          HapticsService.shared.select()
          showChessHistory = true
        }) {
          Image(systemName: "clock.arrow.circlepath")
            .font(.caption)
          Text(Localization.shared.tr("activities.chess.history", default: "History"))
            .font(.caption.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .foregroundColor(.blue)
        
        Spacer()
        
        if isSyncingChess {
          ProgressView()
            .scaleEffect(0.8)
        }
        
        #if DEBUG
        // Environment indicator
        if AppEnvironment.useDevEnvironment {
          Text("DEV")
            .font(.system(size: 9, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.red)
            .cornerRadius(4)
        }
        #endif
      }
      
      // Total Wins and League
      VStack(spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(Localization.shared.tr("activities.chess.wins_label", default: "Wins:"))
            .font(.title3)
            .foregroundColor(AppTheme.textSecondary)
          Text("\(chessTotalWins)")
            .font(.system(size: 44, weight: .bold))
            .foregroundColor(getLeagueColor())
        }
        
        Text(getLeague())
          .font(.headline)
          .foregroundColor(getLeagueColor())
          .padding(.horizontal, 16)
          .padding(.vertical, 6)
          .background(getLeagueColor().opacity(0.15))
          .cornerRadius(12)
      }
      
      // Current / Last Opponent Score (clearer W-L format)
      if !chessOpponentName.isEmpty, !chessOpponentEmail.isEmpty,
         let opponentScore = getOpponentScore(chessOpponentEmail) {
        let parts = opponentScore.split(separator: ":")
        let myW = parts.count == 2 ? String(parts[0]) : "0"
        let opW = parts.count == 2 ? String(parts[1]) : "0"
        
        VStack(spacing: 6) {
          Text("\(Localization.shared.tr("activities.chess.vs", default: "vs")) \(chessOpponentName)")
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
          
          HStack(spacing: 12) {
            VStack(spacing: 2) {
              Text(myW)
                .font(.title2.bold())
                .foregroundColor(.green)
              Text(Localization.shared.tr("activities.chess.wins_short", default: "W"))
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
            }
            
            Text("—")
              .font(.title3)
              .foregroundColor(AppTheme.textSecondary)
            
            VStack(spacing: 2) {
              Text(opW)
                .font(.title2.bold())
                .foregroundColor(.red)
              Text(Localization.shared.tr("activities.chess.losses_short", default: "L"))
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
            }
          }
          
          // Quick rematch button
          Button(action: {
            HapticsService.shared.select()
            showChessWinnerSheet = true
          }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12))
              Text(Localization.shared.tr("activities.chess.rematch", default: "Rematch"))
                .font(.caption.bold())
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.12))
            .cornerRadius(10)
          }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(AppTheme.surface.opacity(0.5))
        .cornerRadius(12)
      }
      
      if !lastChessDate.isEmpty {
        Text("\(Localization.shared.tr("activities.last_game", default: "Last game")): \(formatDate(lastChessDate))")
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)
      }
      
      Button(action: {
        HapticsService.shared.select()
        showChessWinnerSheet = true
      }) {
        HStack {
          Image(systemName: "plus.circle.fill")
          Text(Localization.shared.tr("activities.chess.record", default: "Record Game"))
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
          LinearGradient(
            gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.7)]),
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .cornerRadius(12)
      }
    }
    .padding()
    .background(AppTheme.surface)
    .cornerRadius(16)
    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    .padding(.horizontal)
  }
  
  // MARK: - Chess Activity Button (opens sheet)
  
  private var chessActivityButton: some View {
    let tracked = isTrackedForViewedDate(.chess)
    return Button(action: {
      HapticsService.shared.select()
      showChessSheet = true
    }) {
      HStack {
        Image(systemName: ThemeService.shared.icon(for: "square.grid.3x3.fill"))
          .font(.title2)
          .foregroundColor(tracked ? .white : .purple)
          .frame(width: 40)
        
        VStack(alignment: .leading, spacing: 2) {
          Text(Localization.shared.tr("activities.chess.name", default: "Chess"))
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundColor(tracked ? .white : AppTheme.textPrimary)
          Text(Localization.shared.tr("activities.chess.subtitle", default: "Record games, view wins"))
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundColor(tracked ? .white.opacity(0.9) : AppTheme.textSecondary)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(tracked ? .white : AppTheme.textSecondary)
      }
      .padding()
      .background(
        Group {
          if tracked {
            LinearGradient(colors: [.green, .purple], startPoint: .leading, endPoint: .trailing)
          } else {
            AppTheme.surface
          }
        }
      )
      .cornerRadius(12)
      .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    .buttonStyle(.plain)
  }
  
  // MARK: - Tracked Today Helpers
  
  private func activityTypeKey(_ type: ActivityType) -> String {
    switch type {
    case .gym: return "gym"
    case .steps: return "steps"
    case .treadmill: return "treadmill"
    case .elliptical: return "elliptical"
    case .yoga: return "yoga"
    case .chess: return "chess"
    }
  }

  private func activityTypeFromKey(_ key: String) -> ActivityType? {
    switch key {
    case "gym": return .gym
    case "steps": return .steps
    case "treadmill": return .treadmill
    case "elliptical": return .elliptical
    case "yoga": return .yoga
    case "chess": return .chess
    default: return nil
    }
  }
  
  private func isTrackedToday(_ type: ActivityType) -> Bool {
    if type == .chess {
      return lastChessDate == getCurrentUTCDateString()
    }
    return todayTrackedActivityTypes.contains(activityTypeKey(type))
  }
  
  /// Highlight (green-purple) only activities tracked for the currently viewed date, not other dates.
  private func isTrackedForViewedDate(_ type: ActivityType) -> Bool {
    if type == .chess {
      return (dateISO == getCurrentUTCDateString() && lastChessDate == dateISO)
        || summaryActivityTypes.contains("chess")
    }
    return summaryActivityTypes.contains(activityTypeKey(type))
  }

  private func trackedActivitiesToday() -> [ActivityType] {
    todayTrackedActivityTypes
      .split(separator: ",")
      .compactMap { activityTypeFromKey(String($0)) }
  }

  private func activityDisplayName(_ type: ActivityType) -> String {
    switch type {
    case .gym:
      return Localization.shared.tr("activities.gym", default: "Gym")
    case .steps:
      return Localization.shared.tr("activities.steps", default: "Steps")
    case .treadmill:
      return Localization.shared.tr("activities.treadmill", default: "Treadmill")
    case .elliptical:
      return Localization.shared.tr("activities.elliptical", default: "Elliptical")
    case .yoga:
      return Localization.shared.tr("activities.yoga", default: "Yoga")
    case .chess:
      return Localization.shared.tr("activities.chess.name", default: "Chess")
    }
  }
  
  // MARK: - Activity Button
  
  private func activityButton(type: ActivityType, title: String, subtitle: String, icon: String, color: Color) -> some View {
    let tracked = isTrackedForViewedDate(type)
    return Button(action: {
      HapticsService.shared.select()
      selectedActivityType = type
      inputValue = ""
      showActivityInputSheet = true
    }) {
      HStack {
        // Theme-aware icon
        Image(systemName: ThemeService.shared.icon(for: icon))
          .font(.title2)
          .foregroundColor(tracked ? .white : color)
          .frame(width: 40)
        
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundColor(tracked ? .white : AppTheme.textPrimary)
          Text(subtitle)
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundColor(tracked ? .white.opacity(0.9) : AppTheme.textSecondary)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(tracked ? .white : AppTheme.textSecondary)
      }
      .padding()
      .background(
        Group {
          if tracked {
            LinearGradient(colors: [.green, .purple], startPoint: .leading, endPoint: .trailing)
          } else {
            AppTheme.surface
          }
        }
      )
      .cornerRadius(12)
      .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    .buttonStyle(.plain)
  }
  
  // MARK: - Chess Winner Sheet
  
  private var chessWinnerSheet: some View {
    return NavigationView {
      ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        
        VStack(spacing: 20) {
          Text(Localization.shared.tr("activities.chess.who_won", default: "Who won?"))
            .font(.title2.bold())
            .foregroundColor(AppTheme.textPrimary)
            .padding(.top, 30)
          
          Spacer()
          
          Button(action: { 
            pendingGameResult = "me"
            showChessWinnerSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showOpponentPicker = true
            }
          }) {
            VStack {
              Image(systemName: "person.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
              Text(Localization.shared.tr("activities.chess.me", default: "Me"))
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(AppTheme.surface)
            .cornerRadius(20)
            .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
          }
          
          Button(action: { 
            pendingGameResult = "draw"
            showChessWinnerSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showOpponentPicker = true
            }
          }) {
            VStack {
              Image(systemName: "equal")
                .font(.system(size: 50))
                .foregroundColor(.gray)
              Text(Localization.shared.tr("activities.chess.draw", default: "Draw"))
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(AppTheme.surface)
            .cornerRadius(20)
            .shadow(color: Color.gray.opacity(0.3), radius: 10, x: 0, y: 5)
          }
          
          Button(action: { 
            pendingGameResult = "opponent"
            showChessWinnerSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showOpponentPicker = true
            }
          }) {
            VStack {
              Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
              Text(Localization.shared.tr("activities.chess.opponent", default: "Opponent"))
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(AppTheme.surface)
            .cornerRadius(20)
            .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 5)
          }
          
          Spacer()
          
          // Reset Today's Games Button
          if lastChessDate == getCurrentUTCDateString() {
            Button(action: {
              resetTodayChessGames()
            }) {
              HStack {
                Image(systemName: "arrow.counterclockwise")
                  .font(.system(size: 16))
                Text(Localization.shared.tr("activities.chess.reset_today", default: "Reset Today's Games"))
                  .font(.callout)
              }
              .foregroundColor(.orange)
              .padding(.vertical, 12)
              .padding(.horizontal, 20)
              .background(Color.orange.opacity(0.15))
              .cornerRadius(12)
            }
            .padding(.bottom, 10)
          }
        }
        .padding()
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            showChessWinnerSheet = false
          }) {
            Text(Localization.shared.tr("common.done", default: "Done"))
              .foregroundColor(AppTheme.textPrimary)
          }
        }
      }
    }
  }
  
  // MARK: - Activity Input Sheet
  
  private var activityInputSheet: some View {
    return VStack(spacing: 20) {
      HStack {
        Text(activityTitle)
          .font(.title2.bold())
          .foregroundColor(AppTheme.textPrimary)
        Spacer()
        Button {
          let trimmed = inputValue.trimmingCharacters(in: .whitespacesAndNewlines)
          if trimmed.isEmpty {
            showActivityInputSheet = false
          } else {
            submitActivity()
          }
        } label: {
          Text(Localization.shared.tr("common.done", default: "Done"))
            .font(.headline)
            .foregroundColor(AppTheme.accent)
        }
      }
      
      Text(activityPrompt)
        .font(.subheadline)
        .foregroundColor(AppTheme.textSecondary)
        .multilineTextAlignment(.leading)
      
      TextField(activityPlaceholder, text: $inputValue)
        .keyboardType(.numberPad)
        .font(.title2)
        .multilineTextAlignment(.center)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(AppTheme.surfaceAlt)
        .cornerRadius(12)
    }
    .padding(20)
    .background(AppTheme.surface)
    .cornerRadius(18)
    .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 8)
  }
  
  // MARK: - Helper Properties
  
  private var activityTitle: String {
    switch selectedActivityType {
    case .gym:
      return Localization.shared.tr("activities.gym", default: "Gym")
    case .steps:
      return Localization.shared.tr("activities.steps", default: "Steps")
    case .treadmill:
      return Localization.shared.tr("activities.treadmill", default: "Treadmill")
    case .elliptical:
      return Localization.shared.tr("activities.elliptical", default: "Elliptical")
    case .yoga:
      return Localization.shared.tr("activities.yoga", default: "Yoga")
    case .chess:
      return Localization.shared.tr("activities.chess.name", default: "Chess")
    }
  }
  
  private var activityPrompt: String {
    switch selectedActivityType {
    case .gym:
      return Localization.shared.tr("activities.gym.prompt", default: "How many minutes did you train?")
    case .steps:
      return Localization.shared.tr("activities.steps.prompt", default: "How many steps did you walk?")
    case .treadmill, .elliptical, .yoga:
      return Localization.shared.tr("activities.calories.prompt", default: "How many calories did you burn?")
    case .chess:
      return ""
    }
  }
  
  private var activityPlaceholder: String {
    switch selectedActivityType {
    case .gym:
      return Localization.shared.tr("activities.gym.placeholder", default: "Minutes")
    case .steps:
      return Localization.shared.tr("activities.steps.placeholder", default: "Steps")
    case .treadmill, .elliptical, .yoga:
      return Localization.shared.tr("activities.calories.placeholder", default: "Calories")
    case .chess:
      return ""
    }
  }
  
  // MARK: - Helper Methods
  
  private func getLeague() -> String {
    if chessTotalWins == 0 {
      return "🎯 " + Localization.shared.tr("activities.no_league_yet", default: "No League Yet")
    } else if chessTotalWins <= 5 {
      return "🪵 " + Localization.shared.tr("activities.league.wooden", default: "Wooden League")
    } else if chessTotalWins <= 10 {
      return "🥉 " + Localization.shared.tr("activities.league.bronze", default: "Bronze League")
    } else if chessTotalWins <= 20 {
      return "🥈 " + Localization.shared.tr("activities.league.silver", default: "Silver League")
    } else if chessTotalWins <= 30 {
      return "🥇 " + Localization.shared.tr("activities.league.gold", default: "Gold League")
    } else if chessTotalWins <= 50 {
      return "💎 Diamond League"
    } else {
      return "👑 Grandmaster League"
    }
  }
  
  private func getLeagueColor() -> Color {
    if chessTotalWins == 0 {
      return AppTheme.textSecondary // Gray for no league
    } else if chessTotalWins <= 5 {
      return Color(red: 0.6, green: 0.4, blue: 0.2) // Brown
    } else if chessTotalWins <= 10 {
      return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
    } else if chessTotalWins <= 20 {
      return .gray // Silver
    } else if chessTotalWins <= 30 {
      return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
    } else if chessTotalWins <= 50 {
      return Color(red: 0.4, green: 0.8, blue: 1.0) // Diamond
    } else {
      return .purple // Grandmaster
    }
  }
  
  private func getOpponentScore(_ opponentEmail: String) -> String? {
    guard let data = chessOpponents.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
          let score = dict[opponentEmail] else {
      return nil
    }
    return score
  }
  
  private func updateOpponentScore(_ opponentEmail: String, myWins: Int, opponentWins: Int) {
    var dict: [String: String] = [:]
    if let data = chessOpponents.data(using: .utf8),
       let existing = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
      dict = existing
    }
    dict[opponentEmail] = "\(myWins):\(opponentWins)"
    if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      chessOpponents = jsonString
    }
  }
  
  private func recordChessGame(winner: String) {
    let today = getCurrentUTCDateString()
    
    // If this is the first game today, save current state as "start of day"
    if lastChessDate != today {
      chessWinsStartOfDay = chessTotalWins
      chessOpponentsStartOfDay = chessOpponents
    }
    
    // Get current opponent's score
    var myWins = 0
    var opponentWins = 0
    if !chessOpponentEmail.isEmpty, let scoreStr = getOpponentScore(chessOpponentEmail) {
      let components = scoreStr.split(separator: ":")
      if components.count == 2 {
        myWins = Int(components[0]) ?? 0
        opponentWins = Int(components[1]) ?? 0
      }
    }
    
    // Check for league promotion BEFORE updating
    let oldLeague = getLeague()
    
    // Update scores
    switch winner {
    case "me":
      myWins += 1
      chessTotalWins += 1
    case "opponent":
      opponentWins += 1
    case "draw":
      break
    default:
      break
    }
    
    // Save opponent score locally
    if !chessOpponentEmail.isEmpty {
      updateOpponentScore(chessOpponentEmail, myWins: myWins, opponentWins: opponentWins)
    }
    
    lastChessDate = today
    todayActivityDate = today
    
    // Щоб шахи були видно в статистиці (планети): додати "chess" у кеш активностей на сьогодні.
    let cached = loadActivitySummaryFromCache(dateISO: today)
    if !cached.types.contains("chess") {
      var types = cached.types
      types.append("chess")
      saveActivitySummaryToCache(dateISO: today, total: cached.total, types: types)
    }
    
    // Кожна партія = одна сесія (перемога, поразка чи нічия). Зберігаємо кількість ігор за день.
    let chessCountKey = "activity_summary_chess_count_\(today)"
    let prevCount = UserDefaults.standard.integer(forKey: chessCountKey)
    UserDefaults.standard.set(prevCount + 1, forKey: chessCountKey)
    
    showChessWinnerSheet = false
    
    // Sync with backend
    if let playerEmail = UserDefaults.standard.string(forKey: "user_email"),
       !chessOpponentEmail.isEmpty {
      let backendResult: String
      switch winner {
      case "me": backendResult = "win"
      case "opponent": backendResult = "loss"
      case "draw": backendResult = "draw"
      default: backendResult = "draw"
      }
      
      GRPCService().recordChessGame(
        playerEmail: playerEmail,
        opponentEmail: chessOpponentEmail,
        result: backendResult
      ) { _, _, _ in }
    }
    
    // Notify ContentView to update sport icon
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      NotificationCenter.default.post(name: NSNotification.Name("ChessGameRecorded"), object: nil)
    }
    
    HapticsService.shared.success()
    
    // Check for league promotion
    let newLeague = getLeague()
    let wasPromoted = (newLeague != oldLeague && winner == "me")
    
    let message: String
    switch winner {
    case "me":
      message = getRandomWinQuote()
    case "draw":
      message = getRandomDrawQuote()
    case "opponent":
      message = getRandomLossQuote()
    default:
      message = ""
    }
    
    // Show game recorded alert (neutral title, no mascot message)
    let title = Localization.shared.tr("activities.chess.recorded_title", default: "Game recorded")
    ThemeService.shared.playSound(for: "success")
    
    AlertHelper.showAlert(
      title: title,
      message: message,
      haptic: .success
    )
    
    // Show promotion alert after game recorded alert (if promoted)
    if wasPromoted {
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        AlertHelper.showAlert(
          title: "🎉 " + Localization.shared.tr("activities.chess.promoted", default: "Promoted!"),
          message: String(format: Localization.shared.tr("activities.chess.promoted.msg", default: "You have been promoted to %@!"), newLeague),
          haptic: .success
        )
      }
    }
  }
  
  // MARK: - Reset Today's Activities
  
  private func resetTodayActivities() {
    // Reset sport calories and tracked types
    todaySportCalories = 0
    todaySportCaloriesDate = ""
    todayActivityDate = ""
    todayTrackedActivityTypes = ""
    
    HapticsService.shared.warning()
    
    AlertHelper.showAlert(
      title: Localization.shared.tr("activities.burned.reset.title", default: "Activities Reset"),
      message: Localization.shared.tr("activities.burned.reset.msg", default: "All today's activities have been reset. Your daily calorie limit has returned to normal."),
      haptic: .success
    )
  }
  
  // MARK: - Reset Today's Chess Games
  
  private func resetTodayChessGames() {
    // Only reset if there were games today
    guard lastChessDate == getCurrentUTCDateString() else { return }
    
    let today = getCurrentUTCDateString()
    
    // Restore wins and opponent scores to start of day
    chessTotalWins = chessWinsStartOfDay
    chessOpponents = chessOpponentsStartOfDay
    
    // Обнулити кількість партій за сьогодні в статистиці та прибрати chess з типів за день
    UserDefaults.standard.removeObject(forKey: "activity_summary_chess_count_\(today)")
    var cached = loadActivitySummaryFromCache(dateISO: today)
    if let idx = cached.types.firstIndex(of: "chess") {
      cached.types.remove(at: idx)
      saveActivitySummaryToCache(dateISO: today, total: cached.total, types: cached.types)
    }
    
    // Get yesterday's date
    let calendar = Calendar.current
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
    let yesterdayString = dateFormatter.string(from: yesterday)
    
    // Set lastChessDate to yesterday so today's games don't count for the green icon
    lastChessDate = yesterdayString
    
    // Also reset todayActivityDate if it was set by chess AND there's no other activities
    if todayActivityDate == getCurrentUTCDateString() && todaySportCalories == 0 {
      todayActivityDate = ""
    }
    
    showChessWinnerSheet = false
    
    HapticsService.shared.warning()
    
    let message = String(
      format: Localization.shared.tr("activities.chess.reset.msg", default: "Today's chess games have been cancelled. Total wins restored to: %d"),
      chessTotalWins
    )
    
    AlertHelper.showAlert(
      title: Localization.shared.tr("activities.chess.reset.title", default: "Games Reset"),
      message: message,
      haptic: .success
    )
  }
  
  // MARK: - Sync Chess Data
  
  private func syncChessDataFromBackend() {
    guard !isSyncingChess else { return }
    isSyncingChess = true
    
    GRPCService().getAllChessData { success, totalWins, opponents in
      DispatchQueue.main.async {
        self.isSyncingChess = false
        
        if success {
          let hasBackendData = totalWins > 0 || !opponents.isEmpty
          
          if hasBackendData {
            self.chessTotalWins = totalWins
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: opponents),
               let jsonString = String(data: jsonData, encoding: .utf8) {
              self.chessOpponents = jsonString
            }
          } else if self.chessTotalWins == 0 && self.chessOpponents == "{}" {
            self.chessTotalWins = 0
            self.chessOpponents = "{}"
          }
        }
      }
    }
  }
  
  // MARK: - Environment Switch Support
  
  private func resetChessDataForEnvironmentSwitch() {
    
    // Reset all chess-related @AppStorage values to defaults
    chessTotalWins = 0
    chessOpponents = "{}"
    lastChessDate = ""
    chessWinsStartOfDay = 0
    chessOpponentsStartOfDay = "{}"
    chessOpponentName = ""
    chessOpponentEmail = ""
    // Keep chessPlayerName - it's the user's own name
    
    // Clear friends cache (friends list may differ per environment)
    cachedFriends = nil
    
    // Re-sync from the new environment's backend
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.syncChessDataFromBackend()
      self.prefetchFriends()
    }
  }
  
  // MARK: - Friends Cache
  
  private func prefetchFriends() {
    GRPCService().getFriends(offset: 0, limit: 100) { fetchedFriends, _ in
      DispatchQueue.main.async {
        self.cachedFriends = fetchedFriends
      }
    }
  }
  
  // MARK: - Grandmaster Quotes
  
  private static let chessQuoteWinKeys = (1...10).map { "chess.quote.win.\($0)" }
  private static let chessQuoteDrawKeys = (1...10).map { "chess.quote.draw.\($0)" }
  private static let chessQuoteLossKeys = (1...10).map { "chess.quote.loss.\($0)" }

  private func getRandomWinQuote() -> String {
    let key = Self.chessQuoteWinKeys.randomElement() ?? "chess.quote.win.1"
    return Localization.shared.tr(key, default: Localization.shared.tr("chess.quote.win.fallback", default: "👑 Victory is yours! Score updated."))
  }

  private func getRandomDrawQuote() -> String {
    let key = Self.chessQuoteDrawKeys.randomElement() ?? "chess.quote.draw.1"
    return Localization.shared.tr(key, default: Localization.shared.tr("chess.quote.draw.fallback", default: "⚖️ An honorable draw. Well fought!"))
  }

  private func getRandomLossQuote() -> String {
    let key = Self.chessQuoteLossKeys.randomElement() ?? "chess.quote.loss.1"
    return Localization.shared.tr(key, default: Localization.shared.tr("chess.quote.loss.fallback", default: "💪 Learn from this game and come back stronger!"))
  }
  
  // MARK: - Activity Summary (per selected date) + cache by date (like food for past date)
  
  private static func activitySummaryCacheKeyTotal(_ dateISO: String) -> String {
    "activity_summary_total_\(dateISO)"
  }
  
  private static func activitySummaryCacheKeyTypes(_ dateISO: String) -> String {
    "activity_summary_types_\(dateISO)"
  }
  
  private func loadActivitySummaryFromCache(dateISO: String) -> (total: Int, types: [String]) {
    let ud = UserDefaults.standard
    let total = ud.integer(forKey: Self.activitySummaryCacheKeyTotal(dateISO))
    let typesStr = ud.string(forKey: Self.activitySummaryCacheKeyTypes(dateISO)) ?? ""
    let types = typesStr.isEmpty ? [] : typesStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    return (total, types)
  }
  
  private func saveActivitySummaryToCache(dateISO: String, total: Int, types: [String]) {
    let ud = UserDefaults.standard
    ud.set(total, forKey: Self.activitySummaryCacheKeyTotal(dateISO))
    ud.set(types.joined(separator: ","), forKey: Self.activitySummaryCacheKeyTypes(dateISO))
  }
  
  private func loadActivitySummary() {
    // 1) Apply cached value for this date first (so past date shows saved data on reopen, like food)
    let cached = loadActivitySummaryFromCache(dateISO: dateISO)
    if cached.total > 0 || !cached.types.isEmpty {
      summaryTotalCalories = cached.total
      summaryActivityTypes = cached.types
    }
    
    GRPCService().getActivitySummary(dateISO: dateISO) { total, types in
      DispatchQueue.main.async {
        let isToday = self.dateISO == self.getCurrentUTCDateString()
        // For today: if API returns 0 but we have local data (AppStorage), use it so card shows after reopen
        if isToday, total == 0, self.todaySportCaloriesDate == self.getTodayDDMMYYYY(), self.todaySportCalories > 0 {
          self.summaryTotalCalories = self.todaySportCalories
          self.summaryActivityTypes = self.todayTrackedActivityTypes.isEmpty
            ? []
            : self.todayTrackedActivityTypes.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
          self.saveActivitySummaryToCache(dateISO: self.dateISO, total: self.summaryTotalCalories, types: self.summaryActivityTypes)
          return
        }
        // Merge API with current state: take max total and union of types (so we don't lose user-added past-date data)
        let mergedTotal = max(self.summaryTotalCalories, total)
        var mergedTypes = Set(self.summaryActivityTypes)
        mergedTypes.formUnion(types)
        self.summaryTotalCalories = mergedTotal
        self.summaryActivityTypes = Array(mergedTypes).sorted()
        self.saveActivitySummaryToCache(dateISO: self.dateISO, total: self.summaryTotalCalories, types: self.summaryActivityTypes)
      }
    }
  }
  
  /// Today in dd-MM-yyyy (UTC) to match ContentView / AppStorage
  private func getTodayDDMMYYYY() -> String {
    let f = DateFormatter()
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "dd-MM-yyyy"
    return f.string(from: Date())
  }
  
  private func activitySummaryDisplayName(for key: String) -> String {
    if let type = activityTypeFromKey(key) {
      return activityDisplayName(type)
    }
    return key.capitalized
  }
  
  private func submitActivity() {
    guard let value = Int(inputValue), value > 0 else {
      AlertHelper.showAlert(
        title: Localization.shared.tr("activities.invalid.title", default: "Invalid Input"),
        message: Localization.shared.tr("activities.invalid.msg", default: "Please enter a valid number."),
        haptic: .error
      )
      return
    }
    
    let calories: Int
    let activityName: String
    
    switch selectedActivityType {
    case .gym:
      activityName = "Gym"
      calories = calculateGymCalories(minutes: value)
    case .steps:
      activityName = "Steps"
      calories = calculateStepsCalories(steps: value)
    case .treadmill:
      activityName = "Treadmill"
      calories = value
    case .elliptical:
      activityName = "Elliptical"
      calories = value
    case .yoga:
      activityName = "Yoga"
      calories = value
    case .chess:
      return
    }
    
    // Check if selected date is "today" in UTC (for adjusting today's calorie limit/UI)
    let todayISO = getCurrentUTCDateString()
    let isToday = (dateISO == todayISO)
    
    if isToday {
      todayActivityDate = todayISO
      // Remember this type was tracked today (for green-purple button highlight)
      let key = activityTypeKey(selectedActivityType)
      if !todayTrackedActivityTypes.contains(key) {
        todayTrackedActivityTypes = todayTrackedActivityTypes.isEmpty ? key : todayTrackedActivityTypes + "," + key
      }
      
      // Notify parent view so ContentView can update today's sport calories
      NotificationCenter.default.post(
        name: NSNotification.Name("ActivityCaloriesAdded"),
        object: nil,
        userInfo: [
          "calories": calories,
          "activity": activityName,
          "activityType": selectedActivityType,
          "value": value  // minutes or steps or calories
        ]
      )
    }
    
    let key = activityTypeKey(selectedActivityType)
    
    // Update card first so it repaints with new calories
    summaryTotalCalories += calories
    if !summaryActivityTypes.contains(key) {
      summaryActivityTypes.append(key)
    }
    // Persist by date (same logic as food: past date data stays on reopen)
    saveActivitySummaryToCache(dateISO: dateISO, total: summaryTotalCalories, types: summaryActivityTypes)
    
    // Notify so ContentView can add this date's activity to the daily limit (today or past)
    NotificationCenter.default.post(
      name: NSNotification.Name("ActivityCaloriesAddedForDate"),
      object: nil,
      userInfo: ["dateISO": dateISO]
    )
    
    GRPCService().logActivity(
      activityType: key,
      value: value,
      calories: calories,
      dateISO: dateISO
    ) { _ in }
    
    let themeTitle = ThemeService.shared.getMotivationalMessage(
      for: "activity_recorded",
      language: LanguageService.shared.currentCode
    )
    let message = String(
      format: Localization.shared.tr("activities.added.msg", default: "%d calories from %@ added to your daily limit."),
      calories,
      activityName
    )
    
    // Close sheet and show alert after a tick so the card has time to re-render with new total
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      self.showActivityInputSheet = false
      ThemeService.shared.playSound(for: "success")
      AlertHelper.showAlert(
        title: themeTitle,
        message: message,
        haptic: .success
      )
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      self.loadActivitySummary()
    }
  }
  
  // MARK: - Calorie Calculations
  
  private func calculateGymCalories(minutes: Int) -> Int {
    let userDefaults = UserDefaults.standard
    let weight = userDefaults.double(forKey: "userWeight")
    
    // If no weight data, use average 70kg
    let weightKg = weight > 0 ? weight : 70.0
    
    // MET value for moderate gym workout (5.0)
    let met = 5.0
    let hours = Double(minutes) / 60.0
    
    // Calories = MET × weight (kg) × time (hours)
    let calories = met * weightKg * hours
    
    return Int(calories)
  }
  
  private func calculateStepsCalories(steps: Int) -> Int {
    let userDefaults = UserDefaults.standard
    let weight = userDefaults.double(forKey: "userWeight")
    
    // If no weight data, use average 70kg
    let weightKg = weight > 0 ? weight : 70.0
    
    // Average: 0.04-0.06 calories per step, depends on weight
    // Formula: steps * 0.04 * (weight/70)
    let caloriesPerStep = 0.04 * (weightKg / 70.0)
    let calories = Double(steps) * caloriesPerStep
    
    return Int(calories)
  }
  
  private func formatDate(_ dateString: String) -> String {
    let components = dateString.split(separator: "-")
    guard components.count == 3 else { return dateString }
    return "\(components[2]).\(components[1]).\(components[0])"
  }
  
  /// Format yyyy-MM-dd for display in card title (e.g. "18 Feb 2026" or "18.02.2026")
  private func formatDateForDisplay(_ dateISO: String) -> String {
    let parts = dateISO.split(separator: "-")
    guard parts.count == 3,
          let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
      return dateISO
    }
    return String(format: "%02d.%02d.%d", d, m, y)
  }
  
  private func getCurrentUTCDateString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: Date())
  }
}

#Preview {
  ActivitiesView(dateISO: "2025-01-01")
}
