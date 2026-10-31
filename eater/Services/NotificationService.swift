import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationService()

  private let center = UNUserNotificationCenter.current()
  private let calendar = Calendar.current
  private let daysAheadToSchedule: Int = 14  // keep under iOS 64-pending limit (3/day * 14 = 42)
  private var observers: [Any] = []

  // UserDefaults keys
  private let enabledKey = "notificationsEnabled"
  private let lastSnapDateKey = "lastFoodSnapDate"  // yyyy-MM-dd local
  private let lastSnapTimeKey = "lastFoodSnapTime"  // TimeInterval since 1970

  // Identifiers
  private func id(for label: String, date: Date) -> String {
    let df = DateFormatter()
    df.dateFormat = "yyyyMMdd"
    return "eater_\(label)_\(df.string(from: date))"
  }

  // MARK: - Public API

  func initializeOnLaunch() {
    center.delegate = self
    rescheduleIfEnabled()
    // React to app language changes so future notifications use localized quotes
    let obs = NotificationCenter.default.addObserver(
      forName: .appLanguageChanged, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      self.rescheduleIfEnabled()
    }
    observers.append(obs)
  }

  var isEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: enabledKey) }
    set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
  }

  func requestAuthorizationAndEnable(_ enable: Bool, completion: ((Bool) -> Void)? = nil) {
    if !enable {
      isEnabled = false
      cancelScheduledReminders()
      completion?(true)
      return
    }

    center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
      DispatchQueue.main.async {
        self?.isEnabled = granted
        if granted {
          self?.rescheduleIfEnabled()
        } else {
          self?.cancelScheduledReminders()
        }
        completion?(granted)
      }
    }
  }

  func recordFoodSnap(at date: Date = Date()) {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    let todayString = df.string(from: date)
    let defaults = UserDefaults.standard
    defaults.set(todayString, forKey: lastSnapDateKey)
    defaults.set(date.timeIntervalSince1970, forKey: lastSnapTimeKey)

    // Any snap cancels remaining reminders for the day
    cancelTodayReminders(on: date)
  }

  /// Rolls the pending batch forward. iOS only keeps a short queue, so this runs
  /// on launch, when the app becomes active, and when the day changes, for as long
  /// as the switch stays on.
  func rescheduleIfEnabled() {
    guard isEnabled else { return }
    scheduleUpcomingReminders(daysAhead: daysAheadToSchedule)
  }

  func handleDayChangeIfNeeded() {
    rescheduleIfEnabled()
  }

  // MARK: - Scheduling

  func cancelScheduledReminders() {
    center.removePendingNotificationRequests(
      withIdentifiers: reminderIdentifiers(daysAhead: daysAheadToSchedule))
  }

  private func reminderIdentifiers(daysAhead: Int, from now: Date = Date()) -> [String] {
    let labels = ["breakfast", "lunch", "dinner"]
    var ids: [String] = []
    for offset in 0...daysAhead {
      guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
      let dayStart = calendar.startOfDay(for: day)
      for label in labels {
        ids.append(id(for: label, date: dayStart))
      }
    }
    return ids
  }

  private func scheduleUpcomingReminders(daysAhead: Int) {
    let now = Date()
    let labels: [(String, Int)] = [("breakfast", 12), ("lunch", 17), ("dinner", 21)]

    center.removePendingNotificationRequests(
      withIdentifiers: reminderIdentifiers(daysAhead: daysAhead, from: now))

    for offset in 0...daysAhead {
      guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
      let dayStart = calendar.startOfDay(for: day)

      // For today only, skip scheduling if already snapped
      if offset == 0, hasSnappedToday(reference: now) {
        continue
      }

      for (label, hour) in labels {
        var comps = calendar.dateComponents([.year, .month, .day], from: dayStart)
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        if let triggerDate = calendar.date(from: comps), triggerDate > now {
          scheduleReminder(at: triggerDate, label: label)
        }
      }
    }
  }

  private func scheduleReminder(at date: Date, label: String) {
    let content = UNMutableNotificationContent()
    content.title = loc("notif.title", "Eateria Reminder")
    content.body = makeReminderBody()
    content.sound = .default

    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    let request = UNNotificationRequest(
      identifier: id(for: label, date: date), content: content, trigger: trigger)
    center.add(request, withCompletionHandler: nil)
  }

  private func makeReminderBody() -> String {
    let prefix = loc("notif.body", "Reminder to snap your food to maintain healthy habits.")
    let quotes = FoodQuotesLocalized.quotes(for: LanguageService.shared.currentCode)
    if let quote = quotes.randomElement() {
      return "\(prefix) \"\(quote)\""
    }
    return prefix
  }

  private func cancelTodayReminders(on date: Date = Date()) {
    let ids = ["breakfast", "lunch", "dinner"].map { id(for: $0, date: date) }
    center.removePendingNotificationRequests(withIdentifiers: ids)
  }

  // MARK: - Helpers

  private func hasSnappedToday(reference: Date) -> Bool {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    let todayString = df.string(from: reference)
    let stored = UserDefaults.standard.string(forKey: lastSnapDateKey) ?? ""
    return stored == todayString
  }

  // MARK: - UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _: UNUserNotificationCenter, willPresent _: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
