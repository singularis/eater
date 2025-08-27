import SwiftUI
import Charts

struct StatisticsView: View {
    @Binding var isPresented: Bool
    @State private var selectedPeriod: StatisticsPeriod = .week
    @State private var statistics: [DailyStatistics] = []
    @State private var isLoading = false
    @State private var selectedChart: ChartType = .insights
    
    private let statisticsService = StatisticsService.shared
    
    enum ChartType: CaseIterable {
        case insights
        case calories
        case macros
        case personWeight
        case foodWeight
        case trends
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
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.zeroFormattingBehavior = .dropAll
        // Set locale via calendar
        var cal = Calendar.current
        cal.locale = Locale(identifier: LanguageService.shared.currentCode)
        formatter.calendar = cal
        var comps = DateComponents()
        switch period {
        case .week:
            comps.day = 7
            formatter.allowedUnits = [.day]
        case .month:
            comps.day = 30
            formatter.allowedUnits = [.day]
        case .twoMonths:
            comps.month = 2
            formatter.allowedUnits = [.month]
        case .threeMonths:
            comps.month = 3
            formatter.allowedUnits = [.month]
        }
        return formatter.string(from: comps) ?? period.rawValue
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    if isLoading {
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text(loc("stats.loading", "Loading statistics..."))
                                .foregroundColor(.white)
                                .padding(.top)
                        }
                    } else {
                        VStack(spacing: 0) {
                            // Period Selection
                            periodSelectionView
                                .padding(.horizontal, 16)
                                .padding(.top, 5)
                            
                            // Chart Type Selection
                            chartTypeSelectionView
                                .padding(.vertical, 8)
                            
                            // Main content area - reduced spacing
                            ScrollView {
                                VStack(spacing: 8) {
                                    // Main Chart - increased height for better visibility
                                    chartView
                                        .frame(height: geometry.size.height * 0.5)
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Summary Stats - reduced height to give more space to chart
                            summaryStatsView
                                .frame(height: geometry.size.height * 0.15)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                        }
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
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                loadData()
            }
        }
        .environment(\.locale, Locale(identifier: LanguageService.shared.currentCode))
    }
    
