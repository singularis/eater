import Foundation
import UIKit
import SwiftProtobuf

class GRPCService {

    func fetchProducts(completion: @escaping ([Product], Int) -> Void) {
        fetchProducts(retries: 3, completion: completion)
    }

    private func fetchProducts(retries: Int, completion: @escaping ([Product], Int) -> Void) {
        print("Starting fetchProducts() gRPC call...")

        var request = URLRequest(url: URL(string: "https://chater.singularis.work/eater_get_today")!)
        request.httpMethod = "GET"
        if let path = Bundle.main.path(forResource: "config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let token = dict["API_TOKEN"] as? String {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching products: \(error.localizedDescription)")
                if retries > 0 {
                    print("Retrying fetchProducts()...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.fetchProducts(retries: retries - 1, completion: completion)
                    }
                } else {
                    print("Max retries reached. Giving up.")
                    completion([], 0)
                }
                return
            }

            guard let data = data else {
                print("No data received from fetchProducts()")
                completion([], 0)
                return
            }

            do {
                let todayFood = try TodayFood(serializedBytes: data)
                let products = todayFood.dishesToday.map { dish in
                    Product(
                        name: dish.dishName,
                        calories: Int(dish.estimatedAvgCalories),
                        weight: Int(dish.totalAvgWeight),
                        ingredients: dish.ingredients
                    )
                }
                let remainingCalories = Int(todayFood.totalForDay.totalCalories)

                print("Fetched products: \(products)")
                print("Remaining calories: \(remainingCalories)")

                completion(products, remainingCalories)
            } catch {
                print("Failed to parse TodayFood: \(error.localizedDescription)")
                completion([], 0)
            }
        }

        task.resume()
        print("Completed fetchProducts() call.")
    }

    func sendPhoto(image: UIImage, completion: @escaping (Bool) -> Void) {
        print("Starting sendPhoto() with image...")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert UIImage to Data.")
            completion(false)
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        var photoMessage = Eater_PhotoMessage()
        photoMessage.time = timestamp
        photoMessage.photoData = imageData
        do {
            let serializedData = try photoMessage.serializedData()
            var request = URLRequest(url: URL(string: "https://chater.singularis.work/eater_receive_photo")!)
            request.httpMethod = "POST"
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")
            if let path = Bundle.main.path(forResource: "config", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path),
               let token = dict["API_TOKEN"] as? String {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = serializedData
            func sendRequest(retriesRemaining: Int) {
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("Error sending photo: \(error.localizedDescription)")
                        if retriesRemaining > 0 {
                            print("Retrying sendPhoto() in 20 seconds...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                sendRequest(retriesRemaining: retriesRemaining - 1)
                            }
                        } else {
                            print("Max retries reached. sendPhoto() failed.")
                            completion(false)
                        }
                        return
                    }

                    if let response = response as? HTTPURLResponse {
                        print("Response status code: \(response.statusCode)")
                        if response.statusCode == 200 {
                            if let data = data, let confirmationText = String(data: data, encoding: .utf8) {
                                print("Confirmation \(confirmationText)")
                                completion(true)
                            }
                        } else {
                            if retriesRemaining > 0 {
                                print("Retrying sendPhoto() in 20 seconds...")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                    sendRequest(retriesRemaining: retriesRemaining - 1)
                                }
                            } else {
                                print("Max retries reached. sendPhoto() failed.")
                                completion(false)
                            }
                        }
                    }
                }
                task.resume()
            }

            sendRequest(retriesRemaining: 3)
        } catch {
            print("Failed to serialize PhotoMessage: \(error.localizedDescription)")
            completion(false)
        }

        print("Completed sendPhoto() method.")
    }
}
