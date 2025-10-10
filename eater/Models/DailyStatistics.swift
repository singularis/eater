import Foundation

struct DailyStatistics: Identifiable, Equatable {
  let id = UUID()
  let date: Date
  let dateString: String  // Format: dd-MM-yyyy
  let totalCalories: Int
  let totalFoodWeight: Int  // in grams
  let personWeight: Float  // in kg
  let proteins: Double  // in grams
  let fats: Double  // in grams
  let carbohydrates: Double  // in grams
  let sugar: Double  // in grams
  let numberOfMeals: Int
  let hasData: Bool  // Indicates if this day has actual data vs empty placeholder

  init(
    date: Date, dateString: String, totalCalories: Int, totalFoodWeight: Int, personWeight: Float,
    proteins: Double, fats: Double, carbohydrates: Double, sugar: Double, numberOfMeals: Int,
    hasData: Bool = true
  ) {
    self.date = date
    self.dateString = dateString
    self.totalCalories = totalCalories
    self.totalFoodWeight = totalFoodWeight
    self.personWeight = personWeight
    self.proteins = proteins
    self.fats = fats
    self.carbohydrates = carbohydrates
    self.sugar = sugar
    self.numberOfMeals = numberOfMeals
    self.hasData = hasData
  }

  // Computed properties for additional insights
  var caloriesPerGram: Double {
    guard totalFoodWeight > 0 else { return 0 }
    return Double(totalCalories) / Double(totalFoodWeight)
  }

  var proteinCalories: Double {
    return proteins * 4  // 1g protein = 4 calories
  }

  var fatCalories: Double {
    return fats * 9  // 1g fat = 9 calories
  }

  var carbohydrateCalories: Double {
    return carbohydrates * 4  // 1g carb = 4 calories
  }

  var fiber: Double {
    // Estimate fiber as a portion of carbohydrates (rough approximation)
    return carbohydrates * 0.15  // Assume 15% of carbs are fiber
  }
}

enum StatisticsPeriod: String, CaseIterable {
  case week = "7 days"
  case month = "30 days"
  case twoMonths = "2 months"
  case threeMonths = "3 months"

  var days: Int {
    switch self {
    case .week: return 7
    case .month: return 30
    case .twoMonths: return 60
    case .threeMonths: return 90
    }
  }
}

