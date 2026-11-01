import Foundation

/// Single source for calorie plan math. Health settings, onboarding, the
/// progressive setup sheet and Home all call this so they agree on one number.
enum HealthPlanCalculator {
  enum Goal: String, CaseIterable {
    case lose
    case maintain
    case gain
    case activityOnly
  }

  /// Mifflin-St Jeor needs a sex constant. Average is the middle of the two.
  enum Sex: String {
    case male
    case female
    case average

    var bmrConstant: Double {
      switch self {
      case .male: return 5
      case .female: return -161
      case .average: return -78
      }
    }

    var calorieFloor: Int {
      switch self {
      case .male: return 1500
      case .female: return 1200
      case .average: return 1350
      }
    }
  }

  struct Body {
    let heightCm: Double
    let weightKg: Double
    let age: Int
    let sex: Sex
    let activityLevel: String
  }

  struct Plan {
    let calories: Int
    let goal: Goal
    let targetKg: Double
    let months: Int
  }

  static let heightRange: ClosedRange<Double> = 100...250
  static let weightRange: ClosedRange<Double> = 20...300
  static let ageRange: ClosedRange<Int> = 10...120
  static let bmiMin = 18.5
  static let bmiMaxStandard = 24.9
  static let bmiMaxGain = 27.0
  static let optimalBMI = 21.5
  static let kcalPerKg = 7700.0
  static let hardLimitFactor = 1.15

  static let activityLevels = [
    "Sedentary", "Lightly Active", "Moderately Active", "Very Active", "Extremely Active",
  ]

  static func activityMultiplier(_ level: String) -> Double {
    // Apple Health already adds real burn, so the base stays sedentary.
    if UserDefaults.standard.bool(forKey: "apple_health_activity_enabled") {
      return 1.2
    }
    switch level {
    case "Lightly Active": return 1.375
    case "Moderately Active": return 1.55
    case "Very Active": return 1.725
    case "Extremely Active": return 1.9
    default: return 1.2
    }
  }

  /// Mifflin-St Jeor.
  static func bmr(_ body: Body) -> Double {
    let base = 10 * body.weightKg + 6.25 * body.heightCm - 5 * Double(body.age)
    return base + body.sex.bmrConstant
  }

  static func tdee(_ body: Body) -> Double {
    bmr(body) * activityMultiplier(body.activityLevel)
  }

  static func minCalories(sex: Sex) -> Int {
    sex.calorieFloor
  }

  static func bmi(heightCm: Double, weightKg: Double) -> Double {
    let meters = heightCm / 100.0
    guard meters > 0 else { return 0 }
    return weightKg / (meters * meters)
  }

  static func weight(forBMI bmi: Double, heightCm: Double) -> Double {
    let meters = heightCm / 100.0
    return bmi * meters * meters
  }

  static func optimalWeight(heightCm: Double) -> Double {
    weight(forBMI: optimalBMI, heightCm: heightCm)
  }

  static func bmiCap(for goal: Goal) -> Double {
    goal == .gain ? bmiMaxGain : bmiMaxStandard
  }

  static func healthyTargetRange(heightCm: Double, goal: Goal) -> ClosedRange<Double> {
    weight(forBMI: bmiMin, heightCm: heightCm)...weight(forBMI: bmiCap(for: goal), heightCm: heightCm)
  }

  /// Shortest safe period for a weight change.
  static func minMonths(forChangeKg diff: Double) -> Int {
    let absDiff = abs(diff)
    if absDiff <= 5 { return 2 }
    if absDiff <= 10 { return 4 }
    return 6
  }

  static func monthOptions(forChangeKg diff: Double) -> [Int] {
    let absDiff = abs(diff)
    if absDiff <= 1 { return [2] }
    if absDiff <= 5 { return [2, 4, 6] }
    if absDiff <= 10 { return [4, 6] }
    return [6, 9, 12]
  }

