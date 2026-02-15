import SwiftUI

struct ChessOpponentsHistoryView: View {
  let opponentsJSON: String
  @Binding var isPresented: Bool
  
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
        
        if parsedOpponents.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "person.2.slash.fill")
              .font(.system(size: 50))
              .foregroundColor(AppTheme.textSecondary)
            Text(Localization.shared.tr("activities.chess.history.empty", default: "No opponents yet"))
              .font(.headline)
              .foregroundColor(AppTheme.textSecondary)
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
      .navigationTitle(Localization.shared.tr("activities.chess.history.title", default: "Opponent History"))
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
    }
  }
}
