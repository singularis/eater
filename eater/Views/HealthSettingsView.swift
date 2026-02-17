import SwiftUI

struct HealthSettingsView: View {
  @Binding var isPresented: Bool
  @State private var height: String = ""
  @State private var weight: String = ""
  @State private var targetWeight: String = ""
  @State private var age: String = ""
  @State private var isMale: Bool = true
  @State private var activityLevel: String = "Sedentary"
  @State private var showingHealthDataAlert = false
  @State private var showingTargetWeightAlert = false
  @State private var invalidHealthDataMessage: String = ""
  @StateObject private var themeService = ThemeService.shared

  // Calculated values
  @State private var optimalWeight: Double = 0  // Used as suggestion
  @State private var recommendedCalories: Int = 0
  @State private var timeToOptimalWeight: String = ""
  @State private var showResults = false

  private enum GoalMode: String, CaseIterable, Identifiable {
    case lose
    case maintain
    case gain
    case activityOnly

    var id: String { rawValue }
  }

  @State private var goalMode: GoalMode = .maintain
  @State private var selectedMonths: Int = 4
  @State private var heartBeatScale: CGFloat = 1.0

  let activityLevels = [
    "Sedentary", "Lightly Active", "Moderately Active", "Very Active", "Extremely Active",
  ]

  // Health-safe limits to avoid harmful or unrealistic values
  private static let heightMin = 100.0
  private static let heightMax = 250.0
  private static let weightMin = 20.0
  private static let weightMax = 300.0
  private static let targetWeightMin = 20.0
  private static let targetWeightMax = 300.0  // fallback; effective max is BMI-based below
  private static let ageMin = 10
  private static let ageMax = 120
  /// Max BMI for target weight: standard healthy range upper bound
  private static let bmiMaxStandard = 24.9
  /// Max BMI when goal is weight gain (slightly higher healthy range)
  private static let bmiMaxGain = 27.0

  func localizedActivityLevel(_ level: String) -> String {
    switch level {
    case "Sedentary":
      return loc("health.activity.sedentary", "Sedentary")
    case "Lightly Active":
      return loc("health.activity.lightly", "Lightly Active")
    case "Moderately Active":
      return loc("health.activity.moderately", "Moderately Active")
    case "Very Active":
      return loc("health.activity.very", "Very Active")
    case "Extremely Active":
      return loc("health.activity.extremely", "Extremely Active")
    default:
      return level
    }
  }

  private func themedIcon(_ systemIcon: String) -> String {
    themeService.currentMascot.icon(for: systemIcon)
  }

  private func activityIconName(_ level: String) -> String {
    switch level {
    case "Sedentary":
      return "chair"
    case "Lightly Active":
      return "figure.walk"
    case "Moderately Active":
      return "dumbbell"
    case "Very Active":
      return "figure.run"
    case "Extremely Active":
      return "flag.checkered"
    default:
      return "figure.walk"
    }
  }

  private func localizedActivityDescription(_ level: String) -> String {
    switch level {
    case "Sedentary":
      return loc("health.activity.sedentary.desc", "Desk job, no workouts")
    case "Lightly Active":
      return loc("health.activity.lightly.desc", "Light walks, casual movement during the day")
    case "Moderately Active":
      return loc("health.activity.moderately.desc", "Regular workouts 3–4×/week or active lifestyle")
    case "Very Active":
      return loc("health.activity.very.desc", "Intense training most days or physically demanding job")
    case "Extremely Active":
      return loc("health.activity.extremely.desc", "Athlete-level load: marathon prep or hard physical work daily")
    default:
      return ""
    }
  }