  static func calories(body: Body, goal: Goal, targetKg: Double, months: Int) -> Int {
    let tdee = tdee(body)
    switch goal {
    case .maintain, .activityOnly:
      return Int(tdee.rounded())
    case .lose, .gain:
      let diff = targetKg - body.weightKg
      guard abs(diff) >= 0.1 else { return Int(tdee.rounded()) }
      let safeMonths = max(months, minMonths(forChangeKg: diff))
      let days = Double(safeMonths) * 30.4
      let proposed = tdee + (diff * kcalPerKg) / days
      return max(Int(proposed.rounded()), minCalories(sex: body.sex))
    }
  }

  /// Goal used when the user has not picked one: head for a mid-healthy BMI
  /// at the slowest safe pace, or maintain when already close.
  static func defaultPlan(body: Body) -> Plan {
    let optimal = (optimalWeight(heightCm: body.heightCm) * 10).rounded() / 10
    let diff = optimal - body.weightKg
    if abs(diff) <= 2 {
      return Plan(calories: calories(body: body, goal: .maintain, targetKg: body.weightKg, months: 0),
                  goal: .maintain, targetKg: body.weightKg, months: 0)
    }
    let goal: Goal = diff < 0 ? .lose : .gain
    let months = minMonths(forChangeKg: diff)
    return Plan(calories: calories(body: body, goal: goal, targetKg: optimal, months: months),
                goal: goal, targetKg: optimal, months: months)
  }

  // MARK: - Stored profile

  static func storedBody(_ defaults: UserDefaults = .standard) -> Body? {
    let height = defaults.double(forKey: "userHeight")
    let weight = defaults.double(forKey: "userWeight")
    let age = defaults.integer(forKey: "userAge")
    guard height > 0, weight > 0, age > 0 else { return nil }
    return Body(
      heightCm: height,
      weightKg: weight,
      age: age,
      sex: storedSex(defaults),
      activityLevel: defaults.string(forKey: "userActivityLevel") ?? "Sedentary"
    )
  }

  /// Plan from the stored goal, or the default plan when no goal was saved.
  static func storedPlan(body: Body, _ defaults: UserDefaults = .standard) -> Plan {
    guard let raw = defaults.string(forKey: "userGoalMode"), let goal = Goal(rawValue: raw) else {
      return defaultPlan(body: body)
    }
    let target = defaults.double(forKey: "userTargetWeight")
    let resolvedTarget = target > 0 ? target : body.weightKg
    let months = defaults.integer(forKey: "userGoalMonths")
    let kcal = calories(body: body, goal: goal, targetKg: resolvedTarget, months: months)
    return Plan(calories: kcal, goal: goal, targetKg: resolvedTarget, months: months)
  }

  /// Writes the profile, goal and auto calorie limits. Clears any manual limit.
  static func save(body: Body, plan: Plan, _ defaults: UserDefaults = .standard) {
    let previousTarget = defaults.double(forKey: "userTargetWeight")
    let previousGoal = defaults.string(forKey: "userGoalMode") ?? ""
    let targetStored = (plan.targetKg * 10).rounded() / 10

    defaults.set(body.heightCm.rounded(), forKey: "userHeight")
    defaults.set((body.weightKg * 10).rounded() / 10, forKey: "userWeight")
    defaults.set(body.age, forKey: "userAge")
    defaults.set(body.sex.rawValue, forKey: "userSex")
    defaults.set(body.sex == .male, forKey: "userIsMale")
    defaults.set(body.activityLevel, forKey: "userActivityLevel")
    defaults.set(targetStored, forKey: "userTargetWeight")
    defaults.set(optimalWeight(heightCm: body.heightCm), forKey: "userOptimalWeight")
    defaults.set(plan.goal.rawValue, forKey: "userGoalMode")
    defaults.set((plan.goal == .lose || plan.goal == .gain) ? plan.months : 0, forKey: "userGoalMonths")
    defaults.set(plan.calories, forKey: "userRecommendedCalories")
    defaults.set(true, forKey: "hasUserHealthData")
    if abs(previousTarget - targetStored) > 0.05 || previousGoal != plan.goal.rawValue {
      defaults.removeObject(forKey: "goalCelebratedTargetKg")
    }
    applyLimits(calories: plan.calories, defaults)
  }

