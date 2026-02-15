import SwiftUI
import Combine

enum ActivityType {
  case chess
  case gym
  case steps
  case treadmill
  case elliptical
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
  
  @State private var showChessWinnerSheet = false
  @State private var showOpponentPicker = false
  @State private var showActivityInputSheet = false
  @State private var selectedActivityType: ActivityType = .treadmill
  @State private var inputValue = ""
  @State private var pendingGameResult: String = "" // "me", "draw", or "opponent"
  @State private var isSyncingChess = false
  @State private var showChessHistory = false
  @State private var cachedFriends: [(email: String, nickname: String)]? = nil
  
  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 20) {
            // Chess Activity
            chessActivityCard
            
            // Burned Calories Counter
            burnedCaloriesCard
            
            Divider()
              .padding(.vertical, 10)
            
            // Other Activities Header
            Text(Localization.shared.tr("activities.other", default: "Other Activities"))
              .font(.headline)
              .foregroundColor(AppTheme.textPrimary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal)
            
            // Calorie-based activities
            activityButton(
              type: .gym,
              title: Localization.shared.tr("activities.gym", default: "Gym"),
              subtitle: Localization.shared.tr("activities.gym.subtitle", default: "Enter time"),
              icon: "dumbbell.fill",
              color: .orange
            )
            
            activityButton(
              type: .steps,
              title: Localization.shared.tr("activities.steps", default: "Steps"),
              subtitle: Localization.shared.tr("activities.steps.subtitle", default: "Enter step count"),
              icon: "figure.walk",
              color: .green
            )
            
            activityButton(
              type: .treadmill,
              title: Localization.shared.tr("activities.treadmill", default: "Treadmill"),
              subtitle: Localization.shared.tr("activities.treadmill.subtitle", default: "Enter calories"),
              icon: "figure.run",
              color: .blue
            )
            
            activityButton(
              type: .elliptical,
              title: Localization.shared.tr("activities.elliptical", default: "Elliptical"),
              subtitle: Localization.shared.tr("activities.elliptical.subtitle", default: "Enter calories"),
              icon: "figure.elliptical",
              color: .purple
            )
          }
          .padding()
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
        
        // Pre-fetch friends list for chess opponent picker (cache it)
        prefetchFriends()
        
        // Sync chess data from backend (only if it has data or we have no local data)
        syncChessDataFromBackend()
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
    VStack(spacing: 15) {
      HStack {
        Image(systemName: "flame.fill")
          .font(.title2)
          .foregroundColor(.orange)
        
        Text(Localization.shared.tr("activities.burned.title", default: "Today's Burned Calories"))
          .font(.title3.bold())
          .foregroundColor(AppTheme.textPrimary)
        
        Spacer()
      }
      
      // Calories Display
      HStack(spacing: 8) {
        Text("\(todaySportCalories)")
          .font(.system(size: 48, weight: .bold))
          .foregroundColor(.orange)
        
        Text("kcal")
          .font(.title3)
          .foregroundColor(AppTheme.textSecondary)
          .padding(.top, 10)
      }
      
      if todaySportCalories > 0 {
        Text(Localization.shared.tr("activities.burned.today", default: "Added to today's limit"))
          .font(.caption)
          .foregroundColor(.green)
        
        // Reset Button
        Button(action: {
          resetTodayActivities()
        }) {
          HStack {
            Image(systemName: "arrow.counterclockwise")
              .font(.system(size: 14))
            Text(Localization.shared.tr("activities.burned.reset", default: "Reset Today's Activities"))
              .font(.caption)
          }
          .foregroundColor(.red)
          .padding(.vertical, 8)
          .padding(.horizontal, 16)
          .background(Color.red.opacity(0.15))
          .cornerRadius(10)
        }
        .padding(.top, 5)
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
  }
  
  // MARK: - Chess Activity Card
  
  private var chessActivityCard: some View {
    VStack(spacing: 15) {
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
  
  // MARK: - Activity Button
  
  private func activityButton(type: ActivityType, title: String, subtitle: String, icon: String, color: Color) -> some View {
    Button(action: {
      HapticsService.shared.select()
      selectedActivityType = type
      inputValue = ""
      showActivityInputSheet = true
    }) {
      HStack {
        // Theme-aware icon
        Image(systemName: ThemeService.shared.icon(for: icon))
          .font(.title2)
          .foregroundColor(color)
          .frame(width: 40)
        
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.headline)
            .foregroundColor(AppTheme.textPrimary)
          Text(subtitle)
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
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
    .padding(.horizontal)
  }
  
  // MARK: - Chess Winner Sheet
  
  private var chessWinnerSheet: some View {
    NavigationView {
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
            Text(Localization.shared.tr("common.cancel", default: "Cancel"))
              .foregroundColor(AppTheme.textPrimary)
          }
        }
      }
    }
  }
  
  // MARK: - Activity Input Sheet
  
  private var activityInputSheet: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        
        VStack(spacing: 20) {
          VStack(spacing: 8) {
            Text(activityTitle)
              .font(.title2.bold())
              .foregroundColor(AppTheme.textPrimary)
            
            Text(activityPrompt)
              .font(.subheadline)
              .foregroundColor(AppTheme.textSecondary)
              .multilineTextAlignment(.center)
          }
          .padding(.top, 30)
          
          TextField(activityPlaceholder, text: $inputValue)
            .keyboardType(.numberPad)
            .font(.title)
            .multilineTextAlignment(.center)
            .padding()
            .background(AppTheme.surface)
            .cornerRadius(12)
            .padding(.horizontal)
          
          Spacer()
          
          Button(action: {
            submitActivity()
          }) {
            Text(Localization.shared.tr("activities.submit", default: "Add to Today's Limit"))
              .font(.headline)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding()
              .background(
                LinearGradient(
                  gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .cornerRadius(12)
          }
          .padding(.horizontal)
          .padding(.bottom, 30)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            showActivityInputSheet = false
          }) {
            Text(Localization.shared.tr("common.cancel", default: "Cancel"))
              .foregroundColor(AppTheme.textPrimary)
          }
        }
      }
    }
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
    case .treadmill, .elliptical:
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
    case .treadmill, .elliptical:
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
    // Reset sport calories
    todaySportCalories = 0
    todaySportCaloriesDate = ""
    todayActivityDate = ""
    
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
    
    // Restore wins and opponent scores to start of day
    chessTotalWins = chessWinsStartOfDay
    chessOpponents = chessOpponentsStartOfDay
    
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
    case .chess:
      return
    }
    
    // Mark activity for today
    todayActivityDate = getCurrentUTCDateString()
    
    // Notify parent view
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
    
    showActivityInputSheet = false
    
    // Theme-aware motivational message
    let themeTitle = ThemeService.shared.getMotivationalMessage(
      for: "activity_recorded",
      language: LanguageService.shared.currentCode
    )
    ThemeService.shared.playSound(for: "success")
    
    AlertHelper.showAlert(
      title: themeTitle,
      message: String(
        format: Localization.shared.tr("activities.added.msg", default: "%d calories from %@ added to your daily limit."),
        calories,
        activityName
      ),
      haptic: .success
    )
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
  
  private func getCurrentUTCDateString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: Date())
  }
}

#Preview {
  ActivitiesView()
}
