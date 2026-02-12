import Foundation
import UIKit

class ProductStorageService {
  static let shared = ProductStorageService()
  private init() {}

  private let userDefaults = UserDefaults.standard
  private let productsKey = "cached_products"
  private let caloriesKey = "cached_calories"
  private let weightKey = "cached_weight"
  private let lastUpdateKey = "last_update_timestamp"
  private let healthLevelCacheKey = "health_level_cache"

  // MARK: - Health Level Cache Structure
  


  private let healthLevelKey = "cached_health_levels"

  private struct CachedHealthLevel: Codable {
    let title: String
    let description: String
    let healthSummary: String
  }

  // MARK: - Save/Load Products

  func saveProducts(_ products: [Product], calories: Int, weight: Float) {
    do {
      let encoder = JSONEncoder()
      let productsData = try encoder.encode(products.map { ProductData(from: $0) })
      userDefaults.set(productsData, forKey: productsKey)
      userDefaults.set(calories, forKey: caloriesKey)
      userDefaults.set(weight, forKey: weightKey)
      userDefaults.set(Date().timeIntervalSince1970, forKey: lastUpdateKey)

      // Cleanup orphan health levels
      cleanupOrphanHealthLevels(validProductTimes: Set(products.map { $0.time }))
    } catch {
      // Failed to save products
    }
  }

  func loadProducts() -> ([Product], Int, Float) {
    guard let productsData = userDefaults.data(forKey: productsKey) else {
      return ([], 0, 0)
    }

    do {
      let decoder = JSONDecoder()
      let productDataArray = try decoder.decode([ProductData].self, from: productsData)
      let products = productDataArray.map { $0.toProduct() }
      let calories = userDefaults.integer(forKey: caloriesKey)
      let weight = userDefaults.float(forKey: weightKey)

      return (products, calories, weight)
    } catch {
      return ([], 0, 0)
    }
  }

  // MARK: - Fetch and Process with Image Mapping

  func fetchAndProcessProducts(
    tempImageTime: Int64? = nil, forceRefresh: Bool = false,
    completion: @escaping (Result<([Product], Int, Float), Error>) -> Void
  ) {
    let shouldForceRefresh = forceRefresh || (tempImageTime != nil)

    // Check cache first ONLY if looking for today and no temp image (standard refresh)
    if !shouldForceRefresh, !isDataStale() {
      let (cachedProducts, cachedCalories, cachedWeight) = loadProducts()
      if !cachedProducts.isEmpty || cachedCalories > 0 || cachedWeight > 0 {
        completion(.success((cachedProducts, cachedCalories, cachedWeight)))
        return
      }
    }
    
    // Determine target date. If tempImageTime is provided, that dictates the date.
    if let tempTime = tempImageTime {
       let date = Date(timeIntervalSince1970: TimeInterval(tempTime) / 1000)
       let formatter = DateFormatter()
       formatter.dateFormat = "dd-MM-yyyy"
       // Ensure we use the same timezone/calendar logic as CameraButtonView (essentially UTC date)
       formatter.timeZone = TimeZone(abbreviation: "UTC") 
       let dateStr = formatter.string(from: date)
       
       let isToday = Calendar.current.isDateInToday(date)

       // Always fetch using the specific date from the timestamp to ensure we get the list where this food belongs
       GRPCService().fetchCustomDateFood(date: dateStr) { [weak self] result in
         DispatchQueue.main.async {
           switch result {
           case .success(let (products, calories, weight)):
             self?.mapTemporaryImage(products: products, tempTime: tempTime)
             
             // If it turns out this date WAS today, update the local cache
             if isToday {
                 self?.saveProducts(products, calories: calories, weight: weight)
             }
             
             completion(.success((products, calories, weight)))
           case .failure(let error):
             completion(.failure(error))
           }
         }
       }
       return
    }

    // Default: Fetch today's data (no temp time provided)
    GRPCService().fetchProducts { [weak self] result in
      DispatchQueue.main.async {
        switch result {
        case .success(let (products, calories, weight)):
            // Save products locally (only for today's data)
            self?.saveProducts(products, calories: calories, weight: weight)
            completion(.success((products, calories, weight)))
        case .failure(let error):
            completion(.failure(error))
        }
      }
    }
  }
  
  private func mapTemporaryImage(products: [Product], tempTime: Int64) {
      guard !products.isEmpty else { return }
      
      // Find the product closest to the tempTime
      let matchingProduct = products.min(by: { 
          abs($0.time - tempTime) < abs($1.time - tempTime) 
      })
      
      if let product = matchingProduct {
          // Safety Check: Only map if the time difference is reasonable (e.g. within 2 hours)
          // Since we are forcing timestamps to Noon UTC for backdating, and the backend might use creation time or similar,
          // we allow a slightly larger window, but 24h+ (difference between Today and Yesterday) should be rejected.
          // 4 hours = 4 * 60 * 60 * 1000 = 14,400,000 ms
          let diff = abs(product.time - tempTime)
          if diff < 14400000 { 
              _ = ImageStorageService.shared.moveTemporaryImage(
                fromTime: tempTime,
                toTime: product.time
              )
          }
      }
  }

