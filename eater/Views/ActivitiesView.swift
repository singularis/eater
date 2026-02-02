import SwiftUI

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
  @AppStorage("chessPlayerName") private var chessPlayerName = ""
  @AppStorage("chessOpponentName") private var chessOpponentName = ""
  @AppStorage("todayActivityDate") private var todayActivityDate = ""
  @AppStorage("todaySportCalories") private var todaySportCalories = 0
  @AppStorage("todaySportCaloriesDate") private var todaySportCaloriesDate = ""
  
  @State private var showChessWinnerSheet = false
  @State private var showOpponentPicker = false
  @State private var showActivityInputSheet = false
  @State private var selectedActivityType: ActivityType = .treadmill
  @State private var inputValue = ""
  @State private var pendingGameResult: String = "" // "me", "draw", or "opponent"
  
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
              title: "Gym",
              subtitle: Localization.shared.tr("activities.gym.subtitle", default: "Enter time"),
              icon: "dumbbell.fill",
              color: .orange
            )
            
            activityButton(
              type: .steps,
              title: "Steps",
              subtitle: Localization.shared.tr("activities.steps.subtitle", default: "Enter step count"),
              icon: "figure.walk",
              color: .green
            )
            
            activityButton(
              type: .treadmill,
              title: "Treadmill",
              subtitle: Localization.shared.tr("activities.treadmill.subtitle", default: "Enter calories"),
              icon: "figure.run",
              color: .blue
            )
            
            activityButton(
              type: .elliptical,
              title: "Elliptical",
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
          onOpponentSelected: { opponentNickname in
            showOpponentPicker = false
            recordChessGame(winner: pendingGameResult)
          }
        )
      }
      .sheet(isPresented: $showActivityInputSheet) {
        activityInputSheet
      }
      .onAppear {
        print("🎮 ActivitiesView appeared")
        print("🎮 chessTotalWins: \(chessTotalWins)")
        print("🎮 chessOpponents: \(chessOpponents)")
        
        // Initialize player name if not set
        if chessPlayerName.isEmpty {
          if let nickname = UserDefaults.standard.string(forKey: "nickname"), !nickname.isEmpty {
            chessPlayerName = nickname
          } else if let email = UserDefaults.standard.string(forKey: "currentUserEmail") {
            chessPlayerName = email.components(separatedBy: "@").first ?? email
          }
        }
        
        // Migration: Reset old score system to new wins system (ONE TIME ONLY)
        let migrationKey = "chessLeagueMigrationDone"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
          print("🎮 Running migration...")
          if let oldScore = UserDefaults.standard.string(forKey: "chessScore"), !oldScore.isEmpty && oldScore != "0:0" {
            print("🎮 Found old score: \(oldScore), resetting to new system")
            // Clear old system
            UserDefaults.standard.removeObject(forKey: "chessScore")
            UserDefaults.standard.removeObject(forKey: "chessScoreStartOfDay")
            // Reset to 0
            chessTotalWins = 0
            chessWinsStartOfDay = 0
            chessOpponents = "{}"
          } else {
            print("🎮 No old score found, keeping current state")
          }
          UserDefaults.standard.set(true, forKey: migrationKey)
        }
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
        
        Text("Chess")
          .font(.title3.bold())
          .foregroundColor(AppTheme.textPrimary)
        
        Spacer()
      }
      
      // Total Wins and League
      VStack(spacing: 8) {
        HStack(spacing: 8) {
          Text("\(chessTotalWins)")
            .font(.system(size: 48, weight: .bold))
            .foregroundColor(getLeagueColor())
          
          Text("won")
            .font(.title3)
            .foregroundColor(AppTheme.textSecondary)
            .padding(.top, 10)
        }
        
        Text(getLeague())
          .font(.headline)
          .foregroundColor(getLeagueColor())
          .padding(.horizontal, 16)
          .padding(.vertical, 6)
          .background(getLeagueColor().opacity(0.15))
          .cornerRadius(12)
      }
      
      // Current Opponent Score (if exists)
      if !chessOpponentName.isEmpty, let opponentScore = getOpponentScore(chessOpponentName) {
        VStack(spacing: 4) {
          Text("vs \(chessOpponentName)")
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
          Text(opponentScore)
            .font(.subheadline.bold())
            .foregroundColor(AppTheme.textPrimary)
        }
      }
      
      if !lastChessDate.isEmpty {
        Text("Last game: \(formatDate(lastChessDate))")
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
        Image(systemName: icon)
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
            showOpponentPicker = true
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
            showOpponentPicker = true
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
            showOpponentPicker = true
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
      return "Gym"
    case .steps:
      return "Steps"
    case .treadmill:
      return "Treadmill"
    case .elliptical:
      return "Elliptical"
    case .chess:
      return "Chess"
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
      return "🎯 No League Yet"
    } else if chessTotalWins <= 5 {
      return "🪵 Wooden League"
    } else if chessTotalWins <= 10 {
      return "🥉 Bronze League"
    } else if chessTotalWins <= 20 {
      return "🥈 Silver League"
    } else if chessTotalWins <= 30 {
      return "🥇 Gold League"
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
    
    print("🎮 Recording chess game: winner=\(winner), opponent=\(chessOpponentName)")
    print("🎮 Before: chessTotalWins=\(chessTotalWins)")
    
    // If this is the first game today, save current wins as "start of day"
    if lastChessDate != today {
      chessWinsStartOfDay = chessTotalWins
      print("🎮 New day! Saved start of day wins: \(chessWinsStartOfDay)")
    }
    
    // Get current opponent's score
    var myWins = 0
    var opponentWins = 0
    if !chessOpponentName.isEmpty, let scoreStr = getOpponentScore(chessOpponentName) {
      let components = scoreStr.split(separator: ":")
      if components.count == 2 {
        myWins = Int(components[0]) ?? 0
        opponentWins = Int(components[1]) ?? 0
      }
      print("🎮 Current score vs \(chessOpponentName): \(myWins):\(opponentWins)")
    }
    
    // Check for league promotion BEFORE updating
    let oldLeague = getLeague()
    
    // Update scores
    switch winner {
    case "me":
      myWins += 1
      chessTotalWins += 1
      print("🎮 I won! myWins=\(myWins), chessTotalWins=\(chessTotalWins)")
    case "opponent":
      opponentWins += 1
      print("🎮 Opponent won! opponentWins=\(opponentWins)")
    case "draw":
      print("🎮 Draw!")
      break
    default:
      break
    }
    
    // Save opponent score
    if !chessOpponentName.isEmpty {
      updateOpponentScore(chessOpponentName, myWins: myWins, opponentWins: opponentWins)
      print("🎮 Updated opponent score: \(myWins):\(opponentWins)")
      print("🎮 All opponents: \(chessOpponents)")
    }
    
    lastChessDate = today
    todayActivityDate = today
    
    showChessWinnerSheet = false
    
    // Notify ContentView to update sport icon
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      NotificationCenter.default.post(name: NSNotification.Name("ChessGameRecorded"), object: nil)
    }
    
    HapticsService.shared.success()
    
    // Check for league promotion
    let newLeague = getLeague()
    if newLeague != oldLeague && winner == "me" {
      // Show promotion alert
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        AlertHelper.showAlert(
          title: "🎉 " + Localization.shared.tr("activities.chess.promoted", default: "Promoted!"),
          message: String(format: Localization.shared.tr("activities.chess.promoted.msg", default: "You have been promoted to %@!"), newLeague),
          haptic: .success
        )
      }
    }
    
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
    
    AlertHelper.showAlert(
      title: Localization.shared.tr("activities.chess.recorded", default: "Game Recorded"),
      message: message,
      haptic: .success
    )
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
    
    // Restore wins to start of day
    chessTotalWins = chessWinsStartOfDay
    
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
  
  // MARK: - Grandmaster Quotes
  
  private func getRandomWinQuote() -> String {
    let quotes = [
      "👑 \"Every chess master was once a beginner.\" - Chernev",
      "⚔️ \"Tactics is knowing what to do when there is something to do; strategy is knowing what to do when there is nothing to do.\" - Tartakower",
      "🏆 \"The beauty of a move lies not in its appearance but in the thought behind it.\" - Nimzowitsch",
      "🎯 \"The winner of the game is the player who makes the next-to-last mistake.\" - Tartakower",
      "♟️ \"Even a poor plan is better than no plan at all.\" - Mikhail Chigorin",
      "🔥 \"The threat is stronger than the execution.\" - Nimzowitsch",
      "💎 \"Discovered check is the dive bomber of the chessboard.\" - Reuben Fine",
      "⭐ \"When you see a good move, look for a better one.\" - Emanuel Lasker",
      "🌟 \"Play the opening like a book, the middle game like a magician, and the endgame like a machine.\" - Spielmann",
      "🎪 \"Chess is the struggle against error.\" - Johannes Zukertort"
    ]
    return quotes.randomElement() ?? "👑 Victory is yours! Score updated."
  }
  
  private func getRandomDrawQuote() -> String {
    let quotes = [
      "🤝 \"In chess, as in life, a man is his own most dangerous opponent.\" - Reuben Fine",
      "⚖️ \"The hardest game to win is a won game.\" - Emanuel Lasker",
      "🎭 \"There are two types of sacrifices: correct ones, and mine.\" - Mikhail Tal",
      "🌊 \"Chess is a sea in which a gnat may drink and an elephant may bathe.\" - Indian Proverb",
      "🧩 \"Chess is life.\" - Bobby Fischer",
      "🎯 \"Half the variations which are calculated in a tournament game turn out to be completely superfluous.\" - Jan Timman",
      "💫 \"A strong memory, concentration, imagination, and a strong will is required to become a great chess player.\" - Fischer",
      "🔮 \"Chess is 99% tactics.\" - Richard Teichmann",
      "🎨 \"Chess is the art of analysis.\" - Mikhail Botvinnik",
      "⏳ \"I don't believe in psychology. I believe in good moves.\" - Bobby Fischer"
    ]
    return quotes.randomElement() ?? "⚖️ An honorable draw. Well fought!"
  }
  
  private func getRandomLossQuote() -> String {
    let quotes = [
      "💪 \"Losing can persuade you to change what doesn't need to be changed, and winning can convince you everything is fine even if you are on the brink of disaster.\" - Garry Kasparov",
      "🌱 \"You must take your opponent into a deep dark forest where 2+2=5, and the path leading out is only wide enough for one.\" - Mikhail Tal",
      "🔄 \"Life is like a game of chess. To win you have to make a move.\" - Allan Rufus",
      "📚 \"I have not given any drawn or lost games, because I thought them inadequate for the purposes of instruction.\" - Capablanca",
      "🎲 \"The blunders are all there on the board, waiting to be made.\" - Savielly Tartakower",
      "🌟 \"The mistakes are there, waiting to be made.\" - Savielly Tartakower",
      "🛡️ \"I prefer to lose a really good game than to win a bad one.\" - David Levy",
      "🌸 \"Even a poor plan is better than no plan.\" - Frank Marshall",
      "🎓 \"Every chess master was once a beginner who refused to give up.\" - Unknown",
      "⚡ \"You may learn much more from a game you lose than from a game you win.\" - Capablanca"
    ]
    return quotes.randomElement() ?? "💪 Learn from this game and come back stronger!"
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
    
    AlertHelper.showAlert(
      title: Localization.shared.tr("activities.added.title", default: "Activity Added"),
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