  var body: some View {
    NavigationView {
      ZStack {
        AppTheme.backgroundGradient
          .edgesIgnoringSafeArea(.all)

        ScrollView {
          VStack(spacing: 20) {
            if showResults {
              healthResultsView
            } else {
              healthFormView
            }
          }
          .padding()
        }
      }
      .navigationTitle(
        showResults
          ? loc("health.plan.title", "Your Plan") : loc("nav.health_settings", "Health Settings")
      )
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(loc("common.cancel", "Cancel")) {
            HapticsService.shared.select()
            isPresented = false
          }
          .foregroundColor(AppTheme.textPrimary)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button(loc("common.save", "Save")) {
            // Always validate before saving (including when editing target on results screen)
            if !showResults {
              if validateAndCalculateHealthData() {
                showResults = true
              } else {
                return  // one alert already set (health data or target weight)
              }
            }
            // Re-validate when on results screen (user may have edited target to invalid BMI)
            if showResults && !validateAndCalculateHealthData(showTargetWeightAlert: true, showAlerts: true) {
              return  // invalid target or fields — alert already shown, do not save
            }
            HapticsService.shared.success()
            saveHealthData()
            isPresented = false
          }
          .foregroundColor(AppTheme.textPrimary)
          .fontWeight(.semibold)
        }
      }
    }
    .onAppear {
      loadExistingData()
    }
    .alert(loc("health.invalid.title", "Invalid Health Data"), isPresented: $showingHealthDataAlert)
    {
      Button(loc("common.ok", "OK"), role: .cancel) {}
    } message: {
      Text(
        invalidHealthDataMessage.isEmpty
          ? loc(
            "health.invalid.msg",
            "Check your current weight and target weight. Height and age rarely need changing. An invalid target weight can harm your health. For weight gain, choose the \"Gain\" mode."
          )
          : invalidHealthDataMessage
      )
    }
    .alert(loc("health.target_invalid.title", "Invalid Target Weight"), isPresented: $showingTargetWeightAlert) {
      Button(loc("common.ok", "OK"), role: .cancel) {}
    } message: {
      let bmi = targetBMIValue() ?? 0
      Text(
        String(
          format: loc(
            "health.target_invalid.msg",
            "Target BMI: %.1f. The entered target weight is not allowed and can harm your health. For weight gain, choose the \"Gain\" mode to allow a higher target."
          ),
          bmi
        )
      )
    }
  }

  private var healthFormView: some View {
    VStack(spacing: 20) {
      Image(systemName: "heart.fill")
        .font(.system(size: 60))
        .foregroundColor(AppTheme.danger)
        .scaleEffect(heartBeatScale)
        .onAppear {
          withAnimation(
            .easeInOut(duration: 0.45)
            .repeatForever(autoreverses: true)
          ) {
            heartBeatScale = 1.12
          }
        }

      Text(loc("health.update.title", "Update Your Health Data"))
        .font(.title)
        .fontWeight(.bold)
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.center)

      VStack(spacing: 16) {
        HStack {
          Text(loc("health.height", "Height (cm):"))
            .foregroundColor(AppTheme.textPrimary)
            .frame(width: 100, alignment: .leading)
          TextField("175", text: $height)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.numberPad)
        }

        HStack {
          Text(loc("health.weight", "Weight (kg):"))
            .foregroundColor(AppTheme.textPrimary)
            .frame(width: 100, alignment: .leading)
          TextField("70", text: $weight)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.decimalPad)
        }

        let currentBmiText = currentBMIText()
        if !currentBmiText.isEmpty {
          Text(currentBmiText)
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        HStack {
          Text(loc("health.target_weight", "Target (kg):"))
            .foregroundColor(AppTheme.textPrimary)
            .frame(width: 100, alignment: .leading)
          TextField("65", text: $targetWeight)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.decimalPad)
        }

        HStack {
          Text(loc("health.age", "Age (years):"))
            .foregroundColor(AppTheme.textPrimary)
            .frame(width: 100, alignment: .leading)
          TextField("25", text: $age)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.numberPad)
        }

        HStack {
          Text(loc("health.gender", "Gender:"))
            .foregroundColor(AppTheme.textPrimary)
            .frame(width: 100, alignment: .leading)
          Picker(loc("health.gender", "Gender:"), selection: $isMale) {
            Text(loc("health.gender.male", "Male")).tag(true)
            Text(loc("health.gender.female", "Female")).tag(false)
          }
          .pickerStyle(SegmentedPickerStyle())
        }

        VStack(alignment: .leading, spacing: 8) {
          Text(loc("health.activity", "Activity Level:"))
            .foregroundColor(AppTheme.textPrimary)
          Menu {
            ForEach(activityLevels, id: \.self) { level in
              Button {
                activityLevel = level
              } label: {
                Label(localizedActivityLevel(level), systemImage: activityIconName(level))
              }
            }
          } label: {
            HStack(spacing: 10) {
              Image(systemName: activityIconName(activityLevel))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.accent)
              Text(localizedActivityLevel(activityLevel))
                .font(.subheadline)
                .foregroundColor(AppTheme.textPrimary)
              Spacer()
              Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surface)
            .cornerRadius(AppTheme.smallRadius)
          }

          Text(localizedActivityDescription(activityLevel))
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
        }

        Button(loc("health.calc_plan", "Calculate My Plan")) {
          if validateAndCalculateHealthData() {
            HapticsService.shared.success()
            withAnimation(AppSettingsService.shared.reduceMotion ? .none : .easeInOut(duration: 0.3)) {
              showResults = true
            }
          } else {
            HapticsService.shared.error()
            // validateAndCalculateHealthData already set one alert (health data or target weight)
          }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 20)
      }
      .cardContainer(padding: 16)
    }
  }

  private var healthResultsView: some View {
    VStack(spacing: 20) {
      Image(systemName: "target")
        .font(.system(size: 60))
        .foregroundColor(AppTheme.success)

      Text(loc("health.updated_plan", "Your Updated Plan"))
        .font(.title)
        .fontWeight(.bold)
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.center)

      VStack(spacing: 16) {
        // Goal configuration (editable)
        VStack(alignment: .leading, spacing: 12) {
          Text(loc("health.goal.title", "Goal"))
            .font(.headline)
            .foregroundColor(AppTheme.textPrimary)

          HStack {
            Text(loc("health.target_weight", "Target (kg):"))
              .foregroundColor(AppTheme.textPrimary)
              .frame(width: 110, alignment: .leading)
            TextField("65", text: $targetWeight)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .keyboardType(.decimalPad)
          }

          let targetBmiText = targetBMIText()
          if !targetBmiText.isEmpty {
            Text(targetBmiText)
              .font(.caption)
              .foregroundColor(isTargetBMIValid() ? AppTheme.textSecondary : AppTheme.danger)
          }

          Picker(loc("health.goal.mode", "Goal:"), selection: $goalMode) {
            Text(loc("health.goal.lose", "Lose")).tag(GoalMode.lose)
            Text(loc("health.goal.maintain_mode", "Maintain")).tag(GoalMode.maintain)
            Text(loc("health.goal.gain", "Gain")).tag(GoalMode.gain)
            Text(loc("health.goal.activity_only", "Activity only")).tag(GoalMode.activityOnly)
          }
          .pickerStyle(SegmentedPickerStyle())

          if goalMode == .lose || goalMode == .gain {
            Picker(loc("health.goal.period", "Period:"), selection: $selectedMonths) {
              ForEach(suggestedMonths(), id: \.self) { m in
                Text(String(format: loc("health.goal.months", "%d months"), m)).tag(m)
              }
            }
            .pickerStyle(SegmentedPickerStyle())
          } else if goalMode == .activityOnly {
            VStack(alignment: .leading, spacing: 6) {
              Text(loc("health.goal.activity_hint", "Strategy: increase activity without changing calories."))
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

              Text("• " + loc("health.goal.activity_tip1", "Run/walk intervals: 15 minutes"))
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
              Text("• " + loc("health.goal.activity_tip2", "8–12k steps per day"))
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
              Text("• " + loc("health.goal.activity_tip3", "Strength training: 20–30 min, 2–3×/week"))
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
              Text("• " + loc("health.goal.activity_tip4", "Choose stairs, add short walks after meals"))
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            }
          }
        }
        .padding()
        .background(AppTheme.surfaceAlt)
        .cornerRadius(AppTheme.smallRadius)
        .onChange(of: targetWeight) { _ in recalcFromInputs() }
        .onChange(of: goalMode) { _ in recalcFromInputs() }
        .onChange(of: selectedMonths) { _ in recalcFromInputs() }

        VStack(spacing: 8) {
          HStack(spacing: 8) {
            Image(systemName: themedIcon("checkmark.circle.fill"))
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(AppTheme.success)
            Text(loc("health.plan.target_weight_title", "Target weight"))
              .font(.headline)
              .foregroundColor(AppTheme.success)
          }
          Text("\(currentTargetWeightValue(), specifier: "%.1f") \(loc("units.kg", "kg"))")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(AppTheme.textPrimary)
        }
        .padding()
        .background(AppTheme.surfaceAlt)
        .cornerRadius(AppTheme.smallRadius)

        VStack(spacing: 8) {
          HStack(spacing: 8) {
            Image(systemName: themedIcon("flame.fill"))
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(AppTheme.warning)
            Text(loc("health.plan.daily_calorie_title", "Daily calorie target"))
              .font(.headline)
              .foregroundColor(AppTheme.warning)
          }
          Text("\(recommendedCalories) \(loc("units.kcal", "kcal"))")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(AppTheme.textPrimary)
        }
        .padding()
        .background(AppTheme.surfaceAlt)
        .cornerRadius(AppTheme.smallRadius)

        VStack(spacing: 8) {
          HStack(spacing: 8) {
            Image(systemName: themedIcon("figure.run"))
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(AppTheme.accent)
            Text(loc("health.plan.timeline_title", "Estimated timeline"))
              .font(.headline)
              .foregroundColor(AppTheme.accent)
          }
          Text(timeToOptimalWeight)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(AppTheme.textPrimary)
            .multilineTextAlignment(.center)
        }
        .padding()
        .background(AppTheme.surfaceAlt)
        .cornerRadius(AppTheme.smallRadius)

        Button(loc("common.back_to_edit", "Back to Edit")) {
          HapticsService.shared.select()
          withAnimation(AppSettingsService.shared.reduceMotion ? .none : .easeInOut(duration: 0.3)) {
            showResults = false
          }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 10)
      }
      .cardContainer(padding: 16)
    }
  }

  // MARK: - Helper Methods

  private func loadExistingData() {
    let userDefaults = UserDefaults.standard
    if userDefaults.bool(forKey: "hasUserHealthData") {
      height = String(format: "%.0f", userDefaults.double(forKey: "userHeight"))
      weight = String(format: "%.1f", userDefaults.double(forKey: "userWeight"))
      let storedTarget = userDefaults.double(forKey: "userTargetWeight")
      if storedTarget > 0 {
        targetWeight = String(format: "%.1f", storedTarget)
      }
      age = String(userDefaults.integer(forKey: "userAge"))
      isMale = userDefaults.bool(forKey: "userIsMale")
      activityLevel = userDefaults.string(forKey: "userActivityLevel") ?? "Sedentary"
      if let mode = userDefaults.string(forKey: "userGoalMode"),
         let parsed = GoalMode(rawValue: mode) {
        goalMode = parsed
      }
      let months = userDefaults.integer(forKey: "userGoalMonths")
      if months > 0 { selectedMonths = months }
    }
  }

  private enum ValidationOutcome {
    case success
    case failureInvalidFields
    case failureInvalidTargetWeight
  }

  /// When showTargetWeightAlert is false (e.g. from recalcFromInputs), invalid target BMI is not shown as alert.
  /// When showAlerts is false (recalcFromInputs), no alert is shown and we don't overwrite the target field so the user can type.
  private func validateAndCalculateHealthData(showTargetWeightAlert: Bool = true, showAlerts: Bool = true) -> Bool {
    switch validateAndCalculateHealthDataOutcome(showTargetWeightAlert: showTargetWeightAlert, applyClampingToUI: showAlerts) {
    case .success: return true
    case .failureInvalidFields:
      if showAlerts { showingHealthDataAlert = true }
      return false
    case .failureInvalidTargetWeight:
      if showAlerts { showingTargetWeightAlert = true }
      return false
    }
  }

  private func validateAndCalculateHealthDataOutcome(showTargetWeightAlert: Bool = true, applyClampingToUI: Bool = true) -> ValidationOutcome {
    invalidHealthDataMessage = ""

    var heightValue = parseDoubleFlexible(height)
    var weightValue = parseDoubleFlexible(weight)
    var targetValue = targetWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? nil
      : parseDoubleFlexible(targetWeight)
    var ageValue = Int(age.trimmingCharacters(in: .whitespacesAndNewlines))

    var invalidFields: [String] = []
    if heightValue == nil || (heightValue ?? 0) <= 0 { invalidFields.append(loc("health.height", "Height (cm):")) }
    if weightValue == nil || (weightValue ?? 0) <= 0 { invalidFields.append(loc("health.weight", "Weight (kg):")) }
    if ageValue == nil || (ageValue ?? 0) <= 0 { invalidFields.append(loc("health.age", "Age (years):")) }
    if targetValue == nil && !targetWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      invalidFields.append(loc("health.target_weight", "Target (kg):"))
    }

    if !invalidFields.isEmpty {
      invalidHealthDataMessage = String(
        format: loc("health.invalid.msg_fields", "Please check: %@"),
        invalidFields.joined(separator: ", ")
      )
      return .failureInvalidFields
    }

    guard var h = heightValue, var w = weightValue, var a = ageValue else { return .failureInvalidFields }

    // Clamp to health-safe limits (use clamped values for calculation; only update UI when saving/calculating)
    h = min(max(h, Self.heightMin), Self.heightMax)
    w = min(max(w, Self.weightMin), Self.weightMax)
    a = min(max(a, Self.ageMin), Self.ageMax)
    let heightInMeters = h / 100.0
    let minTargetByBmi = heightInMeters * heightInMeters * 18.5  // min healthy BMI 18.5
    if var t = targetValue {
      let maxAllowed = min(Self.targetWeightMax, maxTargetWeightForCurrentHeight(heightCm: h))
      t = min(max(t, minTargetByBmi), maxAllowed)
      targetValue = t
      if applyClampingToUI {
        targetWeight = String(format: "%.1f", t)
      }
    }
    if applyClampingToUI {
      height = String(format: "%.0f", h)
      weight = String(format: "%.1f", w)
      age = String(a)
    }
    optimalWeight = 21.5 * heightInMeters * heightInMeters

    // Default target weight if empty (suggest optimal) — only when applying to UI
    if applyClampingToUI && (parseDoubleFlexible(targetWeight) == nil || (parseDoubleFlexible(targetWeight) ?? 0) <= 0) {
      targetWeight = String(format: "%.1f", optimalWeight)
    }

    // Validate BMI at target >= 18.5; only show alert when saving/calculating, not during editing
    if !isTargetBMIValid(heightCm: h) {
      return showTargetWeightAlert ? .failureInvalidTargetWeight : .success
    }

    // Calculate BMR using Mifflin-St Jeor Equation
    let bmr: Double
    if isMale {
      bmr = 10 * w + 6.25 * h - 5 * Double(a) + 5
    } else {
      bmr = 10 * w + 6.25 * h - 5 * Double(a) - 161
    }

    // Activity multipliers
    let activityMultiplier: Double
    switch activityLevel {
    case "Sedentary":
      activityMultiplier = 1.2
    case "Lightly Active":
      activityMultiplier = 1.375
    case "Moderately Active":
      activityMultiplier = 1.55
    case "Very Active":
      activityMultiplier = 1.725
    case "Extremely Active":
      activityMultiplier = 1.9
    default:
      activityMultiplier = 1.2
    }

    // Calculate TDEE (Total Daily Energy Expenditure)
    let tdee = bmr * activityMultiplier

    applyGoalAndCompute(tdee: tdee, currentWeight: w)

    return .success
  }

  private func recalcFromInputs() {
    _ = validateAndCalculateHealthData(showTargetWeightAlert: false, showAlerts: false)
  }

  private func currentTargetWeightValue() -> Double {
    parseDoubleFlexible(targetWeight) ?? optimalWeight
  }

  /// Max healthy target weight (kg) from height and goal: heightM² * BMI cap (24.9 standard, 27 for gain).
  private func maxTargetWeightForCurrentHeight(heightCm: Double? = nil) -> Double {
    let h = heightCm ?? parseDoubleFlexible(height) ?? 0
    guard h > 0 else { return Self.targetWeightMax }
    let hm = h / 100.0
    let bmiCap = goalMode == .gain ? Self.bmiMaxGain : Self.bmiMaxStandard
    return (hm * hm) * bmiCap
  }

  private func isTargetBMIValid(heightCm: Double? = nil) -> Bool {
    let h = heightCm ?? parseDoubleFlexible(height) ?? 0
    let t = parseDoubleFlexible(targetWeight) ?? 0
    guard h > 0, t > 0 else { return true }
    let hm = h / 100.0
    let bmi = t / (hm * hm)
    let maxBmi = goalMode == .gain ? Self.bmiMaxGain : Self.bmiMaxStandard
    return bmi >= 18.5 && bmi <= maxBmi
  }

  private func bmi(heightCm: Double, weightKg: Double) -> Double {
    let hm = heightCm / 100.0
    guard hm > 0 else { return 0 }
    return weightKg / (hm * hm)
  }

  private func currentBMIValue() -> Double? {
    guard let h = parseDoubleFlexible(height), let w = parseDoubleFlexible(weight), h > 0, w > 0 else { return nil }
    return bmi(heightCm: h, weightKg: w)
  }

  private func targetBMIValue() -> Double? {
    guard let h = parseDoubleFlexible(height), let t = parseDoubleFlexible(targetWeight), h > 0, t > 0 else { return nil }
    return bmi(heightCm: h, weightKg: t)
  }

  private func currentBMIText() -> String {
    guard let bmi = currentBMIValue() else { return "" }
    return String(format: loc("health.bmi.current", "BMI: %.1f"), bmi)
  }

  private func targetBMIText() -> String {
    guard let bmi = targetBMIValue() else { return "" }
    let maxBmi = goalMode == .gain ? Self.bmiMaxGain : Self.bmiMaxStandard
    return String(
      format: loc("health.bmi.target.range", "Target BMI: %.1f (18.5–%.1f)"),
      bmi,
      maxBmi
    )
  }

  private func parseDoubleFlexible(_ text: String) -> Double? {
    let normalized = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ",", with: ".")
    return Double(normalized)
  }

  private func suggestedMonths() -> [Int] {
    // Weight gain: always offer 2, 4, 6 months
    if goalMode == .gain { return [2, 4, 6] }
    guard let w = parseDoubleFlexible(weight), let t = parseDoubleFlexible(targetWeight) else { return [2, 4, 6] }
    let diff = abs(w - t)
    // Lose: healthy minimum pacing
    if diff <= 1.0 { return [2] }
    if diff <= 5.0 { return [2, 4, 6] }
    if diff <= 10.0 { return [4, 6] }
    return [6, 9, 12]
  }

  private func applyGoalAndCompute(tdee: Double, currentWeight: Double) {
    let target = currentTargetWeightValue()
    let diffKg = target - currentWeight

    // Keep direction consistent with selected goal
    if diffKg > 0.1, goalMode == .lose { goalMode = .gain }
    if diffKg < -0.1, goalMode == .gain { goalMode = .lose }

    if goalMode == .maintain || abs(diffKg) < 0.1 {
      recommendedCalories = Int(tdee)
      timeToOptimalWeight = loc("health.goal.maintain", "Maintain current weight")
      return
    }

    if goalMode == .activityOnly {
      recommendedCalories = Int(tdee)
      timeToOptimalWeight = loc("health.goal.activity_only_timeline", "Increase activity without changing calories")
      return
    }

    // Lose / Gain: compute daily deficit/surplus from selected period
    // Target pace reference: 0.5 kg/week ~ 500 kcal/day. Scale linearly.
    let absDiff = abs(diffKg)
    let minMonths: Int
    if absDiff <= 5.0 {
      minMonths = 2
    } else if absDiff <= 10.0 {
      minMonths = 4
    } else {
      minMonths = 6
    }

    // Enforce healthy minimum pacing
    let months = max(minMonths, selectedMonths)
    if months != selectedMonths { selectedMonths = months }

    let weeks = max(1.0, Double(months) * 30.4 / 7.0)
    let kgPerWeek = absDiff / weeks
    let dailyDelta = (kgPerWeek / 0.5) * 500.0

    var proposed = tdee
    if goalMode == .lose {
      proposed = tdee - dailyDelta
    } else if goalMode == .gain {
      proposed = tdee + dailyDelta
    }

    // Safety floor
    let minCalories = isMale ? 1500.0 : 1200.0
    if proposed < minCalories { proposed = minCalories }

    recommendedCalories = Int(proposed.rounded())
    timeToOptimalWeight = String(format: loc("health.goal.months_to_goal", "%d months to reach your goal"), months)
  }

  private func saveHealthData() {
    guard let heightValue = Double(height),
      let weightValue = Double(weight),
      let ageValue = Int(age)
    else { return }

    let userDefaults = UserDefaults.standard
    let heightStored = heightValue.rounded()
    let weightStored = (weightValue * 10).rounded() / 10
    let targetStored = (currentTargetWeightValue() * 10).rounded() / 10

    userDefaults.set(heightStored, forKey: "userHeight")
    userDefaults.set(weightStored, forKey: "userWeight")
    userDefaults.set(ageValue, forKey: "userAge")
    userDefaults.set(isMale, forKey: "userIsMale")
    userDefaults.set(activityLevel, forKey: "userActivityLevel")
    userDefaults.set(targetStored, forKey: "userTargetWeight")
    userDefaults.set(goalMode.rawValue, forKey: "userGoalMode")
    userDefaults.set((goalMode == .lose || goalMode == .gain) ? selectedMonths : 0, forKey: "userGoalMonths")
    userDefaults.set(recommendedCalories, forKey: "userRecommendedCalories")
    userDefaults.set(true, forKey: "hasUserHealthData")

    // Always apply health-based limits when user saves in Health (new plan = new target)
    let softLimit = recommendedCalories
    let hardLimit = Int(Double(recommendedCalories) * 1.15)  // 15% above recommendation
    userDefaults.set(softLimit, forKey: "softLimit")
    userDefaults.set(hardLimit, forKey: "hardLimit")
    userDefaults.set(false, forKey: "hasManualCalorieLimits")
    // Persist to file storage so ContentView and Set Calorie Limits pick up the new limits
    CalorieLimitsStorageService.shared.save(
      .init(softLimit: softLimit, hardLimit: hardLimit, hasManualCalorieLimits: false))
  }
}

#Preview {
  HealthSettingsView(isPresented: .constant(true))
}