  func fetchAndProcessCustomDateFood(
    date: String, completion: @escaping (Result<([Product], Int, Float), Error>) -> Void
  ) {
    GRPCService().fetchCustomDateFood(date: date) { result in
      DispatchQueue.main.async {
        // Don't save custom date data to cache - only today's data should be cached
        completion(result)
      }
    }
  }

  // MARK: - Cache Management

  func clearCache() {
    userDefaults.removeObject(forKey: productsKey)
    userDefaults.removeObject(forKey: caloriesKey)
    userDefaults.removeObject(forKey: weightKey)
    userDefaults.removeObject(forKey: lastUpdateKey)
  }

  func isDataStale(maxAgeMinutes: Double = 60) -> Bool {
    let lastUpdate = userDefaults.double(forKey: lastUpdateKey)
    if lastUpdate == 0 { return true }
    let ageMinutes = (Date().timeIntervalSince1970 - lastUpdate) / 60
    return ageMinutes > maxAgeMinutes
  }

  // Fast method to get cached data if available and fresh
  func getCachedDataIfFresh() -> ([Product], Int, Float)? {
    guard !isDataStale() else { return nil }
    let (products, calories, weight) = loadProducts()
    // Only return if we have actual data
    if !products.isEmpty || calories > 0 || weight > 0 {
      return (products, calories, weight)
    }
    return nil
  }

  // Fallback method to get cached data even if slightly stale (for better UX when network is slow)
  func getCachedDataAsFallback(maxStaleHours: Double = 12) -> ([Product], Int, Float)? {
    let maxStaleMinutes = maxStaleHours * 60
    guard !isDataStale(maxAgeMinutes: maxStaleMinutes) else { return nil }
    let (products, calories, weight) = loadProducts()
    // Only return if we have actual data
    if !products.isEmpty || calories > 0 || weight > 0 {
      return (products, calories, weight)
    }
    return nil
  }
  // MARK: - Health Level Cache implementation

  func saveHealthLevel(time: Int64, title: String, description: String, healthSummary: String) {
    var cache = loadHealthLevels()
    let cached = CachedHealthLevel(
      title: title, description: description, healthSummary: healthSummary)
    cache[String(time)] = cached
    saveHealthLevels(cache)
  }

  func getHealthLevel(time: Int64) -> (title: String, description: String, healthSummary: String)? {
    let cache = loadHealthLevels()
    guard let cached = cache[String(time)] else { return nil }
    return (cached.title, cached.description, cached.healthSummary)
  }

  func removeHealthLevel(time: Int64) {
    var cache = loadHealthLevels()
    cache.removeValue(forKey: String(time))
    saveHealthLevels(cache)
  }

  private func saveHealthLevels(_ cache: [String: CachedHealthLevel]) {
    if let data = try? JSONEncoder().encode(cache) {
      userDefaults.set(data, forKey: healthLevelKey)
    }
  }

  private func loadHealthLevels() -> [String: CachedHealthLevel] {
    guard let data = userDefaults.data(forKey: healthLevelKey),
      let cache = try? JSONDecoder().decode([String: CachedHealthLevel].self, from: data)
    else {
      return [:]
    }
    return cache
  }

  private func cleanupOrphanHealthLevels(validProductTimes: Set<Int64>) {
    var healthCache = loadHealthLevels()
    let validTimesStrings = Set(validProductTimes.map { String($0) })
    let keysToRemove = healthCache.keys.filter { !validTimesStrings.contains($0) }

    if !keysToRemove.isEmpty {
      for key in keysToRemove {
        healthCache.removeValue(forKey: key)
      }
      saveHealthLevels(healthCache)
    }
  }
}

// MARK: - Codable Product Data

private struct ProductData: Codable {
  let time: Int64
  let name: String
  let calories: Int
  let weight: Int
  let ingredients: [String]
  let healthRating: Int
  let imageId: String

  init(from product: Product) {
    time = product.time
    name = product.name
    calories = product.calories
    weight = product.weight
    ingredients = product.ingredients
    healthRating = product.healthRating
    imageId = product.imageId
  }

  func toProduct() -> Product {
    return Product(
      time: time,
      name: name,
      calories: calories,
      weight: weight,
      ingredients: ingredients,
      healthRating: healthRating,
      imageId: imageId
    )
  }
}
