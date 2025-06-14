import SwiftUI
import Charts

struct StatisticsView: View {
    @Binding var isPresented: Bool
    @State private var selectedPeriod: StatisticsPeriod = .week
    @State private var statistics: [DailyStatistics] = []
    @State private var isLoading = false
    @State private var selectedChart: ChartType = .insights
    
    private let statisticsService = StatisticsService.shared
    
    enum ChartType: String, CaseIterable {
        case insights = "Insights"
        case calories = "Calories"
        case macros = "Macronutrients"
        case personWeight = "Body Weight"
        case foodWeight = "Food Weight"
        case trends = "Trends"
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
                            Text("Loading statistics...")
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
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private var periodSelectionView: some View {
        VStack(spacing: 10) {
            Text("Time Period")
                .font(.headline)
                .foregroundColor(.white)
            
            Picker("Period", selection: $selectedPeriod) {
                ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
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
                        Text(chartType.rawValue)
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
                x: .value("Date", stat.date),
                y: .value("Calories", stat.totalCalories)
            )
            .foregroundStyle(Color.orange)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value("Date", stat.date),
                y: .value("Calories", stat.totalCalories)
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
                Text("\(isToday ? "Current" : "Latest") Weight: \(String(format: "%.1f", validWeightStats[0].personWeight)) kg")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 5)
            }
            
            Chart(validWeightStats) { stat in
                if validWeightStats.count == 1 {
                    PointMark(
                        x: .value("Date", stat.date),
                        y: .value("Weight", stat.personWeight)
                    )
                    .foregroundStyle(Color.green)
                    .symbolSize(100)
                } else {
                    LineMark(
                        x: .value("Date", stat.date),
                        y: .value("Weight", stat.personWeight)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Date", stat.date),
                        y: .value("Weight", stat.personWeight)
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
                    Text("No weight data available")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    Text("Submit weight via camera or manual entry")
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
                x: .value("Date", stat.date),
                y: .value("Food Weight", stat.totalFoodWeight)
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
                ("Proteins", stat.proteins, Color.red),
                ("Fats", stat.fats, Color.yellow),
                ("Carbs", stat.carbohydrates, Color.blue),
                ("Fiber", stat.fiber, Color.green)
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
                    x: .value("Date", stat.date),
                    y: .value("Proteins", stat.proteins)
                )
                .foregroundStyle(Color.red)
                
                BarMark(
                    x: .value("Date", stat.date),
                    y: .value("Fats", stat.fats)
                )
                .foregroundStyle(Color.yellow)
                
                BarMark(
                    x: .value("Date", stat.date),
                    y: .value("Carbs", stat.carbohydrates)
                )
                .foregroundStyle(Color.blue)
                
                BarMark(
                    x: .value("Date", stat.date),
                    y: .value("Fiber", stat.fiber)
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
                    ("Proteins", Color.red),
                    ("Fats", Color.yellow),
                    ("Carbs", Color.blue),
                    ("Fiber", Color.green)
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
            Text("Trend Analysis")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            
            VStack(spacing: 12) {
                trendCard(title: "Calories Trend", value: trends.caloriesTrend, unit: "kcal", color: .orange)
                trendCard(title: "Body Weight Trend", value: trends.personWeightTrend, unit: "kg", color: .green)
                trendCard(title: "Food Weight Trend", value: trends.weightTrend, unit: "g", color: .blue)
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
                Text("Insights Overview")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 5)
                
                VStack(spacing: 12) {
                    insightCard(title: "Active Days", value: "\(validDays)/\(statistics.count)")
                    insightCard(title: "Avg Daily Calories", value: "\(Int(averages.avgCalories)) kcal")
                    insightCard(title: "Avg Food Weight", value: "\(Int(averages.avgWeight)) g")
                    insightCard(title: "Avg Protein", value: "\(Int(averages.avgProteins)) g")
                    insightCard(title: "Avg Fiber", value: "\(Int(averages.avgFiber)) g")
                    
                    if averages.avgPersonWeight > 0 {
                        insightCard(title: "Avg Body Weight", value: String(format: "%.1f kg", averages.avgPersonWeight))
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
            Text("Summary (\(selectedPeriod.rawValue))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                summaryCard(title: "Avg Calories", value: "\(Int(averages.avgCalories))", subtitle: "kcal/day")
                summaryCard(title: "Avg Food", value: "\(Int(averages.avgWeight))", subtitle: "g/day")
                summaryCard(title: "Avg Protein", value: "\(Int(averages.avgProteins))", subtitle: "g/day")
                summaryCard(title: "Avg Fiber", value: "\(Int(averages.avgFiber))", subtitle: "g/day")
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