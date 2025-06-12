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
                    // Debug logging
                    print("📱 Photo Response - Status: \(response.statusCode), PhotoType: \(photoType)")
                    if let data = data, let responseText = String(data: data, encoding: .utf8) {
                        print("📱 Response Body: \(responseText)")
                    }
                    
                    if response.statusCode >= 200 && response.statusCode < 300 {
                        // Success case - but still check for error messages in response body
                        if let data = data, let confirmationText = String(data: data, encoding: .utf8) {
                            let lowerText = confirmationText.lowercased()
                            if lowerText.contains("error") || lowerText.contains("not a") || lowerText.contains("invalid") {
                                DispatchQueue.main.async {
                                    if photoType == "weight_prompt" {
                                        AlertHelper.showAlert(title: "Scale Not Recognized", message: "We couldn't read your weight scale. Please make sure:\n• The scale display shows a clear number\n• The lighting is good\n• The scale is on a flat surface\n• Take the photo straight on")
                                    } else {
                                        AlertHelper.showAlert(title: "Food Not Recognized", message: "We couldn't identify the food in your photo. Please try taking another photo with better lighting and make sure the food is clearly visible.")
                                    }
                                }
                                completion(false)
                            } else {
                                completion(true)
                            }
                        } else {
                            completion(true)
                        }
                    } else {
                        // ANY non-2xx status code - ALWAYS show popup
                        print("📱 ERROR: Non-2xx status code \(response.statusCode), showing popup...")
                        
                        DispatchQueue.main.async {
                            print("📱 ERROR: About to show alert on main queue...")
                            
                            if photoType == "weight_prompt" {
                                print("📱 ERROR: Weight prompt error")
                                // Weight processing failed
                                if let data = data, let responseText = String(data: data, encoding: .utf8) {
                                    print("📱 ERROR: Weight error with response: \(responseText)")
                                    AlertHelper.showAlert(title: "Scale Not Recognized", message: "We couldn't read your weight scale. Please make sure:\n• The scale display shows a clear number\n• The lighting is good\n• The scale is on a flat surface\n• Take the photo straight on\n\nError: \(responseText)")
                                } else {
                                    print("📱 ERROR: Weight error without response text")
                                    AlertHelper.showAlert(title: "Scale Not Recognized", message: "We couldn't read your weight scale. Please make sure:\n• The scale display shows a clear number\n• The lighting is good\n• The scale is on a flat surface\n• Take the photo straight on")
                                }
                            } else {
                                print("📱 ERROR: Food prompt error (photoType: \(photoType))")
                                // Food processing failed - ALWAYS show popup for non-2xx
                                if let data = data, let responseText = String(data: data, encoding: .utf8) {
                                    print("📱 ERROR: Food error with response: \(responseText)")
                                    AlertHelper.showAlert(title: "Food Not Recognized", message: "We couldn't identify the food in your photo. Please try taking another photo with better lighting and make sure the food is clearly visible.\n\nError: \(responseText)")
                                } else {
                                    print("📱 ERROR: Food error without response text")
                                    AlertHelper.showAlert(title: "Food Not Recognized", message: "We couldn't identify the food in your photo. Please try taking another photo with better lighting and make sure the food is clearly visible.")
                                }
                            }
                            print("📱 ERROR: Alert should have been triggered!")
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
    
    func modifyFoodRecord(time: Int64, userEmail: String, percentage: Int32, completion: @escaping (Bool) -> Void) {
        var modifyFoodRequest = Eater_ModifyFoodRecordRequest()
        modifyFoodRequest.time = time
        modifyFoodRequest.userEmail = userEmail
        modifyFoodRequest.percentage = percentage

        do {
            let requestBody = try modifyFoodRequest.serializedData()

            guard var request = createRequest(endpoint: "modify_food_record", httpMethod: "POST", body: requestBody) else {
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
                            let modifyFoodResponse = try Eater_ModifyFoodRecordResponse(serializedBytes: data)
                            completion(modifyFoodResponse.success)
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
    
    func fetchCustomDateFood(date: String, completion: @escaping ([Product], Int, Float) -> Void) {
        var customDateRequest = Eater_CustomDateFoodRequest()
        customDateRequest.date = date

        do {
            let requestBody = try customDateRequest.serializedData()

            guard var request = createRequest(endpoint: "get_food_custom_date", httpMethod: "POST", body: requestBody) else {
                completion([], 0, 0)
                return
            }
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

            sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
                if let error = error {
                    completion([], 0, 0)
                    return
                }

                guard let data = data else {
                    completion([], 0, 0)
                    return
                }

                do {
                    let customDateFood = try Eater_CustomDateFoodResponse(serializedBytes: data)
                    let products = customDateFood.dishesForDate.map { dish in
                        Product(
                            time: dish.time,
                            name: dish.dishName,
                            calories: Int(dish.estimatedAvgCalories),
                            weight: Int(dish.totalAvgWeight),
                            ingredients: dish.ingredients
                        )
                    }
                    let remainingCalories = Int(customDateFood.totalForDay.totalCalories)
                    let personWeight = Float(customDateFood.personWeight)

                    completion(products, remainingCalories, personWeight)
                } catch {
                    completion([], 0, 0)
                }
            }
        } catch {
            completion([], 0, 0)
        }
    }
    
    func fetchStatisticsData(date: String, completion: @escaping (DailyStatistics?) -> Void) {
        var customDateRequest = Eater_CustomDateFoodRequest()
        customDateRequest.date = date

        do {
            let requestBody = try customDateRequest.serializedData()

            guard var request = createRequest(endpoint: "get_food_custom_date", httpMethod: "POST", body: requestBody) else {
                completion(nil)
                return
            }
            request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

            sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
                if let error = error {
                    completion(nil)
                    return
                }

                guard let data = data else {
                    completion(nil)
                    return
                }

                do {
                    let customDateFood = try Eater_CustomDateFoodResponse(serializedBytes: data)
                    
                    // Parse date string to Date object
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd-MM-yyyy"
                    let parsedDate = dateFormatter.date(from: date) ?? Date()
                    
                    let dailyStats = DailyStatistics(
                        date: parsedDate,
                        dateString: date,
                        totalCalories: Int(customDateFood.totalForDay.totalCalories),
                        totalFoodWeight: Int(customDateFood.totalForDay.totalAvgWeight),
                        personWeight: customDateFood.personWeight,
                        proteins: customDateFood.totalForDay.contains.proteins,
                        fats: customDateFood.totalForDay.contains.fats,
                        carbohydrates: customDateFood.totalForDay.contains.carbohydrates,
                        sugar: customDateFood.totalForDay.contains.sugar,
                        numberOfMeals: customDateFood.dishesForDate.count
                    )

                    completion(dailyStats)
                } catch {
                    completion(nil)
                }
            }
        } catch {
            completion(nil)
        }
    }
    
    func sendManualWeight(weight: Float, userEmail: String, completion: @escaping (Bool) -> Void) {
        var manualWeightRequest = Eater_ManualWeightRequest()
        manualWeightRequest.weight = weight
        manualWeightRequest.userEmail = userEmail

        do {
            let requestBody = try manualWeightRequest.serializedData()

            guard var request = createRequest(endpoint: "manual_weight", httpMethod: "POST", body: requestBody) else {
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
                            let manualWeightResponse = try Eater_ManualWeightResponse(serializedBytes: data)
                            completion(manualWeightResponse.success)
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
