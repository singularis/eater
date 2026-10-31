import SwiftUI

struct HealthSettingsView: View {
  @Binding var isPresented: Bool
  var onSaved: (() -> Void)? = nil
  @ObservedObject private var appleHealth = AppleHealthService.shared
  @AppStorage("health_units_imperial") private var imperial = false

  @State private var heightCm = ""
  @State private var heightFeet = ""
  @State private var heightInches = ""
  @State private var weight = ""
  @State private var targetWeight = ""
  @State private var age = ""
  @State private var sex: Calc.Sex = .male
  @State private var activityLevel = "Sedentary"
  @State private var goal: Goal = .maintain
  @State private var selectedMonths = 4

  @State private var didAttemptSave = false
  @State private var initialSnapshot: Snapshot?
  @State private var showDiscardConfirm = false
  @State private var isImporting = false
  @State private var importMessage: String?

  private typealias Goal = HealthPlanCalculator.Goal
  private typealias Calc = HealthPlanCalculator

  private struct Snapshot: Equatable {
    let heightCm: Double?
    let weightKg: Double?
    let targetKg: Double?
    let age: String
    let sex: Calc.Sex
    let activityLevel: String
    let goal: Goal
    let months: Int
  }

  private struct Inputs {
    let body: Calc.Body
    let target: Double?
  }

  private enum PlanStatus {
    case incomplete
    case blocked(String)
    case ready(Calc.Plan, Calc.Body)
  }

  var body: some View {
    trackingChanges(
      NavigationStack {
        navigationContent
      }
      .tint(AppTheme.primaryButtonFill)
      .interactiveDismissDisabled(isDirty)
      .onAppear {
        guard initialSnapshot == nil else { return }
        loadExistingData()
        alignMonths()
        initialSnapshot = snapshot
      }
    )
  }

