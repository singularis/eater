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
    
    func fetchAndProcessProducts(tempImageTime: Int64? = nil, completion: @escaping ([Product], Int, Float) -> Void) {
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