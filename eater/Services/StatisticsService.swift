import Foundation

enum StatisticsPeriodFetchResult {
  case success([DailyStatistics])
  case unauthorized
  case failed
}

class StatisticsService {
  static let shared = StatisticsService()
  private init() {}

  private let grpcService = GRPCService()
  private let cacheService = StatisticsCacheService.shared

  static func dateString(for date: Date = Date()) -> String {
    rangeDateFormatter().string(from: date)
  }

  private static func rangeDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "dd-MM-yyyy"
    return formatter
  }

  func invalidateDay(_ dateString: String? = nil) {
    cacheService.invalidate(dateString: dateString ?? Self.dateString())
  }

  /// One `get_statistics_range` call for the whole window. Empty calendar days are filled locally.
  func fetchStatisticsForPeriod(
    period: StatisticsPeriod,
    completion: @escaping (StatisticsPeriodFetchResult) -> Void
  ) {
    let calendar = Calendar.current
    let endDate = calendar.startOfDay(for: Date())
    let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate) ?? endDate
    let dateFormatter = Self.rangeDateFormatter()
    let startString = dateFormatter.string(from: startDate)
    let endString = dateFormatter.string(from: endDate)

    var allDateStrings: [String] = []
    var currentDate = startDate
    while currentDate <= endDate {
      allDateStrings.append(dateFormatter.string(from: currentDate))
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    grpcService.fetchStatisticsRange(startDate: startString, endDate: endString) { [weak self] result in
      guard let self else { return }
      switch result {
      case .days(let days):
        let formatter = Self.rangeDateFormatter()
        var byDate: [String: DailyStatistics] = [:]
        for stats in days {
          self.cacheService.cacheStatistics(stats, for: stats.dateString)
          byDate[stats.dateString] = stats
        }
        let filled = allDateStrings.map { dateString -> DailyStatistics in
          if let existing = byDate[dateString] {
            return existing
          }
          return DailyStatistics(
            date: formatter.date(from: dateString) ?? Date(),
            dateString: dateString,
            totalCalories: 0,
            totalFoodWeight: 0,
            personWeight: 0,
            proteins: 0,
            fats: 0,
            carbohydrates: 0,
            sugar: 0,
            numberOfMeals: 0,
            hasData: false
          )
        }
        DispatchQueue.main.async {
          completion(.success(filled))
        }
      case .unauthorized:
        DispatchQueue.main.async {
          completion(.unauthorized)
        }
      case .failed:
        DispatchQueue.main.async {
          completion(.failed)
        }
      }
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
    let validStats = statistics.filter { $0.hasData }
    guard !validStats.isEmpty else {
      return (0, 0, 0, 0, 0, 0, 0)
    }

    let totalStats = validStats.count
    let caloriesSum = validStats.reduce(0) { $0 + $1.totalCalories }
    let weightSum = validStats.reduce(0) { $0 + $1.totalFoodWeight }
    let personWeightSum = validStats.filter { $0.personWeight > 0 }.reduce(0) {
      $0 + Double($1.personWeight)
    }
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

    let validCaloriesStats = statistics.filter { $0.hasData && $0.totalCalories > 0 }
    let validWeightStats = statistics.filter { $0.hasData && $0.totalFoodWeight > 0 }
    let validPersonWeightStats = statistics.filter { $0.hasData && $0.personWeight > 0 }

    func calculateTrend<T: Numeric>(_ values: [T]) -> Double {
      guard values.count >= 2 else { return 0 }
      let first = values.prefix(values.count / 3)
      let last = values.suffix(values.count / 3)

      let firstAvg =
        first.reduce(0) { acc, val in
          if let doubleVal = val as? Double { return acc + doubleVal }
          if let intVal = val as? Int { return acc + Double(intVal) }
          if let floatVal = val as? Float { return acc + Double(floatVal) }
          return acc
        } / Double(first.count)

      let lastAvg =
        last.reduce(0) { acc, val in
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

  // MARK: - Cache Management

  func getCacheInfo() -> (totalEntries: Int, cacheSize: Int) {
    return cacheService.getCacheInfo()
  }

  func clearCache() {
    cacheService.clearAllCache()
  }

  func clearExpiredCache() {
    cacheService.clearExpiredCache()
  }
}
