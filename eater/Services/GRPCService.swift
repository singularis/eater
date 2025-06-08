import Foundation
import SwiftProtobuf
import UIKit

class GRPCService {
    private let maxRetries = 10
    private let baseDelay: TimeInterval = 10

    private func createRequest(endpoint: String, httpMethod: String, body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: "https://chater.singularis.work/\(endpoint)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.httpBody = body

        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func sendRequest(request: URLRequest, retriesLeft: Int, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                if retriesLeft > 0 {
                    let delay = self.baseDelay * pow(2, Double(self.maxRetries - retriesLeft))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.sendRequest(request: request, retriesLeft: retriesLeft - 1, completion: completion)
                    }
                } else {
                    completion(nil, nil, error)
                }
            } else {
                completion(data, response, error)
            }
        }
        task.resume()
    }

    func fetchProducts(completion: @escaping ([Product], Int, Float) -> Void) {
        guard let request = createRequest(endpoint: "eater_get_today", httpMethod: "GET") else {
            completion([], 0, 0)
            return
        }

        sendRequest(request: request, retriesLeft: maxRetries) { data, _, error in
            if let error = error {
                completion([], 0, 0)
                return
            }

            guard let data = data else {
                completion([], 0, 0)
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
                let persohWeight = Float(todayFood.personWeight)

                completion(products, remainingCalories, persohWeight)
            } catch {
                completion([], 0, 0)
            }
        }
    }

    func sendPhoto(image: UIImage, photoType: String, timestampMillis: Int64? = nil, completion: @escaping (Bool) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(false)
            return
        }

        let timestamp: String
        if let timestampMillis = timestampMillis {
            timestamp = String(timestampMillis)
        } else {
            timestamp = ISO8601DateFormatter().string(from: Date())
        }
        
        var photoMessage = Eater_PhotoMessage()
        photoMessage.time = timestamp
        photoMessage.photoData = imageData
        photoMessage.photoType = photoType

        do {
            let serializedData = try photoMessage.serializedData()
            guard var request = createRequest(endpoint: "eater_receive_photo", httpMethod: "POST", body: serializedData) else {
                completion(false)
                return
            }
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

            sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
                if let error = error {
                    completion(false)
                    return
                }

                if let response = response as? HTTPURLResponse {
                    if response.statusCode == 200, let data = data, let confirmationText = String(data: data, encoding: .utf8) {
                        if confirmationText.lowercased().contains("not a") {
                            DispatchQueue.main.async {
                                if photoType == "weight_prompt" {
                                    AlertHelper.showAlert(title: "Scale Not Recognized", message: "We couldn't read your weight scale. Please make sure the scale display is clearly visible and well-lit.")
                                } else {
                                    AlertHelper.showAlert(title: "Food Not Recognized", message: confirmationText)
                                }
                            }
                            completion(false)
                        } else {
                            completion(true)
                        }
                        return
                    } else {
                        DispatchQueue.main.async {
                            if photoType == "weight_prompt" {
                                AlertHelper.showAlert(title: "Scale Not Recognized", message: "We couldn't read your weight scale. Please make sure:\n• The scale display is clearly visible\n• The lighting is good\n• The scale is on a flat surface\n• The display is not blurry")
                            } else {
                                AlertHelper.showAlert(title: "Food Not Recognized", message: "We couldn't identify the food in your photo. Please try taking another photo with better lighting and make sure the food is clearly visible.")
                            }
                        }
                        completion(false)
                    }
                }
            }

        } catch {
            completion(false)
        }
    }

    func deleteFood(time: Int64, completion: @escaping (Bool) -> Void) {
        var deleteFoodRequest = Eater_DeleteFoodRequest()
        deleteFoodRequest.time = time

        do {
            let requestBody = try deleteFoodRequest.serializedData()

            guard var request = createRequest(endpoint: "delete_food", httpMethod: "POST", body: requestBody) else {
                completion(false)
                return
            }
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

            sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
                if let error = error {
                    completion(false)
                    return
                }

                if let response = response as? HTTPURLResponse {
                    if response.statusCode == 200, let data = data {
                        do {
                            let deleteFoodResponse = try Eater_DeleteFoodResponse(serializedBytes: data)
                            completion(deleteFoodResponse.success)
                        } catch {
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }
                }
            }
        } catch {
            completion(false)
        }
    }
    
    func getRecommendation(days: Int32, completion: @escaping (String) -> Void) {
        var recommendationRequest = Eater_RecommendationRequest()
        recommendationRequest.days = days

        do {
            let requestBody = try recommendationRequest.serializedData()

            guard var request = createRequest(endpoint: "get_recommendation", httpMethod: "POST", body: requestBody) else {
                completion("")
                return
            }
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

            sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
                if let error = error {
                    completion("")
                    return
                }

                if let response = response as? HTTPURLResponse {
                    if response.statusCode == 200, let data = data {
                        do {
                            let recommendationResponse = try Eater_RecommendationResponse(serializedBytes: data)
                            completion(recommendationResponse.recommendation)
                        } catch {
                            completion("")
                        }
                    } else {
                        completion("")
                    }
                }
            }
        } catch {
            completion("")
        }
    }
    
    func deleteUser(email: String, completion: @escaping (Bool) -> Void) {
        var deleteUserRequest = Eater_DeleteUserRequest()
        deleteUserRequest.email = email

        do {
            let requestBody = try deleteUserRequest.serializedData()

            guard var request = createRequest(endpoint: "delete_user", httpMethod: "POST", body: requestBody) else {
                completion(false)
                return
            }
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

            sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
                if let error = error {
                    completion(false)
                    return
                }

                if let response = response as? HTTPURLResponse {
                    if response.statusCode == 200, let data = data {
                        do {
                            let deleteUserResponse = try Eater_DeleteUserResponse(serializedBytes: data)
                            completion(deleteUserResponse.success)
                        } catch {
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }
                }
            }
        } catch {
            completion(false)
        }
    }
}
