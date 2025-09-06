import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let daysAheadToSchedule: Int = 14 // keep under iOS 64-pending limit (3/day * 14 = 42)
    private var observers: [Any] = []

    // UserDefaults keys
    private let enabledKey = "notificationsEnabled"
    private let lastSnapDateKey = "lastFoodSnapDate" // yyyy-MM-dd local
    private let lastSnapTimeKey = "lastFoodSnapTime" // TimeInterval since 1970

    // Identifiers
    private func id(for label: String, date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return "eater_\(label)_\(df.string(from: date))"
    }

    // MARK: - Public API

    func initializeOnLaunch() {
        center.delegate = self
        if isEnabled { scheduleUpcomingReminders(daysAhead: daysAheadToSchedule) }
        // React to app language changes so future notifications use localized quotes
        let obs = NotificationCenter.default.addObserver(forName: .appLanguageChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if self.isEnabled {
                self.scheduleUpcomingReminders(daysAhead: self.daysAheadToSchedule)
            }
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
            cancelTodayReminders()
            completion?(true)
            return
        }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.isEnabled = granted
                if granted {
                    self?.scheduleUpcomingReminders(daysAhead: self?.daysAheadToSchedule ?? 14)
                } else {
                    self?.cancelTodayReminders()
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

    func handleDayChangeIfNeeded() {
        if isEnabled { scheduleUpcomingReminders(daysAhead: daysAheadToSchedule) }
    }

    // MARK: - Scheduling

    private func scheduleUpcomingReminders(daysAhead: Int) {
        let now = Date()
        let labels: [(String, Int)] = [("breakfast", 12), ("lunch", 17), ("dinner", 21)]

        // Build identifiers for the whole window and clear them to avoid duplicates
        var idsToClear: [String] = []
        for offset in 0...daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            for (label, _) in labels {
                idsToClear.append(id(for: label, date: dayStart))
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: idsToClear)

        for offset in 0...daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: day)

            // For today only, skip scheduling if already snapped
            if offset == 0 && hasSnappedToday(reference: now) {
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
        let request = UNNotificationRequest(identifier: id(for: label, date: date), content: content, trigger: trigger)
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

    private func todayAtHour(_ hour: Int, reference: Date) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day], from: reference)
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        return calendar.date(from: comps)
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}


