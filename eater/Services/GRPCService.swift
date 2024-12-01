import Foundation
import SwiftProtobuf
import UIKit

class GRPCService {
    private func createRequest(endpoint: String, httpMethod: String, body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: "https://chater.singularis.work/\(endpoint)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.httpBody = body

        if let path = Bundle.main.path(forResource: "config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let token = dict["API_TOKEN"] as? String
        {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func sendRequest(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: request, completionHandler: completion)
        task.resume()
        print("Sent request to \(request.url?.absoluteString ?? "unknown URL")")
    }

    func fetchProducts(completion: @escaping ([Product], Int) -> Void) {
        print("Starting fetchProducts() gRPC call...")

        guard let request = createRequest(endpoint: "eater_get_today", httpMethod: "GET") else {
            print("Failed to create request for fetchProducts()")
            completion([], 0)
            return
        }

        let maxRetries = 0

        func attemptFetch(retriesLeft: Int) {
            sendRequest(request: request) { data, _, error in
                if let error = error {
                    print("Error fetching products: \(error.localizedDescription)")
                    if retriesLeft > 0 {
                        print("Retrying fetchProducts()... Retries left: \(retriesLeft - 1)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            attemptFetch(retriesLeft: retriesLeft - 1)
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
                            time: dish.time,
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
        }

        attemptFetch(retriesLeft: maxRetries)
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
            guard var request = createRequest(endpoint: "eater_receive_photo", httpMethod: "POST", body: serializedData) else {
                print("Failed to create request for sendPhoto()")
                completion(false)
                return
            }
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

            sendRequest(request: request) { data, response, error in
                if let error = error {
                    print("Error sending photo: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if let response = response as? HTTPURLResponse {
                    print("Response status code: \(response.statusCode)")
                    if response.statusCode == 200 {
                        if let data = data, let confirmationText = String(data: data, encoding: .utf8) {
                            print("Confirmation: \(confirmationText)")
                            if confirmationText.lowercased().contains("not a food") {
                                DispatchQueue.main.async {
                                    AlertHelper.showAlert(title: "Error", message: "The submitted photo is not food.")
                                }
                                completion(false)
                            } else {
                                completion(true)
                            }
                        }
                    } else {
                        print("sendPhoto() failed. Status code: \(response.statusCode)")
                        completion(false)
                    }
                }
            }

        } catch {
            print("Failed to serialize PhotoMessage: \(error.localizedDescription)")
            completion(false)
        }
    }

    func deleteFood(time: Int64, completion: @escaping (Bool) -> Void) {
        print("Starting deleteFood() with time: \(time)...")

        var deleteFoodRequest = Eater_DeleteFoodRequest()
        deleteFoodRequest.time = time

        do {
            let requestBody = try deleteFoodRequest.serializedData()

            // Create the HTTP request
            guard var request = createRequest(endpoint: "delete_food", httpMethod: "POST", body: requestBody) else {
                print("Failed to create request for deleteFood()")
                completion(false)
                return
            }
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")
            sendRequest(request: request) { data, response, error in
                if let error = error {
                    print("Error deleting food: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if let response = response as? HTTPURLResponse {
                    print("Response status code: \(response.statusCode)")
                    if response.statusCode == 200, let data = data {
                        do {
                            // Parse the Protobuf response
                            let deleteFoodResponse = try Eater_DeleteFoodResponse(serializedBytes: data)
                            print("Delete food response: \(deleteFoodResponse)")
                            completion(deleteFoodResponse.success)
                        } catch {
                            print("Failed to parse DeleteFoodResponse: \(error.localizedDescription)")
                            completion(false)
                        }
                    } else {
                        print("Failed to delete food. Status code: \(response.statusCode)")
                        completion(false)
                    }
                }
            }
        } catch {
            print("Failed to serialize DeleteFoodRequest: \(error.localizedDescription)")
            completion(false)
        }
    }
}
