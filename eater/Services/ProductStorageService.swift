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
            print("ProductStorageService: Saved \(products.count) products locally")
        } catch {
            print("ProductStorageService: Failed to save products - \(error)")
        }
    }
    
    func loadProducts() -> ([Product], Int, Float) {
        guard let productsData = userDefaults.data(forKey: productsKey) else {
            print("ProductStorageService: No cached products found")
            return ([], 0, 0)
        }
        
        do {
            let decoder = JSONDecoder()
            let productDataArray = try decoder.decode([ProductData].self, from: productsData)
            let products = productDataArray.map { $0.toProduct() }
            let calories = userDefaults.integer(forKey: caloriesKey)
            let weight = userDefaults.float(forKey: weightKey)
            
            print("ProductStorageService: Loaded \(products.count) products from cache")
            return (products, calories, weight)
        } catch {
            print("ProductStorageService: Failed to load products - \(error)")
            return ([], 0, 0)
        }
    }
    
    // MARK: - Fetch and Process with Image Mapping
    
    func fetchAndProcessProducts(tempImageTime: Int64? = nil, completion: @escaping ([Product], Int, Float) -> Void) {
        print("ProductStorageService: Fetching products from backend...")
        
        GRPCService().fetchProducts { [weak self] products, calories, weight in
            DispatchQueue.main.async {
                // If we have a temporary image, map it to the newest product
                if let tempTime = tempImageTime, !products.isEmpty {
                    let newestProduct = products.max(by: { $0.time < $1.time })!
                    print("ProductStorageService: Mapping image from temp_\(tempTime) to \(newestProduct.time)")
                    
                    let moved = ImageStorageService.shared.moveTemporaryImage(
                        fromTime: tempTime,
                        toTime: newestProduct.time
                    )
                    
                    if moved {
                        print("ProductStorageService: Successfully mapped image")
                    } else {
                        print("ProductStorageService: Failed to map image")
                    }
                }
                
                // Save products locally
                self?.saveProducts(products, calories: calories, weight: weight)
                
                // Return the processed data
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
        print("ProductStorageService: Cache cleared")
    }
    
    func isDataStale(maxAgeMinutes: Double = 5) -> Bool {
        let lastUpdate = userDefaults.double(forKey: lastUpdateKey)
        let ageMinutes = (Date().timeIntervalSince1970 - lastUpdate) / 60
        return ageMinutes > maxAgeMinutes
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
        self.time = product.time
        self.name = product.name
        self.calories = product.calories
        self.weight = product.weight
        self.ingredients = product.ingredients
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