import Foundation
import UIKit
import SwiftProtobuf

class GRPCService {
    func fetchProducts(completion: @escaping ([Product], Int) -> Void) {
        print("Starting fetchProducts() gRPC call...")

        var request = URLRequest(url: URL(string: "https://chater.singularis.work/eater_get_today")!)
        request.httpMethod = "GET"
        if let path = Bundle.main.path(forResource: "config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let token = dict["API_TOKEN"] as? String {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching products: \(error.localizedDescription)")
                completion([], 0) // Return empty array and 0 calories on error
                return
            }

            guard let data = data else {
                print("No data received from fetchProducts()")
                completion([], 0) // Return empty array and 0 calories on error
                return
            }

            // Parse the response data
            do {
                let todayFood = try TodayFood(serializedBytes: data)

                // Map TodayFood to [Product]
                let products = todayFood.dishesToday.map { dish in
                    Product(
                        name: dish.dishName,
                        calories: Int(dish.estimatedAvgCalories),
                        weight: Int(dish.totalAvgWeight),
                        ingredients: dish.ingredients
                    )
                }

                // Get remainingCalories from TodayFood
                let remainingCalories = Int(todayFood.totalForDay.totalCalories)

                print("Fetched products: \(products)")
                print("Remaining calories: \(remainingCalories)")

                completion(products, remainingCalories)
            } catch {
                print("Failed to parse TodayFood: \(error.localizedDescription)")
                completion([], 0) // Return empty array and 0 calories on error
            }
        }

        task.resume()
        print("Completed fetchProducts() call.")
    }

    func sendPhoto(image: UIImage) {
        print("Starting sendPhoto() with image...")

        // Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert UIImage to Data.")
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        var photoMessage = Eater_PhotoMessage() // Now this should be recognized
        photoMessage.time = timestamp
        photoMessage.photoData = imageData
        do {
            let serializedData = try photoMessage.serializedData()


            
            // Send serialized data as POST body
            var request = URLRequest(url: URL(string: "https://chater.singularis.work/eater_receive_photo")!)
            request.httpMethod = "POST"
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")
            if let path = Bundle.main.path(forResource: "config", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path),
               let token = dict["API_TOKEN"] as? String {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = serializedData

            // Send the request
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error sending photo: \(error.localizedDescription)")
                    return
                }

                if let response = response as? HTTPURLResponse {
                    print("Response status code: \(response.statusCode)")
                }

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
            }

            task.resume()
        } catch {
            print("Failed to serialize PhotoMessage: \(error.localizedDescription)")
        }

        print("Completed sendPhoto() method.")
    }
}
