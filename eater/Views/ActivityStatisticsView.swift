import SwiftUI

/// Living Orbs: behavior visualization — central core (user) + orbs (activities).
/// Orb size = frequency, distance = consistency, no overlap, subtle motion.
struct ActivityStatisticsView: View {
  @Binding var isPresented: Bool
  @StateObject private var themeService = ThemeService.shared
  @State private var selectedActivity: String? = nil
  @State private var timeRange: TimeRange = .week
  @State private var showDogRecommendation: Bool = false
  
  private static let mjSongs: [(song: String, album: String)] = [
    ("Billie Jean", "Thriller"),
    ("Beat It", "Thriller"),
    ("Smooth Criminal", "Bad"),
    ("Black or White", "Dangerous"),
    ("Man in the Mirror", "Bad"),
    ("The Way You Make Me Feel", "Bad"),
    ("Don't Stop 'Til You Get Enough", "Off the Wall"),
    ("Rock With You", "Off the Wall"),
    ("Remember the Time", "Dangerous"),
    ("Heal the World", "Dangerous"),
    ("Wanna Be Startin' Somethin'", "Thriller"),
    ("Human Nature", "Thriller"),
  ]
  
  private var todaysMJRecommendation: (song: String, album: String) {
    let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    let index = (day - 1) % Self.mjSongs.count
    return Self.mjSongs[index]
  }
  
  enum TimeRange: String, CaseIterable {
    case day = "1 Day"
    case week = "1 Week"
    case month = "1 Month"
    case threeMonths = "3 Months"
    
    var calendarComponent: Calendar.Component {
      switch self {
      case .day: return .day
      case .week: return .weekOfYear
      case .month: return .month
      case .threeMonths: return .month
      }
    }
    
    var value: Int {
      switch self {
      case .day: return 1
      case .week: return 1
      case .month: return 1
      case .threeMonths: return 3
      }
    }
  }
  
  private static let totalKeyPrefix = "activity_summary_total_"
  private static let typesKeyPrefix = "activity_summary_types_"
  private static let activityOrder = ["gym", "steps", "treadmill", "elliptical", "yoga", "chess"]
  
  private struct DayEntry: Identifiable {
    let id: String
    let dateISO: String
    let date: Date
    let totalCalories: Int
    let types: [String]
    let displayDate: String
  }
  
  private var allEntries: [DayEntry] {
    let ud = UserDefaults.standard
    let all = ud.dictionaryRepresentation()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
    let displayFormatter = DateFormatter()
    displayFormatter.dateStyle = .medium
    displayFormatter.timeZone = TimeZone(identifier: "UTC")
    
    var result: [DayEntry] = []
    for (key, _) in all {
      guard key.hasPrefix(Self.totalKeyPrefix) else { continue }
      let dateISO = String(key.dropFirst(Self.totalKeyPrefix.count))
      guard dateISO.count == 10, dateISO.allSatisfy({ $0 == "-" || $0.isNumber }) else { continue }
      guard let date = dateFormatter.date(from: dateISO) else { continue }
      let total = ud.integer(forKey: key)
      let typesKey = Self.typesKeyPrefix + dateISO
      let typesStr = ud.string(forKey: typesKey) ?? ""
      let types = typesStr.isEmpty ? [] : typesStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
      result.append(DayEntry(
        id: dateISO,
        dateISO: dateISO,
        date: date,
        totalCalories: total,
        types: types,
        displayDate: displayFormatter.string(from: date)
      ))
    }
    return result.sorted { $0.date > $1.date }
  }
  
  private func entries(in range: TimeRange) -> [DayEntry] {
    let now = Date()
    let cal = Calendar.current
    guard let start = cal.date(byAdding: range.calendarComponent, value: -range.value, to: now) else { return [] }
    return allEntries.filter { $0.date >= start && $0.date <= now }
  }
  
  private var filteredEntries: [DayEntry] { entries(in: timeRange) }
  
  private var totalDaysInRange: Int {
    let now = Date()
    let cal = Calendar.current
    switch timeRange {
    case .day: return 1
    case .week: return 7
    case .month: return cal.range(of: .day, in: .month, for: now)?.count ?? 30
    case .threeMonths: return 90
    }
  }
  
  struct OrbData: Identifiable {
    let id: String
    let key: String
    let sessions: Int
    let consistency: Double
    let percentage: Int
  }
  
  private var orbDataList: [OrbData] {
    let entries = filteredEntries
    let totalSessions = entries.reduce(0) { $0 + $1.types.count }
    var sessionsPer: [String: Int] = [:]
    for e in entries {
      for t in e.types {
        sessionsPer[t, default: 0] += 1
      }
    }
    let daysInRange = max(1, totalDaysInRange)
    return Self.activityOrder.map { key in
      let sessions = sessionsPer[key] ?? 0
      let consistency = sessions > 0 ? min(1, Double(sessions) / Double(daysInRange)) : 0
      let pct = totalSessions > 0 && sessions > 0 ? Int(round(Double(sessions) / Double(totalSessions) * 100)) : 0
      return OrbData(id: key, key: key, sessions: sessions, consistency: consistency, percentage: pct)
    }
  }
  
  private static let statsBackgroundGradient: LinearGradient = LinearGradient(
    colors: [
      Color(red: 0.07, green: 0.05, blue: 0.12),
      Color(red: 0.06, green: 0.07, blue: 0.11),
      Color(red: 0.05, green: 0.09, blue: 0.11)
    ],
    startPoint: .top,
    endPoint: .center
  )
  
