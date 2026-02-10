import Foundation

extension GRPCService {
  /// Record a chess game and synchronize with opponent
  /// - Parameters:
  ///   - playerEmail: Current player's email
  ///   - opponentEmail: Opponent's email
  ///   - result: Game result ("win", "draw", "loss")
  ///   - completion: Callback with success status and updated scores (player:opponent)
  func recordChessGame(
    playerEmail: String,
    opponentEmail: String,
    result: String,
    completion: @escaping (Bool, String?, String?) -> Void  // success, playerScore, opponentScore
  ) {
    // Create JSON request
    let requestDict: [String: Any] = [
      "player_email": playerEmail,
      "opponent_email": opponentEmail,
      "result": result,
      "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
    ]
    
    guard let body = try? JSONSerialization.data(withJSONObject: requestDict) else {
      print("❌ Failed to serialize chess game request")
      completion(false, nil, nil)
      return
    }
    
    guard var urlRequest = createRequest(endpoint: "autocomplete/record_chess_game", httpMethod: "POST", body: body) else {
      print("❌ Failed to create chess game request")
      completion(false, nil, nil)
      return
    }
    
    // Set JSON content type
    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    print("🎮 Sending chess game to backend: \(playerEmail) vs \(opponentEmail), result=\(result)")
    
    sendRequest(request: urlRequest, retriesLeft: 3) { data, response, error in
      if let error = error {
        print("❌ Chess game recording failed: \(error.localizedDescription)")
        completion(false, nil, nil)
        return
      }
      
      guard let data = data else {
        print("❌ No data received from chess game endpoint")
        completion(false, nil, nil)
        return
      }
      
      do {
        guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          print("❌ Invalid response format")
          completion(false, nil, nil)
          return
        }
        
        if let success = responseDict["success"] as? Bool, success {
          let playerWins = responseDict["player_wins"] as? Int ?? 0
          let playerLosses = responseDict["player_losses"] as? Int ?? 0
          let opponentWins = responseDict["opponent_wins"] as? Int ?? 0
          let opponentLosses = responseDict["opponent_losses"] as? Int ?? 0
          
          let playerScore = "\(playerWins):\(playerLosses)"
          let opponentScore = "\(opponentWins):\(opponentLosses)"
          
          print("✅ Chess game recorded: player=\(playerScore), opponent=\(opponentScore)")
          completion(true, playerScore, opponentScore)
        } else {
          print("❌ Chess game recording failed on backend")
          completion(false, nil, nil)
        }
      } catch {
        print("❌ Failed to parse chess game response: \(error)")
        completion(false, nil, nil)
      }
    }
  }
  
  /// Get chess statistics for current user
  /// - Parameters:
  ///   - userEmail: User's email
  ///   - opponentEmail: Optional opponent to filter stats
  ///   - completion: Callback with score string (e.g. "3:2") and last opponent name
  func getChessStats(
    userEmail: String,
    opponentEmail: String? = nil,
    completion: @escaping (Bool, String?, String?, String?) -> Void  // success, score, opponentName, lastGameDate
  ) {
    var requestDict: [String: Any] = ["user_email": userEmail]
    if let opponent = opponentEmail {
      requestDict["opponent_email"] = opponent
    }
    
    guard let body = try? JSONSerialization.data(withJSONObject: requestDict) else {
      print("❌ Failed to serialize chess stats request")
      completion(false, nil, nil, nil)
      return
    }
    
    guard var urlRequest = createRequest(endpoint: "autocomplete/get_chess_stats", httpMethod: "POST", body: body) else {
      print("❌ Failed to create chess stats request")
      completion(false, nil, nil, nil)
      return
    }
    
    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    sendRequest(request: urlRequest, retriesLeft: 3) { data, response, error in
      if let error = error {
        print("❌ Chess stats fetch failed: \(error.localizedDescription)")
        completion(false, nil, nil, nil)
        return
      }
      
      guard let data = data else {
        print("❌ No data received from chess stats endpoint")
        completion(false, nil, nil, nil)
        return
      }
      
      do {
        guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          print("❌ Invalid stats response format")
          completion(false, nil, nil, nil)
          return
        }
        
        let score = responseDict["score"] as? String ?? "0:0"
        let opponentName = responseDict["opponent_name"] as? String
        let lastGameDate = responseDict["last_game_date"] as? String
        
        print("✅ Chess stats: score=\(score), opponent=\(opponentName ?? "none"), lastGame=\(lastGameDate ?? "none")")
        completion(true, score, opponentName, lastGameDate)
      } catch {
        print("❌ Failed to parse chess stats response: \(error)")
        completion(false, nil, nil, nil)
      }
    }
  }
  
  /// Get all chess data (total wins + all opponent scores)
  /// - Parameters:
  ///   - completion: Callback with total wins and opponents dictionary
  func getAllChessData(
    completion: @escaping (Bool, Int, [String: String]) -> Void  // success, totalWins, opponents{"email": "3:2"}
  ) {
    guard let urlRequest = createRequest(endpoint: "autocomplete/get_all_chess_data", httpMethod: "GET") else {
      print("❌ Failed to create get all chess data request")
      completion(false, 0, [:])
      return
    }
    
    print("🎮 Fetching all chess data from backend...")
    
    sendRequest(request: urlRequest, retriesLeft: 3) { data, response, error in
      if let error = error {
        print("❌ Chess data fetch failed: \(error.localizedDescription)")
        completion(false, 0, [:])
        return
      }
      
      guard let data = data else {
        print("❌ No data received from chess data endpoint")
        completion(false, 0, [:])
        return
      }
      
      do {
        guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          print("❌ Invalid chess data response format")
          completion(false, 0, [:])
          return
        }
        
        let totalWins = responseDict["total_wins"] as? Int ?? 0
        let opponents = responseDict["opponents"] as? [String: String] ?? [:]
        
        print("✅ Chess data fetched: totalWins=\(totalWins), opponents=\(opponents.count)")
        completion(true, totalWins, opponents)
      } catch {
        print("❌ Failed to parse chess data response: \(error)")
        completion(false, 0, [:])
      }
    }
  }
}