    private var periodSelectionView: some View {
        VStack(spacing: 10) {
            Text(loc("stats.timeperiod", "Time Period"))
                .font(.headline)
                .foregroundColor(.white)
            
            Picker("Period", selection: $selectedPeriod) {
                ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                    Text(localizedPeriod(period)).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .onChange(of: selectedPeriod) { _, _ in
                loadData()
            }
        }
    }
    
    private var chartTypeSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ChartType.allCases, id: \.self) { chartType in
                    Button(action: {
                        withAnimation {
                            selectedChart = chartType
                        }
                    }) {
                        Text(localizedChartTypeName(chartType))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedChart == chartType ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }
    
    @ViewBuilder
    private var chartView: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Removed redundant titles since chart type is already highlighted above
            
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var caloriesChart: some View {
        Chart(statistics) { stat in
            LineMark(
                x: .value(loc("stats.axis.date", "Date"), stat.date),
                y: .value(loc("stats.axis.calories", "Calories"), stat.totalCalories)
            )
            .foregroundStyle(Color.orange)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value(loc("stats.axis.date", "Date"), stat.date),
                y: .value(loc("stats.axis.calories", "Calories"), stat.totalCalories)
            )
            .foregroundStyle(Color.orange)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(Color.white)
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(Color.white)
                    .font(.caption)
            }
        }
        .frame(height: 300)
    }
    
    private var personWeightChart: some View {
        let allWeightStats = statistics.filter { $0.personWeight > 0 }
        let uniqueWeights = Set(allWeightStats.map { $0.personWeight })
        let validWeightStats: [DailyStatistics]
        
        if uniqueWeights.count <= 1 && !allWeightStats.isEmpty {
            let today = Date()
            let calendar = Calendar.current
            let todayStats = allWeightStats.first { calendar.isDate($0.date, inSameDayAs: today) }
            
            if let todayStats = todayStats {
                validWeightStats = [todayStats]
            } else {
                validWeightStats = [allWeightStats.max(by: { $0.date < $1.date })!]
            }
        } else {
            validWeightStats = allWeightStats
        }
        
        let weights = validWeightStats.map { Double($0.personWeight) }
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 0
        let weightRange = maxWeight - minWeight
        
        let padding: Double
        if weightRange == 0 {
            padding = max(minWeight * 0.05, 2.0)
        } else {
            padding = max(weightRange * 0.2, 1.0)
        }
        
        let yAxisMin = max(0, minWeight - padding)
        let yAxisMax = maxWeight + padding
        
        return VStack(alignment: .leading, spacing: 10) {
            if validWeightStats.count == 1 {
                let isToday = Calendar.current.isDate(validWeightStats[0].date, inSameDayAs: Date())
                let prefix = isToday ? loc("stats.weight.current", "Current") : loc("stats.weight.latest", "Latest")
                Text("\(prefix) \(loc("stats.axis.weight", "Weight")): \(String(format: "%.1f", validWeightStats[0].personWeight)) \(loc("units.kg", "kg"))")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 5)
            }
            
            Chart(validWeightStats) { stat in
                if validWeightStats.count == 1 {
                    PointMark(
                        x: .value(loc("stats.axis.date", "Date"), stat.date),
                        y: .value(loc("stats.axis.weight", "Weight"), stat.personWeight)
                    )
                    .foregroundStyle(Color.green)
                    .symbolSize(100)
                } else {
                    LineMark(
                        x: .value(loc("stats.axis.date", "Date"), stat.date),
                        y: .value(loc("stats.axis.weight", "Weight"), stat.personWeight)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value(loc("stats.axis.date", "Date"), stat.date),
                        y: .value(loc("stats.axis.weight", "Weight"), stat.personWeight)
                    )
                    .foregroundStyle(Color.green)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                        .font(.caption)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                        .font(.caption)
                }
            }
            .chartYScale(domain: yAxisMin...yAxisMax)
            .frame(height: validWeightStats.count == 1 ? 200 : 300)
            .overlay(
                validWeightStats.isEmpty ? 
                VStack {
                    Text(loc("stats.weight.empty.title", "No weight data available"))
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    Text(loc("stats.weight.empty.subtitle", "Submit weight via camera or manual entry"))
                        .foregroundColor(.gray)
                        .font(.caption)
                        .padding(.top, 2)
                } : nil
            )
        }
    }
    
    private var foodWeightChart: some View {
        Chart(statistics) { stat in
            BarMark(
                x: .value(loc("stats.axis.date", "Date"), stat.date),
                y: .value(loc("stats.axis.foodweight", "Food Weight"), stat.totalFoodWeight)
            )
            .foregroundStyle(Color.blue)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(Color.white)
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(Color.white)
                    .font(.caption)
            }
        }
        .frame(height: 300)
    }
    
    private var macronutrientsChart: some View {
        let macroData = statistics.map { stat in
            [
                (loc("stats.axis.proteins", "Proteins"), stat.proteins, Color.red),
                (loc("stats.axis.fats", "Fats"), stat.fats, Color.yellow),
                (loc("stats.axis.carbs", "Carbs"), stat.carbohydrates, Color.blue),
                (loc("stats.axis.fiber", "Fiber"), stat.fiber, Color.green)
            ]
        }.flatMap { dayData in
            dayData.enumerated().map { index, macro in
                MacroData(
                    date: statistics[0].date, // This needs to be fixed
                    nutrient: macro.0,
                    value: macro.1,
                    color: macro.2
                )
            }
        }
        
        return VStack(spacing: 16) {
            Chart(statistics) { stat in
                BarMark(
                    x: .value(loc("stats.axis.date", "Date"), stat.date),
                    y: .value(loc("stats.axis.proteins", "Proteins"), stat.proteins)
                )
                .foregroundStyle(Color.red)
                
                BarMark(
                    x: .value(loc("stats.axis.date", "Date"), stat.date),
                    y: .value(loc("stats.axis.fats", "Fats"), stat.fats)
                )
                .foregroundStyle(Color.yellow)
                
                BarMark(
                    x: .value(loc("stats.axis.date", "Date"), stat.date),
                    y: .value(loc("stats.axis.carbs", "Carbs"), stat.carbohydrates)
                )
                .foregroundStyle(Color.blue)
                
                BarMark(
                    x: .value(loc("stats.axis.date", "Date"), stat.date),
                    y: .value(loc("stats.axis.fiber", "Fiber"), stat.fiber)
                )
                .foregroundStyle(Color.green)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                        .font(.caption)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                        .font(.caption)
                }
            }
            .frame(height: 300)
            
            // Legend
            HStack(spacing: 16) {
                ForEach([
                    (loc("stats.axis.proteins", "Proteins"), Color.red),
                    (loc("stats.axis.fats", "Fats"), Color.yellow),
                    (loc("stats.axis.carbs", "Carbs"), Color.blue),
                    (loc("stats.axis.fiber", "Fiber"), Color.green)
                ], id: \.0) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.1)
                            .frame(width: 8, height: 8)
                        Text(item.0)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var trendsView: some View {
        let trends = statisticsService.calculateTrends(from: statistics)
        
        return VStack(alignment: .leading, spacing: 15) {
            Text(loc("stats.trend.title", "Trend Analysis"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            
            VStack(spacing: 12) {
                trendCard(title: loc("stats.trend.calories", "Calories Trend"), value: trends.caloriesTrend, unit: loc("units.kcal", "kcal"), color: .orange)
                trendCard(title: loc("stats.trend.body_weight", "Body Weight Trend"), value: trends.personWeightTrend, unit: loc("units.kg", "kg"), color: .green)
                trendCard(title: loc("stats.trend.food_weight", "Food Weight Trend"), value: trends.weightTrend, unit: loc("units.g", "g"), color: .blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func trendCard(title: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
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
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var insightsView: some View {
        let averages = statisticsService.calculateAverages(from: statistics)
        let validDays = statistics.filter { $0.hasData }.count
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text(loc("stats.insights.title", "Insights Overview"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 5)
                
                VStack(spacing: 12) {
                    insightCard(title: loc("stats.insights.active_days", "Active Days"), value: "\(validDays)/\(statistics.count)")
                    insightCard(title: loc("stats.insights.avg_daily_calories", "Avg Daily Calories"), value: "\(Int(averages.avgCalories)) \(loc("units.kcal", "kcal"))")
                    insightCard(title: loc("stats.insights.avg_food_weight", "Avg Food Weight"), value: "\(Int(averages.avgWeight)) \(loc("units.g", "g"))")
                    insightCard(title: loc("stats.insights.avg_protein", "Avg Protein"), value: "\(Int(averages.avgProteins)) \(loc("units.g", "g"))")
                    insightCard(title: loc("stats.insights.avg_fiber", "Avg Fiber"), value: "\(Int(averages.avgFiber)) \(loc("units.g", "g"))")
                    
                    if averages.avgPersonWeight > 0 {
                        insightCard(title: loc("stats.insights.avg_body_weight", "Avg Body Weight"), value: String(format: "%.1f %@", averages.avgPersonWeight, loc("units.kg", "kg")))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
    }
    
    private func insightCard(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
    
    private var summaryStatsView: some View {
        let averages = statisticsService.calculateAverages(from: statistics)
        
        return VStack(alignment: .leading, spacing: 6) {
            Text(String(format: loc("stats.summary.title_format", "Summary (%@)"), localizedPeriod(selectedPeriod)))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                summaryCard(title: loc("stats.summary.avg_calories", "Avg Calories"), value: "\(Int(averages.avgCalories))", subtitle: String(format: loc("units.per_day_format", "%@/day"), loc("units.kcal", "kcal")))
                summaryCard(title: loc("stats.summary.avg_food", "Avg Food"), value: "\(Int(averages.avgWeight))", subtitle: String(format: loc("units.per_day_format", "%@/day"), loc("units.g", "g")))
                summaryCard(title: loc("stats.summary.avg_protein", "Avg Protein"), value: "\(Int(averages.avgProteins))", subtitle: String(format: loc("units.per_day_format", "%@/day"), loc("units.g", "g")))
                summaryCard(title: loc("stats.summary.avg_fiber", "Avg Fiber"), value: "\(Int(averages.avgFiber))", subtitle: String(format: loc("units.per_day_format", "%@/day"), loc("units.g", "g")))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func summaryCard(title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.3))
        .cornerRadius(6)
        .frame(maxWidth: .infinity)
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

struct MacroData: Identifiable {
    let id = UUID()
    let date: Date
    let nutrient: String
    let value: Double
    let color: Color
}

#Preview {
    StatisticsView(isPresented: .constant(true))
} 