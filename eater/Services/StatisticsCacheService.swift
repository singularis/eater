import Foundation

class StatisticsCacheService {
  static let shared = StatisticsCacheService()
  private init() {}

  private let userDefaults = UserDefaults.standard
  private let cacheKey = "cached_daily_statistics"
  private let cacheExpiryKey = "statistics_cache_expiry"

  // Cache expiry time (24 hours for current day, longer for past days)
  private let currentDayCacheExpiry: TimeInterval = 4 * 60 * 60  // 4 hours for current day
  private let pastDayCacheExpiry: TimeInterval = 7 * 24 * 60 * 60  // 7 days for past days

  // MARK: - Cache Management

  func getCachedStatistics(for dateString: String) -> DailyStatistics? {
    guard let cachedData = getCachedData(),
      let statistics = cachedData[dateString],
      !isExpired(dateString: dateString, cachedTime: statistics.cachedTime)
    else {
      return nil
    }

    return statistics.dailyStats
  }

  func cacheStatistics(_ statistics: DailyStatistics, for dateString: String) {
    var cachedData = getCachedData() ?? [:]

    let cachedEntry = CachedDailyStatistics(
      dailyStats: statistics,
      cachedTime: Date().timeIntervalSince1970
    )

    cachedData[dateString] = cachedEntry
    saveCachedData(cachedData)
  }

  func getMissingDates(from dateStrings: [String]) -> [String] {
    let cachedData = getCachedData() ?? [:]

    return dateStrings.filter { dateString in
      guard let cachedEntry = cachedData[dateString] else {
        return true  // Not cached, need to fetch
      }

      // Check if expired
      return isExpired(dateString: dateString, cachedTime: cachedEntry.cachedTime)
    }
  }

  func getCachedStatistics(for dateStrings: [String]) -> [DailyStatistics] {
    let cachedData = getCachedData() ?? [:]

    return dateStrings.compactMap { dateString in
      guard let cachedEntry = cachedData[dateString],
        !isExpired(dateString: dateString, cachedTime: cachedEntry.cachedTime)
      else {
        return nil
      }
      return cachedEntry.dailyStats
    }
  }

  // MARK: - Cache Validation

  private func isExpired(dateString: String, cachedTime: TimeInterval) -> Bool {
    let now = Date()
    let cacheDate = Date(timeIntervalSince1970: cachedTime)

    // Check if this is today's data
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyyy"
    let todayString = dateFormatter.string(from: now)

    let expiryTime = (dateString == todayString) ? currentDayCacheExpiry : pastDayCacheExpiry
    let timeSinceCache = now.timeIntervalSince1970 - cachedTime

    return timeSinceCache > expiryTime
  }

  // MARK: - Data Persistence

  private func getCachedData() -> [String: CachedDailyStatistics]? {
    guard let data = userDefaults.data(forKey: cacheKey) else {
      return nil
    }

    do {
      let decoder = JSONDecoder()
      return try decoder.decode([String: CachedDailyStatistics].self, from: data)
    } catch {
      return nil
    }
  }

  private func saveCachedData(_ data: [String: CachedDailyStatistics]) {
    do {
      let encoder = JSONEncoder()
      let encodedData = try encoder.encode(data)
      userDefaults.set(encodedData, forKey: cacheKey)
    } catch {
      // Failed to save cached statistics
    }
  }

  // MARK: - Cache Cleanup

  func clearExpiredCache() {
    guard var cachedData = getCachedData() else { return }

    let originalCount = cachedData.count

    // Remove expired entries
    cachedData = cachedData.filter { dateString, cachedEntry in
      !isExpired(dateString: dateString, cachedTime: cachedEntry.cachedTime)
    }

    if cachedData.count != originalCount {
      saveCachedData(cachedData)
    }
  }

  func clearAllCache() {
    userDefaults.removeObject(forKey: cacheKey)
    userDefaults.removeObject(forKey: cacheExpiryKey)
  }

  func getCacheInfo() -> (totalEntries: Int, cacheSize: Int) {
    guard let cachedData = getCachedData() else {
      return (0, 0)
    }

    let totalEntries = cachedData.count
    let cacheSize = userDefaults.data(forKey: cacheKey)?.count ?? 0

    return (totalEntries, cacheSize)
  }
}

// MARK: - Cache Data Models

private struct CachedDailyStatistics: Codable {
  let dailyStats: DailyStatistics
  let cachedTime: TimeInterval
}

// Make DailyStatistics Codable for caching
extension DailyStatistics: Codable {
  private enum CodingKeys: String, CodingKey {
    case dateString, totalCalories, totalFoodWeight, personWeight
    case proteins, fats, carbohydrates, sugar, numberOfMeals, hasData
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let dateString = try container.decode(String.self, forKey: .dateString)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyyy"
    let date = dateFormatter.date(from: dateString) ?? Date()

    try self.init(
      date: date,
      dateString: dateString,
      totalCalories: container.decode(Int.self, forKey: .totalCalories),
      totalFoodWeight: container.decode(Int.self, forKey: .totalFoodWeight),
      personWeight: container.decode(Float.self, forKey: .personWeight),
      proteins: container.decode(Double.self, forKey: .proteins),
      fats: container.decode(Double.self, forKey: .fats),
      carbohydrates: container.decode(Double.self, forKey: .carbohydrates),
      sugar: container.decode(Double.self, forKey: .sugar),
      numberOfMeals: container.decode(Int.self, forKey: .numberOfMeals),
      hasData: container.decodeIfPresent(Bool.self, forKey: .hasData) ?? true  // Default to true for backward compatibility
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(dateString, forKey: .dateString)
    try container.encode(totalCalories, forKey: .totalCalories)
    try container.encode(totalFoodWeight, forKey: .totalFoodWeight)
    try container.encode(personWeight, forKey: .personWeight)
    try container.encode(proteins, forKey: .proteins)
    try container.encode(fats, forKey: .fats)
    try container.encode(carbohydrates, forKey: .carbohydrates)
    try container.encode(sugar, forKey: .sugar)
    try container.encode(numberOfMeals, forKey: .numberOfMeals)
    try container.encode(hasData, forKey: .hasData)
  }
}
