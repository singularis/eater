import Foundation

class StatisticsService {
  static let shared = StatisticsService()
  private init() {}

  private let grpcService = GRPCService()
  private let cacheService = StatisticsCacheService.shared
  private let fetchQueue = DispatchQueue(label: "com.eater.stats.fetch")
  private var rangeUnavailableThisSession = false

  static func dateString(for date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd-MM-yyyy"
    return formatter.string(from: date)
  }

  func invalidateDay(_ dateString: String? = nil) {
    cacheService.invalidate(dateString: dateString ?? Self.dateString())
  }

  func fetchStatisticsForPeriod(
    period: StatisticsPeriod,
    completion: @escaping ([DailyStatistics]) -> Void
  ) {
    let calendar = Calendar.current
    let endDate = Date()
    let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate) ?? endDate

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyyy"

    // Generate all dates in the period
    var allDateStrings: [String] = []
    var currentDate = startDate
    while currentDate <= endDate {
      let dateString = dateFormatter.string(from: currentDate)
      allDateStrings.append(dateString)
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    // Clean up expired cache entries first
    cacheService.clearExpiredCache()

    // ONE-TIME FIX: Clear cache if it contains data with incorrect hasData logic
    let hasCacheFix = UserDefaults.standard.bool(forKey: "hasDataLogicCacheFix")
    if !hasCacheFix {
      cacheService.clearAllCache()
      UserDefaults.standard.set(true, forKey: "hasDataLogicCacheFix")
    }

    // Refresh cache so daily health scores are present for the new stats screen.
    let hasHealthScoreCache = UserDefaults.standard.bool(forKey: "healthScoreStatsCacheV1")
    if !hasHealthScoreCache {
      cacheService.clearAllCache()
      UserDefaults.standard.set(true, forKey: "healthScoreStatsCacheV1")
    }

    let hasRangeCache = UserDefaults.standard.bool(forKey: "statsRangeCacheV1")
    if !hasRangeCache {
      cacheService.clearAllCache()
      UserDefaults.standard.set(true, forKey: "statsRangeCacheV1")
    }

    // Get cached statistics
    let cachedStatistics = cacheService.getCachedStatistics(for: allDateStrings)

    // Find missing dates that need to be fetched
    let missingDateStrings = cacheService.getMissingDates(from: allDateStrings)

    if missingDateStrings.isEmpty {
      // All data is cached, return immediately
      let sortedStats = cachedStatistics.sorted { $0.date < $1.date }
      completion(sortedStats)
      return
    }

    // Fetch missing data from server
    fetchMissingStatistics(dateStrings: missingDateStrings) { [weak self] newStatistics in
      guard let self = self else { return }

      // Range responses cover the whole span, including days we already had cached.
      var byDate: [String: DailyStatistics] = [:]
      for stats in cachedStatistics {
        byDate[stats.dateString] = stats
      }
      for stats in newStatistics {
        self.cacheService.cacheStatistics(stats, for: stats.dateString)
        byDate[stats.dateString] = stats
      }

      let emptyStats = allDateStrings.compactMap { dateString -> DailyStatistics? in
        guard byDate[dateString] == nil else { return nil }

        let date = dateFormatter.date(from: dateString) ?? Date()
        return DailyStatistics(
          date: date,
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

      let finalStatistics = (Array(byDate.values) + emptyStats).sorted { $0.date < $1.date }

      DispatchQueue.main.async {
        completion(finalStatistics)
      }
    }
  }

  private func fetchMissingStatistics(
    dateStrings: [String],
    completion: @escaping ([DailyStatistics]) -> Void
  ) {
    if rangeUnavailableThisSession {
      fetchMissingStatisticsPerDay(dateStrings: dateStrings, completion: completion)
      return
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "dd-MM-yyyy"
    let sorted = dateStrings.compactMap { dateString -> (String, Date)? in
      guard let date = formatter.date(from: dateString) else { return nil }
      return (dateString, date)
    }.sorted { $0.1 < $1.1 }
    guard let start = sorted.first?.0, let end = sorted.last?.0 else {
      completion([])
      return
    }

    grpcService.fetchStatisticsRange(startDate: start, endDate: end) { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .days(let days):
        completion(days)
      case .unavailable:
        self.rangeUnavailableThisSession = true
        self.fetchMissingStatisticsPerDay(dateStrings: dateStrings, completion: completion)
      case .failed:
        completion([])
      }
    }
  }

  private func fetchMissingStatisticsPerDay(
    dateStrings: [String],
    completion: @escaping ([DailyStatistics]) -> Void
  ) {
    var fetchedStatistics: [DailyStatistics] = []
    let dispatchGroup = DispatchGroup()
    let todayString = Self.dateString()

    for dateString in dateStrings {
      dispatchGroup.enter()
      let finish: (DailyStatistics?) -> Void = { stats in
        self.fetchQueue.async {
          if let stats = stats {
            fetchedStatistics.append(stats)
          }
          dispatchGroup.leave()
        }
      }

      if dateString == todayString {
        grpcService.fetchTodayStatistics { dailyStats in
          finish(dailyStats)
        }
      } else {
        grpcService.fetchStatisticsData(date: dateString) { dailyStats in
          finish(dailyStats)
        }
      }
    }

    dispatchGroup.notify(queue: fetchQueue) {
      completion(fetchedStatistics)
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
