import Charts
import SwiftUI

struct StatisticsView: View {
  @Binding var isPresented: Bool
  @State private var selectedPeriod: StatisticsPeriod = .week
  @State private var statistics: [DailyStatistics] = []
  @State private var isLoading = false
  @State private var selectedDay: DailyStatistics?
  @State private var showGraphs = false

  private let statisticsService = StatisticsService.shared
  private let visiblePeriods: [StatisticsPeriod] = [.week, .month]

  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient.edgesIgnoringSafeArea(.all)

        if isLoading {
          VStack {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.textPrimary))
              .scaleEffect(1.5)
            Text(loc("stats.loading", "Loading statistics..."))
              .foregroundColor(AppTheme.textPrimary)
              .padding(.top)
          }
        } else {
          ScrollView {
            VStack(spacing: 14) {
              periodSelectionView
              if loggedDays.isEmpty {
                EmptyStateView(
                  systemImage: "chart.line.uptrend.xyaxis",
                  title: loc("stats.hero.empty", "Start this week"),
                  subtitle: loc(
                    "stats.hero.empty.body", "Log a meal to see how you are doing.")
                )
              } else {
                heroCard
                energyCard
                if !weightDays.isEmpty {
                  bodyCard
                }
                plateCard
                proteinCard
                consistencyRow
              }
              openGraphsButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
          }
        }
      }
      .navigationTitle(loc("nav.statistics", "Statistics"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(loc("common.close", "Close")) {
            isPresented = false
          }
          .foregroundColor(AppTheme.textPrimary)
        }
      }
      .onAppear { loadData() }
      .sheet(item: $selectedDay) { day in
        dayDetailSheet(day)
      }
      .sheet(isPresented: $showGraphs) {
        StatisticsGraphsView(isPresented: $showGraphs, initialPeriod: selectedPeriod)
      }
    }
    .environment(\.locale, Locale(identifier: LanguageService.shared.currentCode))
    .simultaneousGesture(
      DragGesture(minimumDistance: 40)
        .onEnded { value in
          let dx = value.translation.width
          let dy = value.translation.height
          guard abs(dx) > abs(dy), dx > 70 else { return }
          HapticsService.shared.select()
          isPresented = false
        }
    )
  }

  // MARK: - Data

  private var loggedDays: [DailyStatistics] {
    statistics.filter { $0.hasData }
  }

  private var weightDays: [DailyStatistics] {
    statistics.filter { $0.personWeight > 0 }
  }

  private var scoredDays: [DailyStatistics] {
    statistics.filter { $0.averageHealthScore != nil }
  }

  private var calorieTarget: Int {
    let stored = CalorieLimitsStorageService.shared.load()?.softLimit
      ?? UserDefaults.standard.integer(forKey: "softLimit")
    return stored > 0 ? stored : 0
  }

  private var proteinTarget: Double {
    if let custom = CalorieLimitsStorageService.shared.load()?.customProteinGoal {
      return custom
    }
    guard calorieTarget > 0 else { return 80 }
    return (Double(calorieTarget) * 0.20) / 4.0
  }

  private var goalMode: String {
    UserDefaults.standard.string(forKey: "userGoalMode") ?? "maintain"
  }

  private var targetWeightKg: Double {
    UserDefaults.standard.double(forKey: "userTargetWeight")
  }

  private var daysInCalorieRange: Int {
    guard calorieTarget > 0 else { return 0 }
    return loggedDays.filter { isInCalorieRange($0.totalCalories) }.count
  }

  private var daysOverCalories: Int {
    guard calorieTarget > 0 else { return 0 }
    return loggedDays.filter { Double($0.totalCalories) > Double(calorieTarget) * 1.1 }.count
  }

  private var averageCalories: Int {
    guard !loggedDays.isEmpty else { return 0 }
    return loggedDays.reduce(0) { $0 + $1.totalCalories } / loggedDays.count
  }

  private var averageProtein: Double {
    guard !loggedDays.isEmpty else { return 0 }
    return loggedDays.reduce(0) { $0 + $1.proteins } / Double(loggedDays.count)
  }

  private var weekHealthScore: Int? {
    let scores = scoredDays.compactMap { $0.averageHealthScore }
    guard !scores.isEmpty else { return nil }
    return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
  }

  private var latestWeight: DailyStatistics? {
    weightDays.max(by: { $0.date < $1.date })
  }

  private var firstWeight: DailyStatistics? {
    weightDays.min(by: { $0.date < $1.date })
  }

  private var todayLogged: Bool {
    loggedDays.contains { Calendar.current.isDateInToday($0.date) }
  }

  private func isInCalorieRange(_ kcal: Int) -> Bool {
    guard calorieTarget > 0 else { return false }
    let ratio = Double(kcal) / Double(calorieTarget)
    return ratio >= 0.9 && ratio <= 1.1
  }

  // MARK: - Period

  private var periodSelectionView: some View {
    Picker("", selection: $selectedPeriod) {
      ForEach(visiblePeriods, id: \.self) { period in
        Text(localizedPeriod(period)).tag(period)
      }
    }
    .pickerStyle(SegmentedPickerStyle())
    .onChange(of: selectedPeriod) { _, _ in
      loadData()
    }
  }

  private func localizedPeriod(_ period: StatisticsPeriod) -> String {
    switch period {
    case .week:
      return loc("stats.period.week", "This week")
    case .month:
      return loc("stats.period.month", "30 days")
    case .twoMonths, .threeMonths:
      return period.rawValue
    }
  }

  // MARK: - Hero

  private var heroCard: some View {
    let copy = heroCopy
    return VStack(alignment: .leading, spacing: 8) {
      Text(copy.title)
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(AppTheme.textPrimary)
      Text(copy.body)
        .font(.subheadline)
        .foregroundColor(AppTheme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Text(copy.action)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(AppTheme.accent)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardContainer(padding: 16)
  }

  private var heroCopy: (title: String, body: String, action: String) {
    let days = statistics.count
    let logged = loggedDays.count

    if logged == 0 {
      return (
        loc("stats.hero.empty", "Start this week"),
        loc("stats.hero.empty.body", "Log a meal to see how you are doing."),
        loc("stats.hero.action.log", "Next: log today's meal")
      )
    }

    if !todayLogged {
      return (
        loc("stats.hero.mixed", "This week is mixed"),
        loc("stats.hero.log_today", "Log today's meal to keep the streak."),
        loc("stats.hero.action.log", "Next: log today's meal")
      )
    }

    let proteinLow = proteinTarget > 0 && averageProtein < proteinTarget * 0.8
    let mostlyOver = calorieTarget > 0 && daysOverCalories * 2 >= logged
    let mostlyInRange = calorieTarget > 0 && daysInCalorieRange * 2 >= logged
    let platesGood = (weekHealthScore ?? 0) >= 80

    if mostlyOver {
      return (
        loc("stats.hero.off_track", "A bit off track"),
        String(
          format: loc(
            "stats.hero.over",
            "You went over calories on %d days. Tomorrow keep lunch and skip the late snack."),
          daysOverCalories),
        loc("stats.hero.action.calories", "Next: stay in your calorie band")
      )
    }

    if proteinLow && (mostlyInRange || calorieTarget == 0) {
      return (
        loc("stats.hero.mixed", "This week is mixed"),
        loc(
          "stats.hero.protein_low",
          "Calories are fine. Protein is low. Add eggs, yogurt, or chicken tomorrow."),
        loc("stats.hero.action.protein", "Next: more protein tomorrow")
      )
    }

    if platesGood && mostlyInRange {
      return (
        loc("stats.hero.on_track", "Closer to your goal"),
        loc(
          "stats.hero.plates_good",
          "Your plates this week look balanced. That is the habit to keep."),
        loc("stats.hero.action.keep", "Next: repeat a high-score plate")
      )
    }

    if mostlyInRange {
      return (
        loc("stats.hero.on_track", "Closer to your goal"),
        String(
          format: loc(
            "stats.hero.in_range",
            "You stayed near your calorie target on %d of %d days. Keep it up."),
          daysInCalorieRange, logged),
        loc("stats.hero.action.keep", "Next: repeat a high-score plate")
      )
    }

    if weightDays.isEmpty && targetWeightKg > 0 {
      return (
        loc("stats.hero.mixed", "This week is mixed"),
        loc(
          "stats.hero.weigh_in",
          "Add a weigh-in to see if your body is moving the right way."),
        loc("stats.hero.action.weight", "Next: weigh in")
      )
    }

    _ = days
    return (
      loc("stats.hero.mixed", "This week is mixed"),
      String(
        format: loc("stats.consistency.format", "Logged %d of %d days"), logged, days),
      loc("stats.hero.action.calories", "Next: stay in your calorie band")
    )
  }

  // MARK: - Energy

  private var energyCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(loc("stats.card.energy", "Energy"))
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)

      if selectedPeriod == .week {
        weekDots
      }

      Chart {
        ForEach(loggedDays) { stat in
          LineMark(
            x: .value(loc("stats.axis.date", "Date"), stat.date),
            y: .value(loc("stats.axis.calories", "Calories"), stat.totalCalories)
          )
          .foregroundStyle(AppTheme.accent)
          .lineStyle(StrokeStyle(lineWidth: 2))

          PointMark(
            x: .value(loc("stats.axis.date", "Date"), stat.date),
            y: .value(loc("stats.axis.calories", "Calories"), stat.totalCalories)
          )
          .foregroundStyle(calorieDotColor(stat.totalCalories))
          .symbolSize(60)
        }

        if calorieTarget > 0 {
          RuleMark(y: .value(loc("stats.axis.goal", "Goal"), calorieTarget))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
        }
      }
      .chartXAxis {
        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
          AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
            .foregroundStyle(Color.gray.opacity(0.3))
          AxisValueLabel()
            .foregroundStyle(AppTheme.textPrimary)
            .font(.caption2)
        }
      }
      .chartYAxis {
        AxisMarks { _ in
          AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
            .foregroundStyle(Color.gray.opacity(0.3))
          AxisValueLabel()
            .foregroundStyle(AppTheme.textPrimary)
            .font(.caption2)
        }
      }
      .frame(height: 160)
      .animation(
        AppSettingsService.shared.reduceMotion ? .none : .easeInOut(duration: 0.25),
        value: loggedDays)
      .chartOverlay { proxy in
        GeometryReader { geo in
          Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { location in
              selectDay(at: location, proxy: proxy, geo: geo)
            }
        }
      }

      Text(energyCaption)
        .font(.caption)
        .foregroundColor(AppTheme.textSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardContainer(padding: 16)
  }

  private var weekDots: some View {
    HStack(spacing: 8) {
      ForEach(statistics) { stat in
        VStack(spacing: 4) {
          Circle()
            .fill(dotColor(stat))
            .frame(width: 14, height: 14)
          Text(shortWeekday(stat.date))
            .font(.caption2)
            .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
          guard stat.hasData else { return }
          HapticsService.shared.select()
          selectedDay = stat
        }
      }
    }
  }

  private var energyCaption: String {
    if calorieTarget > 0 {
      return String(
        format: loc(
          "stats.energy.caption",
          "In range %d of %d days · avg %d / %d kcal"),
        daysInCalorieRange, loggedDays.count, averageCalories, calorieTarget)
    }
    return String(
      format: loc("stats.energy.no_target", "Avg %d kcal/day"), averageCalories)
  }

  // MARK: - Body

  private var bodyCard: some View {
    let latest = latestWeight
    let first = firstWeight
    let delta: Double = {
      guard let latest, let first else { return 0 }
      return Double(latest.personWeight - first.personWeight)
    }()

    return VStack(alignment: .leading, spacing: 12) {
      Text(loc("stats.card.body", "Body"))
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)

      if let latest {
        if targetWeightKg > 0 {
          Text(
            String(
              format: loc("stats.body.latest_format", "%.1f kg · target %.1f kg"),
              latest.personWeight, targetWeightKg)
          )
          .font(.title3)
          .fontWeight(.semibold)
          .foregroundColor(AppTheme.textPrimary)
        } else {
          Text(
            String(
              format: loc("stats.body.no_target", "Latest %.1f kg"), latest.personWeight)
          )
          .font(.title3)
          .fontWeight(.semibold)
          .foregroundColor(AppTheme.textPrimary)
        }

        if weightDays.count >= 2 {
          Text(weightDeltaCopy(delta))
            .font(.caption)
            .foregroundColor(weightDeltaColor(delta))
        }
      }

      if weightDays.count >= 2 {
        Chart(weightDays) { stat in
          LineMark(
            x: .value(loc("stats.axis.date", "Date"), stat.date),
            y: .value(loc("stats.axis.weight", "Weight"), stat.personWeight)
          )
          .foregroundStyle(AppTheme.success)
          .lineStyle(StrokeStyle(lineWidth: 2))
          PointMark(
            x: .value(loc("stats.axis.date", "Date"), stat.date),
            y: .value(loc("stats.axis.weight", "Weight"), stat.personWeight)
          )
          .foregroundStyle(AppTheme.success)
        }
        .chartXAxis {
          AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisValueLabel()
              .foregroundStyle(AppTheme.textPrimary)
              .font(.caption2)
          }
        }
        .chartYAxis {
          AxisMarks { _ in
            AxisValueLabel()
              .foregroundStyle(AppTheme.textPrimary)
              .font(.caption2)
          }
        }
        .frame(height: 120)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardContainer(padding: 16)
  }

  private func weightDeltaCopy(_ delta: Double) -> String {
    let absDelta = abs(delta)
    let towardTarget: Bool = {
      guard let latest = latestWeight, targetWeightKg > 0 else { return delta <= 0 }
      let before = abs(Double(firstWeight?.personWeight ?? latest.personWeight) - targetWeightKg)
      let after = abs(Double(latest.personWeight) - targetWeightKg)
      return after <= before
    }()

    if goalMode == "lose" {
      if delta < -0.05 {
        return String(
          format: loc("stats.body.delta_down", "%.1f kg this period, on track"), absDelta)
      }
      if delta > 0.05 {
        return String(format: loc("stats.body.delta_up", "+%.1f kg this period"), absDelta)
      }
    } else if goalMode == "gain" {
      if delta > 0.05 && towardTarget {
        return String(
          format: loc("stats.body.delta_down", "%.1f kg this period, on track"), absDelta)
      }
      if delta < -0.05 {
        return String(format: loc("stats.body.delta_up", "+%.1f kg this period"), absDelta)
          .replacingOccurrences(of: "+", with: "")
      }
    }

    if towardTarget {
      return String(
        format: loc("stats.body.delta_down", "%.1f kg this period, on track"), absDelta)
    }
    return String(format: loc("stats.body.delta_up", "+%.1f kg this period"), absDelta)
  }

  private func weightDeltaColor(_ delta: Double) -> Color {
    guard let latest = latestWeight, targetWeightKg > 0 else {
      if goalMode == "lose" { return delta < 0 ? AppTheme.success : AppTheme.warning }
      if goalMode == "gain" { return delta > 0 ? AppTheme.success : AppTheme.warning }
      return AppTheme.textSecondary
    }
    let before = abs(Double(firstWeight?.personWeight ?? latest.personWeight) - targetWeightKg)
    let after = abs(Double(latest.personWeight) - targetWeightKg)
    return after <= before ? AppTheme.success : AppTheme.warning
  }

  // MARK: - Plate

  private var plateCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(loc("stats.card.plate", "Plate"))
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)

      if let score = weekHealthScore {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("\(score)")
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundColor(healthScoreColor(score))
          VStack(alignment: .leading, spacing: 2) {
            Text(loc("health.score.value.label", "Today's Score"))
              .font(.caption)
              .foregroundColor(AppTheme.textSecondary)
            Text(scoreBandLabel(score))
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(AppTheme.textPrimary)
          }
        }

        if scoredDays.count >= 2 {
          Chart(scoredDays) { stat in
            LineMark(
              x: .value(loc("stats.axis.date", "Date"), stat.date),
              y: .value(loc("stats.card.plate", "Plate"), stat.averageHealthScore ?? 0)
            )
            .foregroundStyle(healthScoreColor(stat.averageHealthScore ?? 0))
            PointMark(
              x: .value(loc("stats.axis.date", "Date"), stat.date),
              y: .value(loc("stats.card.plate", "Plate"), stat.averageHealthScore ?? 0)
            )
            .foregroundStyle(healthScoreColor(stat.averageHealthScore ?? 0))
          }
          .chartYScale(domain: 0...100)
          .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
              AxisValueLabel()
                .foregroundStyle(AppTheme.textPrimary)
                .font(.caption2)
            }
          }
          .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { _ in
              AxisValueLabel()
                .foregroundStyle(AppTheme.textPrimary)
                .font(.caption2)
            }
          }
          .frame(height: 100)
        }
      } else {
        Text(loc("stats.plate.empty", "Log meals to see your plate score this week."))
          .font(.subheadline)
          .foregroundColor(AppTheme.textSecondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardContainer(padding: 16)
  }

  // MARK: - Protein / consistency

  private var proteinCard: some View {
    let met = proteinTarget > 0 && averageProtein >= proteinTarget * 0.8
    return VStack(alignment: .leading, spacing: 8) {
      Text(loc("stats.card.protein", "Protein"))
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)
      HStack {
        Text(
          String(
            format: loc("stats.protein.caption", "%d / %d g per day"),
            Int(averageProtein.rounded()), Int(proteinTarget.rounded()))
        )
        .font(.subheadline)
        .foregroundColor(AppTheme.textPrimary)
        Spacer()
        Circle()
          .fill(met ? AppTheme.success : AppTheme.warning)
          .frame(width: 10, height: 10)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardContainer(padding: 16)
  }

  private var consistencyRow: some View {
    Text(
      String(
        format: loc("stats.consistency.format", "Logged %d of %d days"),
        loggedDays.count, statistics.count)
    )
    .font(.footnote)
    .foregroundColor(AppTheme.textSecondary)
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.top, 4)
  }

  private var openGraphsButton: some View {
    Button {
      HapticsService.shared.select()
      showGraphs = true
    } label: {
      Label(loc("stats.open_graphs", "View graphs"), systemImage: "chart.xyaxis.line")
        .font(.headline)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(SecondaryButtonStyle())
    .padding(.top, 8)
    .accessibilityHint(loc("stats.open_graphs.hint", "Opens the detailed statistics graphs"))
  }

  // MARK: - Day detail

  private func dayDetailSheet(_ day: DailyStatistics) -> some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 16) {
        Text(mediumDate(day.date))
          .font(.title3)
          .fontWeight(.semibold)
          .foregroundColor(AppTheme.textPrimary)

        if calorieTarget > 0 {
          HStack {
            Text("\(day.totalCalories) / \(calorieTarget) \(loc("units.kcal", "kcal"))")
              .foregroundColor(AppTheme.textPrimary)
            Text(calorieStatusLabel(day.totalCalories))
              .font(.caption)
              .foregroundColor(calorieDotColor(day.totalCalories))
          }
        } else {
          Text("\(day.totalCalories) \(loc("units.kcal", "kcal"))")
            .foregroundColor(AppTheme.textPrimary)
        }

        Text(
          String(
            format: loc("stats.day.meals", "%d meals"), day.numberOfMeals)
        )
        .foregroundColor(AppTheme.textSecondary)

        if let score = day.averageHealthScore {
          Text(
            "\(loc("stats.card.plate", "Plate")) \(score) · \(scoreBandLabel(score))"
          )
          .foregroundColor(healthScoreColor(score))
        }

        Spacer()
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.backgroundGradient.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(loc("common.done", "Done")) {
            selectedDay = nil
          }
          .foregroundColor(AppTheme.textPrimary)
        }
      }
    }
    .presentationDetents([.medium])
  }

  // MARK: - Helpers

  private func selectDay(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
    let plotFrame = geo[proxy.plotFrame!]
    let x = location.x - plotFrame.origin.x
    guard let date: Date = proxy.value(atX: x) else { return }
    let match = loggedDays.min {
      abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
    }
    guard let match else { return }
    HapticsService.shared.select()
    selectedDay = match
  }

  private func calorieDotColor(_ kcal: Int) -> Color {
    guard calorieTarget > 0 else { return AppTheme.accent }
    if isInCalorieRange(kcal) { return AppTheme.success }
    if Double(kcal) > Double(calorieTarget) * 1.1 { return AppTheme.danger }
    return AppTheme.warning
  }

  private func calorieStatusLabel(_ kcal: Int) -> String {
    guard calorieTarget > 0 else { return "" }
    if isInCalorieRange(kcal) { return loc("stats.day.on_target", "on target") }
    if Double(kcal) > Double(calorieTarget) { return loc("stats.day.over", "over") }
    return loc("stats.day.under", "under")
  }

  private func dotColor(_ stat: DailyStatistics) -> Color {
    if !stat.hasData { return AppTheme.textSecondary.opacity(0.25) }
    return calorieDotColor(stat.totalCalories)
  }

  private func shortWeekday(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: LanguageService.shared.currentCode)
    formatter.dateFormat = "EEEEE"
    return formatter.string(from: date)
  }

  private func mediumDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: LanguageService.shared.currentCode)
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }

  private func healthScoreColor(_ rating: Int) -> Color {
    switch rating {
    case 0..<40: return Color(red: 1.0, green: 0.0, blue: 0.0)
    case 40..<60: return Color(red: 1.0, green: 0.6, blue: 0.0)
    case 60..<80: return Color(red: 0.85, green: 0.7, blue: 0.0)
    case 80..<95: return Color(red: 0.5, green: 0.9, blue: 0.3)
    default: return Color(red: 0.0, green: 1.0, blue: 0.0)
    }
  }

  private func scoreBandLabel(_ score: Int) -> String {
    switch score {
    case 0..<40: return loc("health.score.band.poor", "Needs Improvement")
    case 40..<60: return loc("health.score.band.low", "Fair")
    case 60..<80: return loc("health.score.band.fair", "Good")
    case 80..<95: return loc("health.score.band.good", "Very Good")
    default: return loc("health.score.band.great", "Excellent")
    }
  }

  private func loadData() {
    isLoading = true
    statisticsService.fetchStatisticsForPeriod(period: selectedPeriod) { fetchedStats in
      DispatchQueue.main.async {
        self.statistics = fetchedStats
        self.isLoading = false
      }
    }
  }
}

#Preview {
  StatisticsView(isPresented: .constant(true))
}