  private var navigationContent: some View {
    scrollContent
      .scaledNavTitle(loc("nav.health_settings", "Health"))
      .toolbarBackground(AppTheme.surface, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(loc("common.cancel", "Cancel")) {
            HapticsService.shared.select()
            if isDirty {
              showDiscardConfirm = true
            } else {
              isPresented = false
            }
          }
          .foregroundColor(AppTheme.textPrimary)
        }
      }
      .scaledNotice(
        loc("health.discard.title", "Discard changes?"),
        isPresented: $showDiscardConfirm,
        message: "",
        actions: [
          ScaledNoticeAction(title: loc("health.discard.confirm", "Discard"), kind: .destructive) {
            isPresented = false
          },
          ScaledNoticeAction(title: loc("health.discard.keep", "Keep editing"), kind: .secondary),
        ]
      )
  }

  private var scrollContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        goalGroup
        bodyGroup
        activityGroup
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 12)
    }
    .scrollDismissesKeyboard(.interactively)
    .scrollIndicators(.hidden)
    .background(AppTheme.backgroundGradient.ignoresSafeArea())
    .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
  }

  private func trackingChanges<Content: View>(_ content: Content) -> some View {
    let tracked = content
      .onChange(of: imperial) { oldValue, newValue in
        convertUnits(from: oldValue, to: newValue)
      }
      .onChange(of: weight) { _, _ in inputsChanged() }
      .onChange(of: targetWeight) { _, _ in inputsChanged() }
      .onChange(of: goal) { _, _ in inputsChanged() }
    return tracked
      .onChange(of: heightCm) { _, _ in didAttemptSave = false }
      .onChange(of: heightFeet) { _, _ in didAttemptSave = false }
      .onChange(of: heightInches) { _, _ in didAttemptSave = false }
      .onChange(of: age) { _, _ in didAttemptSave = false }
  }

  // MARK: - Groups

  private var bodyGroup: some View {
    VStack(alignment: .leading, spacing: 14) {
      AppLabeledNumberField(
        label: loc("health.field.weight", "Weight"),
        unit: HealthUnits.weightUnit(imperial: imperial),
        text: $weight,
        keyboard: .decimalPad,
        placeholder: imperial ? "154" : "70",
        focusTag: HealthFieldTag.weight
      )

      if let bmi = currentBMI {
        Text(String(format: loc("health.bmi.current", "BMI: %.1f"), bmi))
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text(loc("health.gender", "Sex"))
          .font(.subheadline.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
        sexControl
      }

      AppLabeledNumberField(
        label: loc("health.field.age", "Age"),
        unit: loc("health.age.unit", "yr"),
        text: $age,
        keyboard: .numberPad,
        placeholder: "30",
        focusTag: HealthFieldTag.age
      )

      HStack {
        Text(loc("health.units.label", "Units"))
          .font(.subheadline.weight(.semibold))
          .foregroundColor(AppTheme.textPrimary)
        Spacer()
        HealthUnitPicker(imperial: $imperial)
      }

      HealthHeightField(imperial: imperial, cm: $heightCm, feet: $heightFeet, inches: $heightInches)

      if appleHealth.isAvailable {
        Divider()
        Button(action: importFromAppleHealth) {
          HStack(spacing: 8) {
            Image(systemName: "heart.fill")
              .font(.subheadline)
              .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.19))
            Text(loc("health.apple.import", "Fill from Apple Health"))
              .font(.subheadline)
              .foregroundColor(AppTheme.textPrimary)
            Spacer()
            if isImporting {
              ProgressView()
            }
          }
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
        if let importMessage {
          Text(importMessage)
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(16)
    .appSurface()
  }

  private var activityGroup: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(loc("health.section.activity", "Activity"))
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AppTheme.textPrimary)
        .padding(.bottom, 4)

      if !appleHealth.activityEnabled {
        VStack(spacing: 0) {
          ForEach(Array(Calc.activityLevels.enumerated()), id: \.element) { index, level in
            activityRow(level)
            if index < Calc.activityLevels.count - 1 {
              Divider().padding(.leading, 2)
            }
          }
        }
      }

      if appleHealth.isAvailable {
        if !appleHealth.activityEnabled {
          Divider().padding(.vertical, 6)
        }
        Toggle(isOn: appleHealthToggle) {
          Text(loc("health.apple.activity.title", "Apple Health"))
            .font(.subheadline)
            .foregroundColor(AppTheme.textPrimary)
        }
        .tint(AppTheme.primaryButtonFill)

        if appleHealth.activityEnabled {
          shareControl
          let today = AppleHealthService.todayISO()
          Text(String(
            format: loc("health.apple.activity.today", "Today: %d kcal burned, %d kcal added to your limit."),
            appleHealth.rawKcal(dayISO: today),
            appleHealth.bonusKcal(dayISO: today)
          ))
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(16)
    .appSurface()
  }

  private var goalGroup: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(loc("health.goal.title", "Goal"))
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AppTheme.textPrimary)

      VStack(spacing: 0) {
        goalRow(loc("health.goal.lose", "Lose"), .lose)
        Divider()
        goalRow(loc("health.goal.maintain_mode", "Maintain"), .maintain)
        Divider()
        goalRow(loc("health.goal.gain", "Gain"), .gain)
        Divider()
        goalRow(loc("health.goal.activity_only", "Activity only"), .activityOnly)
      }

      AppLabeledNumberField(
        label: loc("health.field.target", "Target weight"),
        unit: HealthUnits.weightUnit(imperial: imperial),
        text: $targetWeight,
        keyboard: .decimalPad,
        placeholder: suggestedTargetText ?? (imperial ? "143" : "65"),
        focusTag: HealthFieldTag.target
      )

      if let suggestion = suggestedTargetText {
        Button {
          HapticsService.shared.select()
          targetWeight = suggestion
        } label: {
          Text("\(suggestion) \(HealthUnits.weightUnit(imperial: imperial))")
            .font(.subheadline)
            .foregroundColor(AppTheme.primaryButtonFill)
        }
        .buttonStyle(.plain)
      }

      if let bmi = targetBMI {
        Text(String(format: loc("health.bmi.target.range", "Target BMI: %.1f (18.5–%.1f)"), bmi, Calc.bmiCap(for: goal)))
          .font(.caption)
          .foregroundColor(isTargetBMIValid ? AppTheme.textSecondary : AppTheme.danger)
      }

      if goal == .lose || goal == .gain {
        HStack(spacing: 18) {
          ForEach(monthOptions, id: \.self) { months in
            let on = effectiveMonths == months
            Button {
              HapticsService.shared.select()
              selectedMonths = months
            } label: {
              Text(String(format: loc("health.goal.months", "%d months"), months))
                .font(.subheadline.weight(on ? .semibold : .regular))
                .foregroundColor(on ? AppTheme.primaryButtonFill : AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
          }
          Spacer(minLength: 0)
        }
      }
    }
    .padding(16)
    .appSurface()
  }

  private var saveBar: some View {
    VStack(alignment: .leading, spacing: 8) {
      Divider()
      switch planStatus {
      case .ready(let plan, _):
        HStack(alignment: .firstTextBaseline) {
          Text("\(plan.calories)")
            .font(.title3.weight(.semibold))
            .foregroundColor(AppTheme.textPrimary)
          Text(loc("units.kcal", "kcal"))
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)
          Spacer(minLength: 8)
          Text(plan.timelineText)
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)
            .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
      case .blocked(let message):
        Text(message)
          .font(.footnote)
          .foregroundColor(AppTheme.danger)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 16)
      case .incomplete:
        if didAttemptSave {
          Text(loc("health.plan.empty", "Add your height, weight, and age to see a calorie target."))
            .font(.footnote)
            .foregroundColor(AppTheme.danger)
            .padding(.horizontal, 16)
        }
      }
      Button(loc("common.save", "Save")) {
        saveTapped()
      }
      .buttonStyle(PrimaryButtonStyle())
      .padding(.horizontal, 16)
      .padding(.bottom, 8)
    }
    .background(AppTheme.surface.ignoresSafeArea(edges: .bottom))
  }

  // MARK: - Controls

  private var sexControl: some View {
    HStack(spacing: 0) {
      sexButton(.male, loc("health.gender.male", "Male"))
      sexButton(.female, loc("health.gender.female", "Female"))
      sexButton(.average, loc("health.sex.average", "Other"))
    }
    .padding(2)
    .background(AppTheme.surfaceAlt)
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.tinyRadius, style: .continuous))
  }

  private func sexButton(_ value: Calc.Sex, _ title: String) -> some View {
    let on = sex == value
    return Button {
      HapticsService.shared.select()
      sex = value
    } label: {
      Text(title)
        .font(.subheadline.weight(on ? .semibold : .regular))
        .foregroundColor(AppTheme.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(on ? AppTheme.surface : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var shareControl: some View {
    HStack(spacing: 0) {
      ForEach(AppleHealthService.shareOptions, id: \.self) { share in
        let on = appleHealth.activityShare == share
        Button {
          HapticsService.shared.select()
          appleHealth.activityShare = share
        } label: {
          Text("\(share)%")
            .font(.subheadline.weight(on ? .semibold : .regular))
            .foregroundColor(AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(on ? AppTheme.surface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(2)
    .background(AppTheme.surfaceAlt)
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.tinyRadius, style: .continuous))
  }

  private func goalRow(_ title: String, _ value: Goal) -> some View {
    let on = goal == value
    return Button {
      HapticsService.shared.select()
      goal = value
    } label: {
      HStack {
        Text(title)
          .font(.body)
          .foregroundColor(AppTheme.textPrimary)
        Spacer()
        if on {
          Image(systemName: "checkmark")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.primaryButtonFill)
        }
      }
      .padding(.vertical, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func activityRow(_ level: String) -> some View {
    let on = activityLevel == level
    return Button {
      HapticsService.shared.select()
      activityLevel = level
    } label: {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(localizedActivityLevel(level))
            .font(.body)
            .foregroundColor(AppTheme.textPrimary)
          if on {
            Text(localizedActivityDescription(level))
              .font(.caption)
              .foregroundColor(AppTheme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 8)
        if on {
          Image(systemName: "checkmark")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.primaryButtonFill)
        }
      }
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var appleHealthToggle: Binding<Bool> {
    Binding(
      get: { appleHealth.activityEnabled },
      set: { enabled in
        HapticsService.shared.select()
        if enabled {
          if activityLevel != "Sedentary" {
            UserDefaults.standard.set(activityLevel, forKey: "userActivityLevelManual")
          }
          activityLevel = "Sedentary"
          Task { await appleHealth.enableActivity() }
        } else {
          appleHealth.activityEnabled = false
          if let saved = UserDefaults.standard.string(forKey: "userActivityLevelManual"), !saved.isEmpty {
            activityLevel = saved
          }
        }
      }
    )
  }

  // MARK: - Labels

  private func localizedActivityLevel(_ level: String) -> String {
    switch level {
    case "Sedentary": return loc("health.activity.sedentary", "Sedentary")
    case "Lightly Active": return loc("health.activity.lightly", "Lightly Active")
    case "Moderately Active": return loc("health.activity.moderately", "Moderately Active")
    case "Very Active": return loc("health.activity.very", "Very Active")
    case "Extremely Active": return loc("health.activity.extremely", "Extremely Active")
    default: return level
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

  // MARK: - Values

  private var heightValueCm: Double? {
    HealthUnits.cm(cmText: heightCm, feetText: heightFeet, inchesText: heightInches, imperial: imperial)
  }

  private var weightValueKg: Double? {
    HealthUnits.kg(fromDisplay: weight, imperial: imperial)
  }

  private var targetValueKg: Double? {
    HealthUnits.kg(fromDisplay: targetWeight, imperial: imperial)
  }

  private var currentBMI: Double? {
    guard let h = heightValueCm, let w = weightValueKg, h > 0, w > 0 else { return nil }
    return Calc.bmi(heightCm: h, weightKg: w)
  }

  private var targetBMI: Double? {
    guard let h = heightValueCm, let t = targetValueKg, h > 0, t > 0 else { return nil }
    return Calc.bmi(heightCm: h, weightKg: t)
  }

  private var isTargetBMIValid: Bool {
    guard let bmi = targetBMI else { return true }
    return bmi >= Calc.bmiMin && bmi <= Calc.bmiCap(for: goal)
  }

  private var suggestedTargetText: String? {
    guard let h = heightValueCm, Calc.heightRange.contains(h) else { return nil }
    let suggestion = HealthUnits.displayWeight(Calc.optimalWeight(heightCm: h), imperial: imperial)
    return suggestion == targetWeight.trimmingCharacters(in: .whitespaces) ? nil : suggestion
  }

  private var weightChangeKg: Double {
    guard let w = weightValueKg, let t = targetValueKg else { return 0 }
    return t - w
  }

  private var monthOptions: [Int] {
    targetValueKg == nil ? [2, 4, 6] : Calc.monthOptions(forChangeKg: weightChangeKg)
  }

  private var effectiveMonths: Int {
    monthOptions.min(by: { abs($0 - selectedMonths) < abs($1 - selectedMonths) }) ?? selectedMonths
  }

  private var snapshot: Snapshot {
    Snapshot(
      heightCm: heightValueCm.map { $0.rounded() },
      weightKg: weightValueKg.map { ($0 * 10).rounded() / 10 },
      targetKg: targetValueKg.map { ($0 * 10).rounded() / 10 },
      age: age.trimmingCharacters(in: .whitespaces),
      sex: sex,
      activityLevel: activityLevel,
      goal: goal,
      months: effectiveMonths
    )
  }

  private var isDirty: Bool {
    guard let initialSnapshot else { return false }
    return initialSnapshot != snapshot
  }

  private var planStatus: PlanStatus {
    let heightEmpty = imperial
      ? heightFeet.trimmingCharacters(in: .whitespaces).isEmpty
      : heightCm.trimmingCharacters(in: .whitespaces).isEmpty
    if heightEmpty || weight.trimmingCharacters(in: .whitespaces).isEmpty
      || age.trimmingCharacters(in: .whitespaces).isEmpty {
      return .incomplete
    }
    guard let inputs = strictInputs() else {
      return .blocked(HealthUnits.invalidRangeMessage(imperial: imperial))
    }
    if let issue = targetIssue(inputs) {
      return .blocked(issue)
    }
    let target = inputs.target ?? inputs.body.weightKg
    let months = (goal == .lose || goal == .gain) ? effectiveMonths : 0
    let plan = Calc.Plan(
      calories: Calc.calories(body: inputs.body, goal: goal, targetKg: target, months: months),
      goal: goal,
      targetKg: target,
      months: months
    )
    return .ready(plan, inputs.body)
  }

  private func strictInputs() -> Inputs? {
    guard let h = heightValueCm, Calc.heightRange.contains(h),
      let w = weightValueKg, Calc.weightRange.contains(w),
      let a = Int(age.trimmingCharacters(in: .whitespaces)), Calc.ageRange.contains(a)
    else { return nil }

    let body = Calc.Body(heightCm: h, weightKg: w, age: a, sex: sex, activityLevel: activityLevel)
    if targetWeight.trimmingCharacters(in: .whitespaces).isEmpty {
      return Inputs(body: body, target: nil)
    }
    guard let t = targetValueKg, Calc.weightRange.contains(t) else { return nil }
    return Inputs(body: body, target: t)
  }

  private func targetIssue(_ inputs: Inputs) -> String? {
    if (goal == .lose || goal == .gain) && inputs.target == nil {
      return loc("health.goal.need_target", "Enter a target weight.")
    }
    guard let target = inputs.target else { return nil }

    if goal == .lose && target > inputs.body.weightKg - 0.1 {
      return loc("health.goal.direction.lose",
                 "Target must be below your current weight for Lose. Choose Gain, or set a lower target.")
    }
    if goal == .gain && target < inputs.body.weightKg + 0.1 {
      return loc("health.goal.direction.gain",
                 "Target must be above your current weight for Gain. Choose Lose, or set a higher target.")
    }

    let bmi = Calc.bmi(heightCm: inputs.body.heightCm, weightKg: target)
    let cap = Calc.bmiCap(for: goal)
    if bmi < Calc.bmiMin || bmi > cap {
      let range = Calc.healthyTargetRange(heightCm: inputs.body.heightCm, goal: goal)
      return String(
        format: loc("health.target_bmi.bounds", "Target BMI is %.1f. Keep it between 18.5 and %.1f, about %@."),
        bmi,
        cap,
        HealthUnits.weightRangeText(range, imperial: imperial)
      )
    }
    return nil
  }

  // MARK: - Actions

  private func inputsChanged() {
    didAttemptSave = false
    alignMonths()
  }

  private func alignMonths() {
    let nearest = effectiveMonths
    if nearest != selectedMonths { selectedMonths = nearest }
  }

  private func convertUnits(from wasImperial: Bool, to nowImperial: Bool) {
    guard wasImperial != nowImperial else { return }
    let cm = HealthUnits.cm(cmText: heightCm, feetText: heightFeet, inchesText: heightInches, imperial: wasImperial)
    let kg = HealthUnits.kg(fromDisplay: weight, imperial: wasImperial)
    let targetKg = HealthUnits.kg(fromDisplay: targetWeight, imperial: wasImperial)
    setHeight(cm)
    weight = kg.map { HealthUnits.displayWeight($0, imperial: nowImperial) } ?? weight
    targetWeight = targetKg.map { HealthUnits.displayWeight($0, imperial: nowImperial) } ?? targetWeight
  }

  private func setHeight(_ cm: Double?) {
    guard let cm, cm > 0 else { return }
    heightCm = String(format: "%.0f", cm)
    let parts = HealthUnits.feetAndInches(fromCm: cm)
    heightFeet = String(parts.feet)
    heightInches = String(parts.inches)
  }

  private func importFromAppleHealth() {
    HapticsService.shared.select()
    isImporting = true
    importMessage = nil
    Task {
      let profile = await appleHealth.importProfile()
      isImporting = false
      if profile.isEmpty {
        importMessage = loc(
          "health.apple.import.empty",
          "No data found. Add it in the Health app, or allow Eateria in Health: Sharing, Apps."
        )
        HapticsService.shared.warning()
        return
      }
      if let cm = profile.heightCm { setHeight(cm) }
      if let kg = profile.weightKg { weight = HealthUnits.displayWeight(kg, imperial: imperial) }
      if let years = profile.age { age = String(years) }
      if let imported = profile.sex { sex = imported }
      importMessage = loc("health.apple.import.done", "Filled from Apple Health. Check the values before saving.")
      HapticsService.shared.success()
    }
  }

  private func loadExistingData() {
    let defaults = UserDefaults.standard
    guard defaults.bool(forKey: "hasUserHealthData") else { return }
    let storedHeight = defaults.double(forKey: "userHeight")
    if storedHeight > 0 { setHeight(storedHeight) }
    let storedWeight = defaults.double(forKey: "userWeight")
    if storedWeight > 0 { weight = HealthUnits.displayWeight(storedWeight, imperial: imperial) }
    let storedTarget = defaults.double(forKey: "userTargetWeight")
    if storedTarget > 0 { targetWeight = HealthUnits.displayWeight(storedTarget, imperial: imperial) }
    let storedAge = defaults.integer(forKey: "userAge")
    if storedAge > 0 { age = String(storedAge) }
    sex = Calc.storedSex(defaults)
    activityLevel = defaults.string(forKey: "userActivityLevel") ?? "Sedentary"
    if appleHealth.activityEnabled, activityLevel != "Sedentary" {
      if defaults.string(forKey: "userActivityLevelManual") == nil {
        defaults.set(activityLevel, forKey: "userActivityLevelManual")
      }
      activityLevel = "Sedentary"
    }
    if let raw = defaults.string(forKey: "userGoalMode"), let parsed = Goal(rawValue: raw) {
      goal = parsed
    }
    let months = defaults.integer(forKey: "userGoalMonths")
    if months > 0 { selectedMonths = months }
  }

  private func saveTapped() {
    guard case .ready(let plan, let body) = planStatus else {
      didAttemptSave = true
      HapticsService.shared.error()
      return
    }
    HapticsService.shared.success()
    Calc.save(body: body, plan: plan)
    GRPCService().updateGoal(
      targetWeight: (plan.targetKg * 10).rounded() / 10,
      goalMode: plan.goal.rawValue,
      goalMonths: plan.months,
      recommendedCalories: plan.calories
    ) { _ in }
    onSaved?()
    isPresented = false
  }
}

#Preview {
  HealthSettingsView(isPresented: .constant(true))
}