  private static let statsBottomGlow: LinearGradient = LinearGradient(
    colors: [
      Color.clear,
      Color(red: 0.12, green: 0.28, blue: 0.32).opacity(0.35),
      Color(red: 0.18, green: 0.38, blue: 0.42).opacity(0.6)
    ],
    startPoint: .center,
    endPoint: .bottom
  )
  
  var body: some View {
    statsNavigationContent
  }
  
  private var statsNavigationContent: some View {
    NavigationView {
      statsRootStack
    }
    .navigationTitle(Localization.shared.tr("activities.stats.title", default: "Activity Statistics"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(Localization.shared.tr("common.done", default: "Done")) {
          isPresented = false
        }
        .foregroundColor(AppTheme.textPrimary)
      }
    }
  }
  
  @ViewBuilder
  private var statsRootStack: some View {
    ZStack {
      Self.statsBackgroundGradient.ignoresSafeArea()
      Self.statsBottomGlow.ignoresSafeArea()
      if allEntries.isEmpty {
        emptyView
      } else {
        statsContentStack
      }
    }
  }
  
  private var statsContentStack: some View {
    ZStack {
      statsMainColumn
      statsTapToDismissOverlay
      statsOrbInfoOverlay
    }
    .animation(.easeInOut(duration: 0.28), value: selectedActivity)
    .animation(.easeInOut(duration: 0.4), value: timeRange)
    .animation(.easeInOut(duration: 0.28), value: showDogRecommendation)
  }
  
  private var statsMainColumn: some View {
    let centralImage: String? = themeService.currentMascot == .dog ? "stats_dog_gym" : (themeService.currentMascot == .cat ? AppMascot.cat.happyImage() : nil)
    return VStack(spacing: 0) {
      timeRangePicker
      LivingOrbsView(
        orbData: orbDataList,
        selectedActivity: $selectedActivity,
        timeRange: timeRange,
        centralImageName: centralImage,
        onCentralTap: themeService.currentMascot == .dog ? { showDogRecommendation = true } : nil
      )
      if showDogRecommendation {
        mjRecommendationCard
          .padding(.horizontal, 24)
          .padding(.bottom, 16)
          .transition(.opacity.combined(with: .scale(scale: 0.96)))
      }
    }
  }
  
  @ViewBuilder
  private var statsTapToDismissOverlay: some View {
    if selectedActivity != nil {
      Color.clear
        .contentShape(Rectangle())
        .ignoresSafeArea()
        .onTapGesture {
          withAnimation(.easeInOut(duration: 0.25)) { selectedActivity = nil }
        }
    }
  }
  
  @ViewBuilder
  private var statsOrbInfoOverlay: some View {
    if let key = selectedActivity, let orb = orbDataList.first(where: { $0.key == key }) {
      orbInfoCard(orb)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .gesture(
          DragGesture(minimumDistance: 20)
            .onEnded { value in
              if value.translation.height > 50 {
                withAnimation(.easeOut(duration: 0.25)) { selectedActivity = nil }
              }
            }
        )
    }
  }
  
  private var mjRecommendationCard: some View {
    let rec = todaysMJRecommendation
    return VStack(spacing: 8) {
      Text(Localization.shared.tr("activities.stats.dog.recommendation.title", default: "Today's top pick"))
        .font(.caption)
        .foregroundColor(AppTheme.textSecondary)
      Text(rec.song)
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)
      Text(rec.album)
        .font(.subheadline)
        .foregroundColor(AppTheme.accent)
      Text("Michael Jackson")
        .font(.caption)
        .foregroundColor(AppTheme.textSecondary)
      Text(Localization.shared.tr("activities.stats.dog.recommendation.gym", default: "Great to run to at the gym"))
        .font(.caption)
        .foregroundColor(AppTheme.textSecondary)
        .italic()
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(AppTheme.surface)
    .cornerRadius(12)
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.28)) { showDogRecommendation = false }
    }
  }
  
  private var timeRangeBinding: Binding<TimeRange> {
    Binding(
      get: { timeRange },
      set: { newValue in
        withAnimation(.easeInOut(duration: 0.32)) { timeRange = newValue }
      }
    )
  }
  
  private var timeRangePicker: some View {
    Picker("", selection: timeRangeBinding) {
      ForEach(TimeRange.allCases, id: \.self) { r in
        Text(Localization.shared.tr("activities.stats.range.\(r.rawValue.replacingOccurrences(of: " ", with: "_"))", default: r.rawValue))
          .tag(r)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .animation(.easeInOut(duration: 0.32), value: timeRange)
  }
  
  private func orbInfoCard(_ orb: OrbData) -> some View {
    VStack(spacing: 6) {
      Text(activityDisplayName(orb.key))
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)
      Text("\(orb.sessions) \(Localization.shared.tr("activities.stats.sessions", default: "sessions"))")
        .font(.subheadline)
        .foregroundColor(AppTheme.textSecondary)
      Text("\(orb.percentage)% \(Localization.shared.tr("activities.stats.of.activities", default: "of your activities"))")
        .font(.caption)
        .foregroundColor(activityColor(orb.key))
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(AppTheme.surface)
    .cornerRadius(12)
  }
  
  private var emptyView: some View {
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
  }
  
  private func activityColor(_ key: String) -> Color {
    switch key {
    case "gym": return .orange
    case "steps": return .green
    case "treadmill": return .blue
    case "elliptical": return .purple
    case "yoga": return Color(red: 0.4, green: 0.6, blue: 0.5)
    case "chess": return .purple.opacity(0.9)
    default: return .gray
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
