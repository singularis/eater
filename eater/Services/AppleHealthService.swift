import Foundation
import HealthKit

/// Read-only Apple Health access. Values stay on the device: they prefill the
/// health form and raise the local daily calorie limit, and are never uploaded.
@MainActor
final class AppleHealthService: ObservableObject {
  static let shared = AppleHealthService()

  struct Profile {
    var heightCm: Double?
    var weightKg: Double?
    var age: Int?
    var sex: HealthPlanCalculator.Sex?

    var isEmpty: Bool { heightCm == nil && weightKg == nil && age == nil && sex == nil }
  }

  static let shareOptions = [50, 75, 100]

  private static let enabledKey = "apple_health_activity_enabled"
  private static let shareKey = "apple_health_activity_share"
  private static let requestedKey = "apple_health_activity_requested"

  private let store = HKHealthStore()
  private let defaults = UserDefaults.standard
  private var observer: HKObserverQuery?

  @Published var activityEnabled: Bool {
    didSet {
      defaults.set(activityEnabled, forKey: Self.enabledKey)
      if activityEnabled { startObserving() } else { stopObserving() }
    }
  }

  /// Percent of Apple Health active energy added to the limit. Watches tend to overestimate.
  @Published var activityShare: Int {
    didSet { defaults.set(activityShare, forKey: Self.shareKey) }
  }

  /// Raw active energy (kcal) per local day, keyed yyyy-MM-dd.
  @Published private(set) var activeKcalByDay: [String: Int] = [:]

  private init() {
    activityEnabled = defaults.bool(forKey: Self.enabledKey)
    let storedShare = defaults.integer(forKey: Self.shareKey)
    activityShare = Self.shareOptions.contains(storedShare) ? storedShare : 100
  }

  var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

  private var activeEnergyType: HKQuantityType { HKQuantityType(.activeEnergyBurned) }

  private var profileTypes: Set<HKObjectType> {
    [
      HKQuantityType(.height),
      HKQuantityType(.bodyMass),
      HKCharacteristicType(.dateOfBirth),
      HKCharacteristicType(.biologicalSex),
    ]
  }

  // MARK: - Profile import

  func importProfile() async -> Profile {
    guard isAvailable else { return Profile() }
    do {
      try await store.requestAuthorization(toShare: [], read: profileTypes)
    } catch {
      return Profile()
    }

    var profile = Profile()
    if let height = await latestQuantity(.height, unit: .meterUnit(with: .centi)) {
      profile.heightCm = height.rounded()
    }
    if let weight = await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo)) {
      profile.weightKg = (weight * 10).rounded() / 10
    }
    if let birth = try? store.dateOfBirthComponents(),
      let date = Calendar.current.date(from: birth),
      let years = Calendar.current.dateComponents([.year], from: date, to: Date()).year,
      years > 0 {
      profile.age = years
    }
    if let sex = try? store.biologicalSex().biologicalSex {
      switch sex {
      case .male: profile.sex = .male
      case .female: profile.sex = .female
      case .other: profile.sex = .average
      default: break
      }
    }
    return profile
  }

  private func latestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.quantitySample(type: HKQuantityType(id))],
      sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
      limit: 1
    )
    guard let sample = try? await descriptor.result(for: store).first else { return nil }
    return sample.quantity.doubleValue(for: unit)
  }

  // MARK: - Active energy

  /// Asks for read access, then turns the setting on. iOS never says whether
  /// read access was denied, so the setting stays on and simply reads 0.
  func enableActivity() async {
    guard isAvailable else { return }
    do {
      try await store.requestAuthorization(toShare: [], read: [activeEnergyType])
    } catch {
      return
    }
    defaults.set(true, forKey: Self.requestedKey)
    activityEnabled = true
    await refresh(dayISO: Self.todayISO())
  }

  func rawKcal(dayISO: String) -> Int {
    activeKcalByDay[dayISO] ?? 0
  }

  /// Calories to add to the limit for a day, after the chosen share.
  func bonusKcal(dayISO: String) -> Int {
    guard activityEnabled else { return 0 }
    return Int((Double(rawKcal(dayISO: dayISO)) * Double(activityShare) / 100).rounded())
  }

  func refresh(dayISO: String) async {
    guard activityEnabled, isAvailable, let start = Self.date(fromISO: dayISO),
      let end = Calendar.current.date(byAdding: .day, value: 1, to: start)
    else { return }
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let descriptor = HKStatisticsQueryDescriptor(
      predicate: .quantitySample(type: activeEnergyType, predicate: predicate),
      options: .cumulativeSum
    )
    let kcal = (try? await descriptor.result(for: store))?
      .sumQuantity()?
      .doubleValue(for: .kilocalorie()) ?? 0
    activeKcalByDay[dayISO] = Int(kcal.rounded())
  }

  func startObserving() {
    guard activityEnabled, isAvailable, observer == nil else { return }
    let query = HKObserverQuery(sampleType: activeEnergyType, predicate: nil) { [weak self] _, completion, _ in
      Task { @MainActor in
        await self?.refresh(dayISO: Self.todayISO())
        completion()
      }
    }
    observer = query
    store.execute(query)
  }

  private func stopObserving() {
    if let observer { store.stop(observer) }
    observer = nil
  }

  // MARK: - Dates

  static func todayISO() -> String {
    isoFormatter.string(from: Date())
  }

  static func date(fromISO iso: String) -> Date? {
    guard let date = isoFormatter.date(from: iso) else { return nil }
    return Calendar.current.startOfDay(for: date)
  }

  private static let isoFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}