  static func storedSex(_ defaults: UserDefaults = .standard) -> Sex {
    if let raw = defaults.string(forKey: "userSex"), let sex = Sex(rawValue: raw) {
      return sex
    }
    if defaults.object(forKey: "userIsMale") != nil {
      return defaults.bool(forKey: "userIsMale") ? .male : .female
    }
    return .male
  }

  static func applyLimits(calories: Int, _ defaults: UserDefaults = .standard) {
    let hard = Int(Double(calories) * hardLimitFactor)
    defaults.set(calories, forKey: "softLimit")
    defaults.set(hard, forKey: "hardLimit")
    defaults.set(false, forKey: "hasManualCalorieLimits")
    CalorieLimitsStorageService.shared.save(
      .init(softLimit: calories, hardLimit: hard, hasManualCalorieLimits: false))
  }
}

/// Metric is stored; imperial is display only.
enum HealthUnits {
  static let kgPerLb = 0.45359237
  static let cmPerInch = 2.54

  static var imperial: Bool {
    UserDefaults.standard.bool(forKey: "health_units_imperial")
  }

  static func parse(_ text: String) -> Double? {
    let normalized = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ",", with: ".")
    guard let value = Double(normalized), value.isFinite else { return nil }
    return value
  }

  static func kg(fromDisplay text: String, imperial: Bool) -> Double? {
    guard let value = parse(text) else { return nil }
    return imperial ? value * kgPerLb : value
  }

  static func displayWeight(_ kg: Double, imperial: Bool) -> String {
    imperial ? String(format: "%.1f", kg / kgPerLb) : String(format: "%.1f", kg)
  }

  static func cm(cmText: String, feetText: String, inchesText: String, imperial: Bool) -> Double? {
    if !imperial { return parse(cmText) }
    let feet = parse(feetText) ?? 0
    let inches = parse(inchesText) ?? 0
    guard feet > 0 || inches > 0 else { return nil }
    return (feet * 12 + inches) * cmPerInch
  }

  static func feetAndInches(fromCm cm: Double) -> (feet: Int, inches: Int) {
    let totalInches = Int((cm / cmPerInch).rounded())
    return (totalInches / 12, totalInches % 12)
  }

  static func weightUnit(imperial: Bool) -> String {
    imperial ? loc("units.lb", "lb") : loc("units.kg", "kg")
  }

  static func formatHeight(_ cm: Double, imperial: Bool) -> String {
    if imperial {
      let parts = feetAndInches(fromCm: cm)
      return "\(parts.feet)′\(parts.inches)″"
    }
    return String(format: "%.0f %@", cm, loc("units.cm", "cm"))
  }

  static func weightRangeText(_ range: ClosedRange<Double>, imperial: Bool) -> String {
    let lower = imperial ? range.lowerBound / kgPerLb : range.lowerBound
    let upper = imperial ? range.upperBound / kgPerLb : range.upperBound
    return String(format: "%.0f-%.0f %@", lower, upper, weightUnit(imperial: imperial))
  }

  static func invalidRangeMessage(imperial: Bool) -> String {
    let height = imperial
      ? "\(formatHeight(HealthPlanCalculator.heightRange.lowerBound, imperial: true))-\(formatHeight(HealthPlanCalculator.heightRange.upperBound, imperial: true))"
      : "100-250 \(loc("units.cm", "cm"))"
    let weight = weightRangeText(HealthPlanCalculator.weightRange, imperial: imperial)
    return String(
      format: loc("health.invalid.range_fmt", "Use height %@, weight %@, and age 10-120."),
      height,
      weight
    )
  }
}
