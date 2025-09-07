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

  // MARK: - Save/Load Products

  func saveProducts(_ products: [Product], calories: Int, weight: Float) {
    do {
      let encoder = JSONEncoder()
      let productsData = try encoder.encode(products.map { ProductData(from: $0) })
      userDefaults.set(productsData, forKey: productsKey)
      userDefaults.set(calories, forKey: caloriesKey)
      userDefaults.set(weight, forKey: weightKey)
      userDefaults.set(Date().timeIntervalSince1970, forKey: lastUpdateKey)
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
    completion: @escaping ([Product], Int, Float) -> Void
  ) {
    // When tempImageTime is provided, we MUST force refresh to get the latest data from backend
    // and properly map the temporary image to the newest product timestamp
    let shouldForceRefresh = forceRefresh || (tempImageTime != nil)

    // Check cache first unless force refresh is requested or we have a temp image to map
    if !shouldForceRefresh, !isDataStale() {
      let (cachedProducts, cachedCalories, cachedWeight) = loadProducts()
      if !cachedProducts.isEmpty || cachedCalories > 0 || cachedWeight > 0 {
        // Return cached data immediately for better performance
        completion(cachedProducts, cachedCalories, cachedWeight)
        return
      }
    }

    // Cache is stale, empty, force refresh requested, or we need to map temp image - fetch from network
    GRPCService().fetchProducts { [weak self] products, calories, weight in
      DispatchQueue.main.async {
        // If we have a temporary image, map it to the newest product
        if let tempTime = tempImageTime, !products.isEmpty {
          let newestProduct = products.max(by: { $0.time < $1.time })!

          ImageStorageService.shared.moveTemporaryImage(
            fromTime: tempTime,
            toTime: newestProduct.time
          )
        }

        // Save products locally (only for today's data)
        self?.saveProducts(products, calories: calories, weight: weight)

        // Return the processed data
        completion(products, calories, weight)
      }
    }
  }

  func fetchAndProcessCustomDateProducts(
    date: String, completion: @escaping ([Product], Int, Float) -> Void
  ) {
    GRPCService().fetchCustomDateFood(date: date) { products, calories, weight in
      DispatchQueue.main.async {
        // Don't save custom date data to cache - only today's data should be cached
        completion(products, calories, weight)
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
}

// MARK: - Codable Product Data

private struct ProductData: Codable {
  let time: Int64
  let name: String
  let calories: Int
  let weight: Int
  let ingredients: [String]

  init(from product: Product) {
    time = product.time
    name = product.name
    calories = product.calories
    weight = product.weight
    ingredients = product.ingredients
  }

  func toProduct() -> Product {
    return Product(
      time: time,
      name: name,
      calories: calories,
      weight: weight,
      ingredients: ingredients
    )
  }
}
