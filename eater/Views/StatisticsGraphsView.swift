import Charts
import SwiftUI

/// Existing statistics graphs, kept as a detail screen from the new week overview.
/// Charts use current Swift Charts selection, scrolling, interpolation, and iOS 26 glass on controls.
struct StatisticsGraphsView: View {
  @Binding var isPresented: Bool
  var initialPeriod: StatisticsPeriod = .week

  @State private var selectedPeriod: StatisticsPeriod = .week
  @State private var statistics: [DailyStatistics] = []
  @State private var isLoading = false
  @State private var selectedChart: ChartType = .calories
  @State private var selectedDate: Date?
  @State private var scrollDate: Date = Date()

  private let statisticsService = StatisticsService.shared

  enum ChartType: String, CaseIterable {
    case insights
    case calories
    case macros
    case personWeight
    case foodWeight
    case trends
  }

  private var plottedDays: [DailyStatistics] {
    statistics.filter { $0.hasData }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()

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
          VStack(spacing: 0) {
            periodSelectionView
              .padding(.horizontal, 16)
              .padding(.top, 8)

            chartTypeSelectionView
              .padding(.vertical, 8)

            ScrollView {
              chartView
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            if selectedChart != .insights && selectedChart != .trends {
              summaryStatsView
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
          }
        }
      }
      .navigationTitle(loc("stats.graphs.title", "Graphs"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(loc("common.done", "Done")) {
            isPresented = false
          }
          .foregroundColor(AppTheme.textPrimary)
        }
      }
      .onAppear {
        selectedPeriod = initialPeriod
        loadData()
      }
      .sensoryFeedback(.selection, trigger: selectedChart)
      .sensoryFeedback(.selection, trigger: selectedDate)
    }
    .environment(\.locale, Locale(identifier: LanguageService.shared.currentCode))
  }

  private func localizedChartTypeName(_ type: ChartType) -> String {
    switch type {
    case .insights: return loc("stats.chart.insights", "Insights")
    case .calories: return loc("stats.chart.calories", "Calories")
    case .macros: return loc("stats.chart.macros", "Macronutrients")
    case .personWeight: return loc("stats.chart.personweight", "Body Weight")
    case .foodWeight: return loc("stats.chart.foodweight", "Food Weight")
    case .trends: return loc("stats.chart.trends", "Trends")
    }
  }

  private func localizedPeriod(_ period: StatisticsPeriod) -> String {
    switch period {
    case .week: return loc("stats.period.week", "This week")
    case .month: return loc("stats.period.month", "30 days")
    case .twoMonths: return loc("stats.period.two_months", "2 months")
    case .threeMonths: return loc("stats.period.three_months", "3 months")
    }
  }

  private var periodSelectionView: some View {
    Picker("Period", selection: $selectedPeriod) {
      ForEach(StatisticsPeriod.allCases, id: \.self) { period in
        Text(localizedPeriod(period)).tag(period)
      }
    }
    .pickerStyle(.segmented)
    .onChange(of: selectedPeriod) { _, _ in
      selectedDate = nil
      loadData()
    }
    .modifier(ControlGlass())
  }

  private var chartTypeSelectionView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(ChartType.allCases, id: \.self) { chartType in
          Button {
            withAnimation(.snappy(duration: 0.25)) {
              selectedChart = chartType
              selectedDate = nil
            }
          } label: {
            Text(localizedChartTypeName(chartType))
              .font(.caption)
              .fontWeight(.semibold)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .foregroundColor(
                selectedChart == chartType
                  ? Color.black.opacity(0.9) : AppTheme.textPrimary)
          }
          .buttonStyle(.plain)
          .modifier(ChipGlass(selected: selectedChart == chartType))
        }
      }
      .padding(.horizontal, 16)
    }
    .frame(height: 44)
  }

  @ViewBuilder
  private var chartView: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch selectedChart {
      case .calories:
        caloriesChart
      case .personWeight:
        personWeightChart
      case .foodWeight:
        foodWeightChart
      case .macros:
        macronutrientsChart
      case .trends:
        trendsView
      case .insights:
        insightsView
      }
    }
    .padding(12)
    .modifier(ChartCardGlass())
  }

  // MARK: - Calories

  private var caloriesChart: some View {
    let days = plottedDays
    return interactiveTimeChart(days: days, yLabel: loc("stats.axis.calories", "Calories")) {
      ForEach(days, id: \.dateString) { stat in
        AreaMark(
          x: .value(loc("stats.axis.date", "Date"), stat.date, unit: .day),
          y: .value(loc("stats.axis.calories", "Calories"), stat.totalCalories)
        )
        .interpolationMethod(.monotone)
        .foregroundStyle(
          LinearGradient(
            colors: [Color.orange.opacity(0.38), Color.orange.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
          )
        )

        LineMark(
          x: .value(loc("stats.axis.date", "Date"), stat.date, unit: .day),
          y: .value(loc("stats.axis.calories", "Calories"), stat.totalCalories)
        )
        .interpolationMethod(.monotone)
        .foregroundStyle(Color.orange)
        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

        PointMark(
          x: .value(loc("stats.axis.date", "Date"), stat.date, unit: .day),
          y: .value(loc("stats.axis.calories", "Calories"), stat.totalCalories)
        )
        .foregroundStyle(Color.orange)
        .symbolSize(selectedDate.map { Calendar.current.isDate($0, inSameDayAs: stat.date) } == true ? 80 : 40)
      }

      if let target = calorieTarget, target > 0 {
        RuleMark(y: .value(loc("stats.axis.goal", "Goal"), target))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
          .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
          .annotation(position: .top, alignment: .trailing) {
            Text("\(target)")
              .font(.caption2)
              .foregroundColor(AppTheme.textSecondary)
          }
      }

      selectionRule(in: days) { stat in
        "\(stat.totalCalories) \(loc("units.kcal", "kcal"))"
      }
    }
  }

  // MARK: - Body weight

  private var personWeightChart: some View {
    let validWeightStats = weightSeries
    let weights = validWeightStats.map { Double($0.personWeight) }
    let minWeight = weights.min() ?? 0
    let maxWeight = weights.max() ?? 0
    let weightRange = maxWeight - minWeight
    let padding = weightRange == 0 ? max(minWeight * 0.05, 2.0) : max(weightRange * 0.2, 1.0)
    let yAxisMin = max(0, minWeight - padding)
    let yAxisMax = maxWeight + padding

    return VStack(alignment: .leading, spacing: 10) {
      if validWeightStats.count == 1 {
        let isToday = Calendar.current.isDate(validWeightStats[0].date, inSameDayAs: Date())
        let prefix =
          isToday ? loc("stats.weight.current", "Current") : loc("stats.weight.latest", "Latest")
        Text(
          "\(prefix) \(loc("stats.axis.weight", "Weight")): \(String(format: "%.1f", validWeightStats[0].personWeight)) \(loc("units.kg", "kg"))"
        )
        .font(.headline)
        .foregroundColor(AppTheme.textPrimary)
      }

      if validWeightStats.isEmpty {
        EmptyStateView(
          systemImage: "figure.stand",
          title: loc("stats.weight.empty.title", "No weight data available"),
          subtitle: loc("stats.weight.empty.subtitle", "Submit weight via camera or manual entry")
        )
      } else {
        interactiveTimeChart(
          days: validWeightStats,
          yLabel: loc("stats.axis.weight", "Weight"),
          yDomain: yAxisMin...yAxisMax
        ) {
          ForEach(validWeightStats, id: \.dateString) { stat in
            if validWeightStats.count > 1 {
              AreaMark(
                x: .value(loc("stats.axis.date", "Date"), stat.date, unit: .day),
                y: .value(loc("stats.axis.weight", "Weight"), stat.personWeight)
              )
              .interpolationMethod(.monotone)
              .foregroundStyle(
                LinearGradient(
                  colors: [Color.green.opacity(0.32), Color.green.opacity(0.02)],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              LineMark(
                x: .value(loc("stats.axis.date", "Date"), stat.date, unit: .day),
                y: .value(loc("stats.axis.weight", "Weight"), stat.personWeight)
              )
              .interpolationMethod(.monotone)
              .foregroundStyle(Color.green)
              .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            PointMark(
              x: .value(loc("stats.axis.date", "Date"), stat.date, unit: .day),
              y: .value(loc("stats.axis.weight", "Weight"), stat.personWeight)
            )
            .foregroundStyle(Color.green)
            .symbolSize(validWeightStats.count == 1 ? 100 : 50)
          }
          selectionRule(in: validWeightStats) { stat in
            String(format: "%.1f %@", stat.personWeight, loc("units.kg", "kg"))
          }
        }
      }
    }
  }

  private var weightSeries: [DailyStatistics] {
    let allWeightStats = statistics.filter { $0.personWeight > 0 }
    let uniqueWeights = Set(allWeightStats.map { $0.personWeight })
    if uniqueWeights.count <= 1, !allWeightStats.isEmpty {
      let today = Date()
      if let todayStats = allWeightStats.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
        return [todayStats]
      }
      return [allWeightStats.max(by: { $0.date < $1.date })!]
    }
    return allWeightStats
  }

  // MARK: - Food weight

  private var foodWeightChart: some View {
    let days = plottedDays.filter { $0.totalFoodWeight > 0 }
    return interactiveTimeChart(days: days, yLabel: loc("stats.axis.foodweight", "Food Weight")) {
      ForEach(days, id: \.dateString) { stat in
        BarMark(
          x: .value(loc("stats.axis.date", "Date"), stat.date, unit: .day),
          y: .value(loc("stats.axis.foodweight", "Food Weight"), stat.totalFoodWeight)
        )
        .foregroundStyle(
          LinearGradient(
            colors: [Color.blue, Color.blue.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .cornerRadius(6)
      }
      selectionRule(in: days) { stat in
        "\(stat.totalFoodWeight) \(loc("units.g", "g"))"
      }
    }
  }

  // MARK: - Macros

  private var macronutrientsChart: some View {
    let series = macroSeries
    return VStack(spacing: 12) {
      interactiveTimeChart(days: plottedDays, yLabel: loc("units.g", "g")) {
        ForEach(series) { item in
          BarMark(
            x: .value(loc("stats.axis.date", "Date"), item.date, unit: .day),
            y: .value(item.nutrient, item.value)
          )
          .foregroundStyle(by: .value(loc("stats.chart.macros", "Macronutrients"), item.nutrient))
          .cornerRadius(3)
        }
        selectionRule(in: plottedDays) { stat in
          String(
            format: loc("stats.graphs.macro_selected", "P %.0f  F %.0f  C %.0f"),
            stat.proteins, stat.fats, stat.carbohydrates)
        }
      }
      .chartForegroundStyleScale([
        loc("stats.axis.proteins", "Proteins"): AppTheme.macroProtein,
        loc("stats.axis.fats", "Fats"): AppTheme.macroFat,
        loc("stats.axis.carbs", "Carbs"): AppTheme.macroCarb,
        loc("stats.axis.fiber", "Fiber"): AppTheme.macroFiber,
      ])
      .chartLegend(position: .bottom, alignment: .center)
    }
  }

  private var macroSeries: [MacroPlotPoint] {
    plottedDays.flatMap { stat in
      [
        MacroPlotPoint(date: stat.date, nutrient: loc("stats.axis.proteins", "Proteins"), value: stat.proteins),
        MacroPlotPoint(date: stat.date, nutrient: loc("stats.axis.fats", "Fats"), value: stat.fats),
        MacroPlotPoint(date: stat.date, nutrient: loc("stats.axis.carbs", "Carbs"), value: stat.carbohydrates),
        MacroPlotPoint(date: stat.date, nutrient: loc("stats.axis.fiber", "Fiber"), value: stat.fiber),
      ]
    }
  }

  // MARK: - Trends / insights (existing content)

  private var trendsView: some View {
    let trends = statisticsService.calculateTrends(from: statistics)
    return VStack(alignment: .leading, spacing: 15) {
      Text(loc("stats.trend.title", "Trend Analysis"))
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(AppTheme.textPrimary)

      trendCard(
        title: loc("stats.trend.calories", "Calories Trend"), value: trends.caloriesTrend,
        unit: loc("units.kcal", "kcal"), color: .orange)
      trendCard(
        title: loc("stats.trend.body_weight", "Body Weight Trend"),
        value: trends.personWeightTrend, unit: loc("units.kg", "kg"), color: .green)
      trendCard(
        title: loc("stats.trend.food_weight", "Food Weight Trend"), value: trends.weightTrend,
        unit: loc("units.g", "g"), color: .blue)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func trendCard(title: String, value: Double, unit: String, color: Color) -> some View {
    HStack {
      VStack(alignment: .leading) {
        Text(title)
          .font(.subheadline)
          .foregroundColor(AppTheme.textPrimary)
        HStack {
          Image(systemName: value > 0 ? "arrow.up" : value < 0 ? "arrow.down" : "minus")
            .foregroundColor(value > 0 ? .red : value < 0 ? .green : .gray)
          Text(String(format: "%.1f %@", abs(value), unit))
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(color)
        }
      }
      Spacer()
    }
    .padding()
    .background(AppTheme.surface)
    .cornerRadius(AppTheme.smallRadius)
  }

  private var insightsView: some View {
    let averages = statisticsService.calculateAverages(from: statistics)
    let validDays = plottedDays.count
    return VStack(alignment: .leading, spacing: 12) {
      Text(loc("stats.insights.title", "Insights Overview"))
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(AppTheme.textPrimary)
      insightRow(loc("stats.insights.active_days", "Active Days"), "\(validDays)/\(statistics.count)")
      insightRow(
        loc("stats.insights.avg_daily_calories", "Avg Daily Calories"),
        "\(Int(averages.avgCalories)) \(loc("units.kcal", "kcal"))")
      insightRow(
        loc("stats.insights.avg_food_weight", "Avg Food Weight"),
        "\(Int(averages.avgWeight)) \(loc("units.g", "g"))")
      insightRow(
        loc("stats.insights.avg_protein", "Avg Protein"),
        "\(Int(averages.avgProteins)) \(loc("units.g", "g"))")
      insightRow(
        loc("stats.insights.avg_fiber", "Avg Fiber"),
        "\(Int(averages.avgFiber)) \(loc("units.g", "g"))")
      if averages.avgPersonWeight > 0 {
        insightRow(
          loc("stats.insights.avg_body_weight", "Avg Body Weight"),
          String(format: "%.1f %@", averages.avgPersonWeight, loc("units.kg", "kg")))
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func insightRow(_ title: String, _ value: String) -> some View {
    HStack {
      Text(title)
        .font(.subheadline)
        .foregroundColor(AppTheme.textSecondary)
      Spacer()
      Text(value)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(AppTheme.textPrimary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(AppTheme.surface)
    .cornerRadius(AppTheme.smallRadius)
  }

  private var summaryStatsView: some View {
    let averages = statisticsService.calculateAverages(from: statistics)
    return VStack(alignment: .leading, spacing: 6) {
      Text(
        String(
          format: loc("stats.summary.title_format", "Summary (%@)"), localizedPeriod(selectedPeriod)
        )
      )
      .font(.subheadline)
      .fontWeight(.semibold)
      .foregroundColor(AppTheme.textPrimary)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
        summaryCard(
          title: loc("stats.summary.avg_calories", "Avg Calories"),
          value: "\(Int(averages.avgCalories))",
          subtitle: String(format: loc("units.per_day_format", "%@/day"), loc("units.kcal", "kcal"))
        )
        summaryCard(
          title: loc("stats.summary.avg_food", "Avg Food"), value: "\(Int(averages.avgWeight))",
          subtitle: String(format: loc("units.per_day_format", "%@/day"), loc("units.g", "g")))
        summaryCard(
          title: loc("stats.summary.avg_protein", "Avg Protein"),
          value: "\(Int(averages.avgProteins))",
          subtitle: String(format: loc("units.per_day_format", "%@/day"), loc("units.g", "g")))
        summaryCard(
          title: loc("stats.summary.avg_fiber", "Avg Fiber"), value: "\(Int(averages.avgFiber))",
          subtitle: String(format: loc("units.per_day_format", "%@/day"), loc("units.g", "g")))
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .modifier(ChartCardGlass())
  }

  private func summaryCard(title: String, value: String, subtitle: String) -> some View {
    VStack(spacing: 3) {
      Text(title)
        .font(.caption2)
        .foregroundColor(AppTheme.textSecondary)
        .lineLimit(1)
      Text(value)
        .font(.subheadline)
        .fontWeight(.bold)
        .foregroundColor(AppTheme.textPrimary)
        .lineLimit(1)
      Text(subtitle)
        .font(.caption2)
        .foregroundColor(AppTheme.textSecondary)
        .lineLimit(1)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(AppTheme.surface)
    .cornerRadius(AppTheme.smallRadius)
    .frame(maxWidth: .infinity)
  }

  // MARK: - Shared chart chrome

  @ViewBuilder
  private func interactiveTimeChart<Content: ChartContent>(
    days: [DailyStatistics],
    yLabel: String,
    yDomain: ClosedRange<Double>? = nil,
    @ChartContentBuilder content: () -> Content
  ) -> some View {
    let base = Chart { content() }
      .chartXSelection(value: $selectedDate)
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
      .frame(height: 300)
      .animation(
        AppSettingsService.shared.reduceMotion ? .none : .snappy(duration: 0.25),
        value: days.map(\.dateString))

    if let yDomain {
      scrolledChart(base.chartYScale(domain: yDomain), daysCount: days.count)
    } else {
      scrolledChart(base, daysCount: days.count)
    }
  }

  @ViewBuilder
  private func scrolledChart<V: View>(_ chart: V, daysCount: Int) -> some View {
    if selectedPeriod == .week || daysCount <= 8 {
      chart
    } else {
      chart
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: 14 * 24 * 3600)
        .chartScrollPosition(x: $scrollDate)
    }
  }

  @ChartContentBuilder
  private func selectionRule(
    in days: [DailyStatistics],
    valueText: (DailyStatistics) -> String
  ) -> some ChartContent {
    if let selectedDate,
      let stat = days.min(by: {
        abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
      })
    {
      RuleMark(x: .value(loc("stats.axis.date", "Date"), stat.date, unit: .day))
        .foregroundStyle(AppTheme.accent.opacity(0.45))
        .lineStyle(StrokeStyle(lineWidth: 1))
        .annotation(position: .top, spacing: 4) {
          VStack(alignment: .leading, spacing: 2) {
            Text(stat.date, format: .dateTime.month(.abbreviated).day())
              .font(.caption2)
              .foregroundStyle(AppTheme.textSecondary)
            Text(valueText(stat))
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(AppTheme.textPrimary)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .modifier(SelectionPopoverGlass())
        }
    }
  }

  private var calorieTarget: Int? {
    let stored = CalorieLimitsStorageService.shared.load()?.softLimit
      ?? UserDefaults.standard.integer(forKey: "softLimit")
    return stored > 0 ? stored : nil
  }

  private func loadData() {
    isLoading = true
    statisticsService.fetchStatisticsForPeriod(period: selectedPeriod) { fetchedStats in
      DispatchQueue.main.async {
        self.statistics = fetchedStats
        self.scrollDate = fetchedStats.last?.date ?? Date()
        self.isLoading = false
      }
    }
  }
}

struct MacroPlotPoint: Identifiable {
  let id = UUID()
  let date: Date
  let nutrient: String
  let value: Double
}

private struct ControlGlass: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
    } else {
      content
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.smallRadius)
    }
  }
}

private struct ChipGlass: ViewModifier {
  let selected: Bool
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(
        selected ? .regular.tint(AppTheme.accent).interactive() : .regular.interactive(),
        in: .capsule
      )
    } else {
      content
        .background(selected ? AppTheme.accent : AppTheme.surfaceAlt)
        .cornerRadius(16)
    }
  }
}

private struct ChartCardGlass: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular, in: .rect(cornerRadius: AppTheme.smallRadius))
    } else {
      content
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.smallRadius)
    }
  }
}

private struct SelectionPopoverGlass: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    } else {
      content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }
}

#Preview {
  StatisticsGraphsView(isPresented: .constant(true))
}
