import Foundation
import SwiftProtobuf
import UIKit

class GRPCService {
  private let maxRetries = 10
  private let baseDelay: TimeInterval = 10

  private func createRequest(endpoint: String, httpMethod: String, body: Data? = nil) -> URLRequest?
  {
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

  private func sendRequest(
    request: URLRequest, retriesLeft: Int,
    completion: @escaping (Data?, URLResponse?, Error?) -> Void
  ) {
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
      if error != nil {
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
            ingredients: dish.ingredients,
            healthRating: Int(dish.healthRating),
            imageId: dish.imageID
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

  func sendPhoto(
    image: UIImage, photoType: String, timestampMillis: Int64? = nil,
    completion: @escaping (Bool) -> Void
  ) {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
      completion(false)
      return
    }

    let timestamp: String
    if let timestampMillis = timestampMillis {
      // Convert millis to Date and then to ISO8601 string to ensure backend parses it correctly
      // as it handles ISO8601 natively for 'now' cases.
      let date = Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000)
      timestamp = ISO8601DateFormatter().string(from: date)
    } else {
      timestamp = ISO8601DateFormatter().string(from: Date())
    }

    var photoMessage = Eater_PhotoMessage()
    photoMessage.time = timestamp
    photoMessage.photoData = imageData
    photoMessage.photoType = photoType

    do {
      let serializedData = try photoMessage.serializedData()
      guard
        var request = createRequest(
          endpoint: "eater_receive_photo", httpMethod: "POST", body: serializedData)
      else {
        completion(false)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
          completion(false)
          return
        }

        if let response = response as? HTTPURLResponse {

          if response.statusCode >= 200, response.statusCode < 300 {
            // Success case - but still check for error messages in response body
            if let data = data, let confirmationText = String(data: data, encoding: .utf8) {
              let lowerText = confirmationText.lowercased()
              if lowerText.contains("error") || lowerText.contains("not a")
                || lowerText.contains("invalid")
              {
                DispatchQueue.main.async {
                  if photoType == "weight_prompt" {
                    AlertHelper.showAlert(
                      title: loc("error.scale.title", "Scale Not Recognized"),
                      message: loc(
                        "error.scale.msg",
                        "We couldn't read your weight scale. Please make sure:\n• The scale display shows a clear number\n• The lighting is good\n• The scale is on a flat surface\n• Take the photo straight on"
                      ))
                  } else {
                    AlertHelper.showAlert(
                      title: loc("error.food.title", "Food Not Recognized"),
                      message: loc(
                        "error.food.msg",
                        "We couldn't identify the food in your photo. Please try taking another photo with better lighting and make sure the food is clearly visible."
                      ))
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
            DispatchQueue.main.async {

              if photoType == "weight_prompt" {
                // Weight processing failed
                if let data = data, let responseText = String(data: data, encoding: .utf8) {
                  let base = loc(
                    "error.scale.msg",
                    "We couldn't read your weight scale. Please make sure:\n• The scale display shows a clear number\n• The lighting is good\n• The scale is on a flat surface\n• Take the photo straight on"
                  )
                  let msg = base + "\n\n" + loc("common.error", "Error") + ": " + responseText
                  AlertHelper.showAlert(
                    title: loc("error.scale.title", "Scale Not Recognized"), message: msg)
                } else {
                  AlertHelper.showAlert(
                    title: loc("error.scale.title", "Scale Not Recognized"),
                    message: loc(
                      "error.scale.msg",
                      "We couldn't read your weight scale. Please make sure:\n• The scale display shows a clear number\n• The lighting is good\n• The scale is on a flat surface\n• Take the photo straight on"
                    ))
                }
              } else {
                // Food processing failed - ALWAYS show popup for non-2xx
                if let data = data, let responseText = String(data: data, encoding: .utf8) {
                  let base = loc(
                    "error.food.msg",
                    "We couldn't identify the food in your photo. Please try taking another photo with better lighting and make sure the food is clearly visible."
                  )
                  let msg = base + "\n\n" + loc("common.error", "Error") + ": " + responseText
                  AlertHelper.showAlert(
                    title: loc("error.food.title", "Food Not Recognized"), message: msg)
                } else {
                  AlertHelper.showAlert(
                    title: loc("error.food.title", "Food Not Recognized"),
                    message: loc(
                      "error.food.msg",
                      "We couldn't identify the food in your photo. Please try taking another photo with better lighting and make sure the food is clearly visible."
                    ))
                }
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

      guard
        var request = createRequest(endpoint: "delete_food", httpMethod: "POST", body: requestBody)
      else {
        completion(false)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
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

      guard
        var request = createRequest(
          endpoint: "get_recommendation", httpMethod: "POST", body: requestBody)
      else {
        completion("")
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
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

      guard
        var request = createRequest(endpoint: "delete_user", httpMethod: "POST", body: requestBody)
      else {
        completion(false)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
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

  func modifyFoodRecord(
    time: Int64, 
    userEmail: String, 
    percentage: Int32, 
    isTryAgain: Bool = false,
    imageId: String = "",
    addedSugarTsp: Float = 0,
    completion: @escaping (Bool) -> Void
  ) {
    var modifyFoodRequest = Eater_ModifyFoodRecordRequest()
    modifyFoodRequest.time = time
    modifyFoodRequest.userEmail = userEmail
    modifyFoodRequest.percentage = percentage
    modifyFoodRequest.isTryAgain = isTryAgain
    modifyFoodRequest.imageID = imageId
    modifyFoodRequest.addedSugarTsp = addedSugarTsp

    do {
      let requestBody = try modifyFoodRequest.serializedData()

      guard
        var request = createRequest(
          endpoint: "modify_food_record", httpMethod: "POST", body: requestBody)
      else {
        completion(false)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
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

      guard
        var request = createRequest(
          endpoint: "get_food_custom_date", httpMethod: "POST", body: requestBody)
      else {
        completion([], 0, 0)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, _, error in
        if error != nil {
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
              ingredients: dish.ingredients,
              healthRating: Int(dish.healthRating),
              imageId: dish.imageID
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

      guard
        var request = createRequest(
          endpoint: "get_food_custom_date", httpMethod: "POST", body: requestBody)
      else {
        completion(nil)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, _, error in
        if error != nil {
          completion(nil)
          return
        }

        guard let data = data else {
          completion(nil)
          return
        }

        do {
          let customDateFood = try Eater_CustomDateFoodResponse(serializedBytes: data)

          let dateFormatter = DateFormatter()
          dateFormatter.dateFormat = "dd-MM-yyyy"
          let parsedDate = dateFormatter.date(from: date) ?? Date()

          let totalCalories = Int(customDateFood.totalForDay.totalCalories)
          let totalWeight = Int(customDateFood.totalForDay.totalAvgWeight)
          let numberOfMeals = customDateFood.dishesForDate.count
          let personWeight = customDateFood.personWeight
          let proteins = customDateFood.totalForDay.contains.proteins
          let fats = customDateFood.totalForDay.contains.fats
          let carbs = customDateFood.totalForDay.contains.carbohydrates

          let hasActualData =
            numberOfMeals > 0 || (totalCalories > 0 && (proteins > 0 || fats > 0 || carbs > 0))

          let dailyStats = DailyStatistics(
            date: parsedDate,
            dateString: date,
            totalCalories: totalCalories,
            totalFoodWeight: totalWeight,
            personWeight: personWeight,
            proteins: proteins,
            fats: fats,
            carbohydrates: carbs,
            sugar: customDateFood.totalForDay.contains.sugar,
            numberOfMeals: numberOfMeals,
            hasData: hasActualData
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

      guard
        var request = createRequest(
          endpoint: "manual_weight", httpMethod: "POST", body: requestBody)
      else {
        completion(false)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
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

  func fetchTodayStatistics(completion: @escaping (DailyStatistics?) -> Void) {
    guard let request = createRequest(endpoint: "eater_get_today", httpMethod: "GET") else {
      completion(nil)
      return
    }

    sendRequest(request: request, retriesLeft: maxRetries) { data, _, error in
      if error != nil {
        completion(nil)
        return
      }

      guard let data = data else {
        completion(nil)
        return
      }

      do {
        let todayFood = try TodayFood(serializedBytes: data)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let todayString = dateFormatter.string(from: Date())

        let totalCalories = Int(todayFood.totalForDay.totalCalories)
        let totalWeight = Int(todayFood.totalForDay.totalAvgWeight)
        let numberOfMeals = todayFood.dishesToday.count
        let personWeight = todayFood.personWeight
        let proteins = todayFood.totalForDay.contains.proteins
        let fats = todayFood.totalForDay.contains.fats
        let carbs = todayFood.totalForDay.contains.carbohydrates
        let sugar = todayFood.totalForDay.contains.sugar

        let hasActualData =
          numberOfMeals > 0 || (totalCalories > 0 && (proteins > 0 || fats > 0 || carbs > 0))

        let dailyStats = DailyStatistics(
          date: Date(),
          dateString: todayString,
          totalCalories: totalCalories,
          totalFoodWeight: totalWeight,
          personWeight: personWeight,
          proteins: proteins,
          fats: fats,
          carbohydrates: carbs,
          sugar: sugar,
          numberOfMeals: numberOfMeals,
          hasData: hasActualData
        )

        completion(dailyStats)
      } catch {
        completion(nil)
      }
    }
  }

  func submitFeedback(
    time: String, userEmail: String, feedback: String, completion: @escaping (Bool) -> Void
  ) {
    var feedbackRequest = Eater_FeedbackRequest()
    feedbackRequest.time = time
    feedbackRequest.userEmail = userEmail
    feedbackRequest.feedback = feedback

    do {
      let requestBody = try feedbackRequest.serializedData()

      guard var request = createRequest(endpoint: "feedback", httpMethod: "POST", body: requestBody)
      else {
        completion(false)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
          completion(false)
          return
        }

        if let response = response as? HTTPURLResponse {
          if response.statusCode == 200, let data = data {
            do {
              let feedbackResponse = try Eater_FeedbackResponse(serializedBytes: data)
              completion(feedbackResponse.success)
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

  func addFriend(email: String, completion: @escaping (Bool) -> Void) {
    var addFriendRequest = Eater_AddFriendRequest()
    addFriendRequest.email = email

    do {
      let requestBody = try addFriendRequest.serializedData()

      guard
        var request = createRequest(
          endpoint: "autocomplete/addfriend", httpMethod: "POST", body: requestBody)
      else {
        completion(false)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
          completion(false)
          return
        }

        if let response = response as? HTTPURLResponse {
          if response.statusCode == 200, let data = data {
            do {
              let addFriendResponse = try Eater_AddFriendResponse(serializedBytes: data)
              completion(addFriendResponse.success)
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

  func getFriends(offset: Int = 0, limit: Int = 5, completion: @escaping ([(email: String, nickname: String)], Int) -> Void) {
    // Backend returns full list via GET; we will slice client-side using offset/limit
    guard let request = createRequest(endpoint: "autocomplete/getfriend", httpMethod: "GET") else {
      completion([], 0)
      return
    }
    sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
      if error != nil {
        completion([], 0)
        return
      }
      if let response = response as? HTTPURLResponse, response.statusCode == 200, let data = data {
        do {
          let resp = try Eater_GetFriendsResponse(serializedBytes: data)
          let allFriends = resp.friends.map { (email: $0.email, nickname: $0.nickname) }
          let total = Int(resp.count)
          let start = max(0, min(offset, allFriends.count))
          let end = max(start, min(start + max(0, limit), allFriends.count))
          let slice = Array(allFriends[start..<end])
          completion(slice, total)
        } catch {
          completion([], 0)
        }
      } else {
        completion([], 0)
      }
    }
  }

  func shareFood(
    time: Int64, fromEmail: String, toEmail: String, percentage: Int32,
    completion: @escaping (Bool, String?) -> Void
  ) {
    var req = Eater_ShareFoodRequest()
    req.time = time
    req.fromEmail = fromEmail
    req.toEmail = toEmail
    req.percentage = percentage
    do {
      let body = try req.serializedData()
      guard
        var request = createRequest(
          endpoint: "autocomplete/sharefood", httpMethod: "POST", body: body)
      else {
        completion(false, nil)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")
      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
          completion(false, nil)
          return
        }
        if let response = response as? HTTPURLResponse, response.statusCode == 200, let data = data
        {
          do {
            let resp = try Eater_ShareFoodResponse(serializedBytes: data)
            completion(resp.success, resp.nicknameUsed)
          } catch {
            completion(false, nil)
          }
        } else {
          completion(false, nil)
        }
      }
    } catch {
      completion(false, nil)
    }
  }

  // MARK: - Alcohol

  func fetchAlcoholLatest(completion: @escaping (Eater_GetAlcoholLatestResponse?) -> Void) {
    guard var request = createRequest(endpoint: "alcohol_latest", httpMethod: "GET") else {
      completion(nil)
      return
    }
    request.addValue("application/grpc+proto", forHTTPHeaderField: "Accept")

    sendRequest(request: request, retriesLeft: maxRetries) { data, _, error in
      if error != nil {
        completion(nil)
        return
      }
      guard let data = data else {
        completion(nil)
        return
      }
      do {
        let resp = try Eater_GetAlcoholLatestResponse(serializedBytes: data)
        completion(resp)
      } catch {
        completion(nil)
      }
    }
  }

  func fetchAlcoholRange(
    startDateDDMMYYYY: String, endDateDDMMYYYY: String,
    completion: @escaping (Eater_GetAlcoholRangeResponse?) -> Void
  ) {
    var req = Eater_GetAlcoholRangeRequest()
    req.startDate = startDateDDMMYYYY
    req.endDate = endDateDDMMYYYY
    do {
      let body = try req.serializedData()
      guard var request = createRequest(endpoint: "alcohol_range", httpMethod: "POST", body: body)
      else {
        completion(nil)
        return
      }
      request.addValue("application/grpc+proto", forHTTPHeaderField: "Content-Type")
      request.addValue("application/grpc+proto", forHTTPHeaderField: "Accept")

      sendRequest(request: request, retriesLeft: maxRetries) { data, _, error in
        if error != nil {
          completion(nil)
          return
        }
        guard let data = data else {
          completion(nil)
          return
        }
        do {
          let resp = try Eater_GetAlcoholRangeResponse(serializedBytes: data)
          completion(resp)
        } catch {
          completion(nil)
        }
      }
    } catch {
      completion(nil)
    }
  }

  // MARK: - Language

  func setLanguage(userEmail: String, languageCode: String, completion: @escaping (Bool) -> Void) {
    var req = Eater_SetLanguageRequest()
    req.userEmail = userEmail
    req.languageCode = languageCode
    do {
      let body = try req.serializedData()
      guard var request = createRequest(endpoint: "set_language", httpMethod: "POST", body: body)
      else {
        completion(false)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")
      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
          completion(false)
          return
        }
        if let response = response as? HTTPURLResponse, response.statusCode == 200, let data = data
        {
          do {
            let resp = try Eater_SetLanguageResponse(serializedBytes: data)
            completion(resp.success)
          } catch {
            completion(false)
          }
        } else {
          completion(false)
        }
      }
    } catch {
      completion(false)
    }
  }

  func getFoodHealthLevel(time: Int64, foodName: String, completion: @escaping (Eater_FoodHealthLevelResponse?) -> Void) {
    var healthLevelRequest = Eater_FoodHealthLevelRequest()
    healthLevelRequest.time = time
    healthLevelRequest.foodName = foodName

    do {
      let requestBody = try healthLevelRequest.serializedData()

      guard
        var request = createRequest(
          endpoint: "food_health_level", httpMethod: "POST", body: requestBody)
      else {
        completion(nil)
        return
      }
      request.addValue("application/protobuf", forHTTPHeaderField: "Content-Type")

      sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
        if error != nil {
          completion(nil)
          return
        }

        if let response = response as? HTTPURLResponse {
          if response.statusCode == 200, let data = data {
            do {
              let healthLevelResponse = try Eater_FoodHealthLevelResponse(serializedBytes: data)
              completion(healthLevelResponse)
            } catch {
              completion(nil)
            }
          } else {
            completion(nil)
          }
        }
      }
    } catch {
     completion(nil)
    }
  }

  // MARK: - Nickname Update
  
  func updateNickname(nickname: String, completion: @escaping (Bool, String?) -> Void) {
    guard let url = URL(string: "https://chater.singularis.work/nickname_update") else {
      completion(false, "Invalid URL")
      return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    if let token = UserDefaults.standard.string(forKey: "auth_token") {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    let body: [String: Any] = ["nickname": nickname]
    
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
    } catch {
      completion(false, "Failed to encode request")
      return
    }
    
    sendRequest(request: request, retriesLeft: maxRetries) { data, response, error in
      if let error = error {
        completion(false, error.localizedDescription)
        return
      }
      
      if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode == 200 {
          completion(true, nil)
        } else {
          let errorMsg = "Server returned status code \(httpResponse.statusCode)"
          completion(false, errorMsg)
        }
      } else {
        completion(false, "Invalid response")
      }
    }
  }
}

