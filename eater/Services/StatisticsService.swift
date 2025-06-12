import Foundation

class StatisticsService {
    static let shared = StatisticsService()
    private init() {}
    
    private let grpcService = GRPCService()
    
    func fetchStatisticsForPeriod(
        period: StatisticsPeriod,
        completion: @escaping ([DailyStatistics]) -> Void
    ) {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate) ?? endDate
        
        var allStatistics: [DailyStatistics] = []
        let dispatchGroup = DispatchGroup()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        
        // Generate all dates in the period
        var currentDate = startDate
        while currentDate <= endDate {
            let dateString = dateFormatter.string(from: currentDate)
            
            dispatchGroup.enter()
            grpcService.fetchStatisticsData(date: dateString) { [weak self] dailyStats in
                defer { dispatchGroup.leave() }
                
                if let stats = dailyStats {
                    allStatistics.append(stats)
                } else {
                    // Create empty stats for days with no data
                    let emptyStats = DailyStatistics(
                        date: currentDate,
                        dateString: dateString,
                        totalCalories: 0,
                        totalFoodWeight: 0,
                        personWeight: 0,
                        proteins: 0,
                        fats: 0,
                        carbohydrates: 0,
                        sugar: 0,
                        numberOfMeals: 0
                    )
                    allStatistics.append(emptyStats)
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        dispatchGroup.notify(queue: .main) {
            // Sort by date to ensure proper order
            let sortedStats = allStatistics.sorted { $0.date < $1.date }
            completion(sortedStats)
        }
    }
    
    // Helper methods for analysis
    func calculateAverages(from statistics: [DailyStatistics]) -> (
        avgCalories: Double,
        avgWeight: Double,
        avgPersonWeight: Double,
        avgProteins: Double,
        avgFats: Double,
        avgCarbs: Double,
        avgFiber: Double
    ) {
        let validStats = statistics.filter { $0.totalCalories > 0 || $0.personWeight > 0 }
        guard !validStats.isEmpty else {
            return (0, 0, 0, 0, 0, 0, 0)
        }
        
        let totalStats = validStats.count
        let caloriesSum = validStats.reduce(0) { $0 + $1.totalCalories }
        let weightSum = validStats.reduce(0) { $0 + $1.totalFoodWeight }
        let personWeightSum = validStats.filter { $0.personWeight > 0 }.reduce(0) { $0 + Double($1.personWeight) }
        let personWeightCount = validStats.filter { $0.personWeight > 0 }.count
        let proteinsSum = validStats.reduce(0) { $0 + $1.proteins }
        let fatsSum = validStats.reduce(0) { $0 + $1.fats }
        let carbsSum = validStats.reduce(0) { $0 + $1.carbohydrates }
        let fiberSum = validStats.reduce(0) { $0 + $1.fiber }
        
        return (
            avgCalories: Double(caloriesSum) / Double(totalStats),
            avgWeight: Double(weightSum) / Double(totalStats),
            avgPersonWeight: personWeightCount > 0 ? personWeightSum / Double(personWeightCount) : 0,
            avgProteins: proteinsSum / Double(totalStats),
            avgFats: fatsSum / Double(totalStats),
            avgCarbs: carbsSum / Double(totalStats),
            avgFiber: fiberSum / Double(totalStats)
        )
    }
    
    func calculateTrends(from statistics: [DailyStatistics]) -> (
        caloriesTrend: Double,
        weightTrend: Double,
        personWeightTrend: Double
    ) {
        guard statistics.count >= 2 else { return (0, 0, 0) }
        
        let validCaloriesStats = statistics.filter { $0.totalCalories > 0 }
        let validWeightStats = statistics.filter { $0.totalFoodWeight > 0 }
        let validPersonWeightStats = statistics.filter { $0.personWeight > 0 }
        
        func calculateTrend<T: Numeric>(_ values: [T]) -> Double {
            guard values.count >= 2 else { return 0 }
            let first = values.prefix(values.count / 3)
            let last = values.suffix(values.count / 3)
            
            let firstAvg = first.reduce(0) { acc, val in
                if let doubleVal = val as? Double { return acc + doubleVal }
                if let intVal = val as? Int { return acc + Double(intVal) }
                if let floatVal = val as? Float { return acc + Double(floatVal) }
                return acc
            } / Double(first.count)
            
            let lastAvg = last.reduce(0) { acc, val in
                if let doubleVal = val as? Double { return acc + doubleVal }
                if let intVal = val as? Int { return acc + Double(intVal) }
                if let floatVal = val as? Float { return acc + Double(floatVal) }
                return acc
            } / Double(last.count)
            
            return lastAvg - firstAvg
        }
        
        let caloriesTrend = calculateTrend(validCaloriesStats.map { $0.totalCalories })
        let weightTrend = calculateTrend(validWeightStats.map { $0.totalFoodWeight })
        let personWeightTrend = calculateTrend(validPersonWeightStats.map { $0.personWeight })
        
        return (caloriesTrend, weightTrend, Double(personWeightTrend))
    }
} 