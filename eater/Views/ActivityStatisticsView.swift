import SwiftUI

/// Statistics only for activities (burned calories by date). Not related to food statistics.
struct ActivityStatisticsView: View {
  @Binding var isPresented: Bool
  
  private static let totalKeyPrefix = "activity_summary_total_"
  private static let typesKeyPrefix = "activity_summary_types_"
  
  private struct DayEntry: Identifiable {
    let id: String
    let dateISO: String
    let totalCalories: Int
    let types: [String]
    let displayDate: String
  }
  
  private var entries: [DayEntry] {
    let ud = UserDefaults.standard
    let all = ud.dictionaryRepresentation()
    var result: [DayEntry] = []
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
    let displayFormatter = DateFormatter()
    displayFormatter.dateStyle = .medium
    displayFormatter.timeZone = TimeZone(identifier: "UTC")
    
    for (key, _) in all {
      guard key.hasPrefix(Self.totalKeyPrefix) else { continue }
      let dateISO = String(key.dropFirst(Self.totalKeyPrefix.count))
      guard dateISO.count == 10, dateISO.allSatisfy({ $0 == "-" || $0.isNumber }) else { continue }
      let total = ud.integer(forKey: key)
      let typesKey = Self.typesKeyPrefix + dateISO
      let typesStr = ud.string(forKey: typesKey) ?? ""
      let types = typesStr.isEmpty ? [] : typesStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
      guard let date = dateFormatter.date(from: dateISO) else { continue }
      let displayDate = displayFormatter.string(from: date)
      result.append(DayEntry(id: dateISO, dateISO: dateISO, totalCalories: total, types: types, displayDate: displayDate))
    }
    return result.sorted { $0.dateISO > $1.dateISO }
  }
  
  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        
        if entries.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "flame")
              .font(.system(size: 48))
              .foregroundColor(.orange.opacity(0.8))
            Text(Localization.shared.tr("activities.stats.empty", default: "No activity data yet"))
              .font(.headline)
              .foregroundColor(AppTheme.textPrimary)
            Text(Localization.shared.tr("activities.stats.empty.hint", default: "Track activities to see burned calories here."))
              .font(.subheadline)
              .foregroundColor(AppTheme.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
        } else {
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(entries) { entry in
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayDate)
                      .font(.subheadline.bold())
                      .foregroundColor(AppTheme.textPrimary)
                    if !entry.types.isEmpty {
                      Text(entry.types.map { activityDisplayName($0) }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    }
                  }
                  Spacer()
                  Text("\(entry.totalCalories) kcal")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
                }
                .padding()
                .background(AppTheme.surface)
                .cornerRadius(12)
              }
            }
            .padding()
          }
        }
      }
      .navigationTitle(Localization.shared.tr("activities.stats.title", default: "Activity Statistics"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(Localization.shared.tr("common.close", default: "Close")) {
            isPresented = false
          }
          .foregroundColor(AppTheme.textPrimary)
        }
      }
    }
  }
  
  private func activityDisplayName(_ key: String) -> String {
    switch key {
    case "gym": return Localization.shared.tr("activities.gym", default: "Gym")
    case "steps": return Localization.shared.tr("activities.steps", default: "Steps")
    case "treadmill": return Localization.shared.tr("activities.treadmill", default: "Treadmill")
    case "elliptical": return Localization.shared.tr("activities.elliptical", default: "Elliptical")
    case "yoga": return Localization.shared.tr("activities.yoga", default: "Yoga")
    case "chess": return Localization.shared.tr("activities.chess.name", default: "Chess")
    default: return key.capitalized
    }
  }
}

#Preview {
  ActivityStatisticsView(isPresented: .constant(true))
}
