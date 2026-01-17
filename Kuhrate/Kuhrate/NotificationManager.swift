//
//  NotificationManager.swift
//  Kuhrate
//
//  Created by Sandro Brunner on 15.01.2026.
//

import CoreData
import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Constants

    private enum Keys {
        static let weeklyReviewDay = "weeklyReviewDay"
        static let monthlyReviewDay = "monthlyReviewDay"
        static let notificationHour = "notificationHour"
        static let notificationMinute = "notificationMinute"
    }

    private enum NotificationID {
        static let weeklyReview = "weekly-review"
        static let monthlyReview = "monthly-review"
        static let yearlyReview = "yearly-review"
    }

    // MARK: - Permission

    /// Request notification permission from user
    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Check if notifications are authorized
    func checkPermission(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - Schedule Notifications

    /// Schedule all review notifications
    func scheduleAllNotifications(context: NSManagedObjectContext) {
        checkPermission { [weak self] authorized in
            guard authorized else { return }

            self?.scheduleWeeklyNotification(context: context)
            self?.scheduleMonthlyNotification(context: context)
            self?.scheduleYearlyNotification(context: context)
        }
    }

    /// Schedule weekly review notification (every Sunday at 8 PM)
    private func scheduleWeeklyNotification(context: NSManagedObjectContext) {
        let weekDay = UserDefaults.standard.integer(forKey: Keys.weeklyReviewDay)
        let hour = UserDefaults.standard.integer(forKey: Keys.notificationHour)
        let minute = UserDefaults.standard.integer(forKey: Keys.notificationMinute)

        // Defaults: Sunday (1), 8 PM
        let targetWeekday = weekDay > 0 ? weekDay : 1
        let targetHour = hour > 0 ? hour : 20
        let targetMinute = minute >= 0 ? minute : 0

        var dateComponents = DateComponents()
        dateComponents.weekday = targetWeekday
        dateComponents.hour = targetHour
        dateComponents.minute = targetMinute

        let content = UNMutableNotificationContent()
        content.title = "Weekly Review Ready"
        content.sound = .default
        content.categoryIdentifier = "REVIEW_REMINDER"
        content.userInfo = ["reviewType": "weekly"]

        // Count pending notes
        let noteCount = countPendingNotes(for: .weekly, context: context)

        // Only schedule if there is work to do
        guard noteCount > 0 else {
            print("ℹ️ No weekly notes to review, skipping notification")
            return
        }

        content.body = "You have \(noteCount) note\(noteCount == 1 ? "" : "s") ready for your Weekly Review."

        // Calculate total badge: count how many cycles have work
        let totalSessions = calculateTotalPendingSessions(context: context)
        content.badge = NSNumber(value: totalSessions)

        // TESTING: 60-second test (triggers ONCE after 60 seconds) - CURRENTLY ACTIVE
        // let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        // PRODUCTION: Use this for actual weekly schedule (every Sunday 8 PM)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: NotificationID.weeklyReview, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule weekly notification: \(error)")
            } else {
                print("✅ Scheduled weekly notification. Badge: \(totalSessions)")
            }
        }
    }

    /// Schedule monthly review notification (1st of month at 8 PM)
    private func scheduleMonthlyNotification(context: NSManagedObjectContext) {
        let day = UserDefaults.standard.integer(forKey: Keys.monthlyReviewDay)
        let hour = UserDefaults.standard.integer(forKey: Keys.notificationHour)
        let minute = UserDefaults.standard.integer(forKey: Keys.notificationMinute)

        // Defaults: 1st of month, 8 PM
        let targetDay = day > 0 ? day : 1
        let targetHour = hour > 0 ? hour : 20
        let targetMinute = minute >= 0 ? minute : 0

        var dateComponents = DateComponents()
        dateComponents.day = targetDay
        dateComponents.hour = targetHour
        dateComponents.minute = targetMinute

        let content = UNMutableNotificationContent()
        content.title = "Monthly Review Ready"
        content.sound = .default
        content.categoryIdentifier = "REVIEW_REMINDER"
        content.userInfo = ["reviewType": "monthly"]

        let noteCount = countPendingNotes(for: .monthly, context: context)

        guard noteCount > 0 else {
            print("ℹ️ No monthly notes to review, skipping notification")
            return
        }

        content.body = "You have \(noteCount) note\(noteCount == 1 ? "" : "s") ready for your Monthly Review."

        let totalSessions = calculateTotalPendingSessions(context: context)
        content.badge = NSNumber(value: totalSessions)

        // TESTING: 60-second test
        // let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        // PRODUCTION:
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: NotificationID.monthlyReview, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule monthly notification: \(error)")
            } else {
                print("✅ Scheduled monthly notification. Badge: \(totalSessions)")
            }
        }
    }

    /// Schedule yearly review notification (Jan 1st at 8 PM)
    private func scheduleYearlyNotification(context: NSManagedObjectContext) {
        let hour = UserDefaults.standard.integer(forKey: Keys.notificationHour)
        let minute = UserDefaults.standard.integer(forKey: Keys.notificationMinute)

        // Defaults: January 1st, 8 PM
        let targetHour = hour > 0 ? hour : 20
        let targetMinute = minute >= 0 ? minute : 0

        var dateComponents = DateComponents()
        dateComponents.month = 1
        dateComponents.day = 1
        dateComponents.hour = targetHour
        dateComponents.minute = targetMinute

        let content = UNMutableNotificationContent()
        content.title = "Yearly Review Ready"
        content.sound = .default
        content.categoryIdentifier = "REVIEW_REMINDER"
        content.userInfo = ["reviewType": "yearly"]

        let noteCount = countPendingNotes(for: .yearly, context: context)

        guard noteCount > 0 else {
            print("ℹ️ No yearly notes to review, skipping notification")
            return
        }

        content.body = "You have \(noteCount) note\(noteCount == 1 ? "" : "s") ready for your Yearly Review."

        let totalSessions = calculateTotalPendingSessions(context: context)
        content.badge = NSNumber(value: totalSessions)

        // TESTING: 60-second test
        // let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)

        // PRODUCTION:
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: NotificationID.yearlyReview, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule yearly notification: \(error)")
            } else {
                print("✅ Scheduled yearly notification. Badge: \(totalSessions)")
            }
        }
    }

    // MARK: - Cancel Notifications

    /// Cancel all scheduled notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    /// Cancel specific notification type
    func cancelNotification(for type: ReviewType) {
        let identifier: String
        switch type {
        case .weekly: identifier = NotificationID.weeklyReview
        case .monthly: identifier = NotificationID.monthlyReview
        case .yearly: identifier = NotificationID.yearlyReview
        }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Logic Helpers

    private func calculateTotalPendingSessions(context: NSManagedObjectContext) -> Int {
        var total = 0
        if countPendingNotes(for: .weekly, context: context) > 0 { total += 1 }
        if countPendingNotes(for: .monthly, context: context) > 0 { total += 1 }
        if countPendingNotes(for: .yearly, context: context) > 0 { total += 1 }
        return total
    }

    /// Counts notes that are ready for review (in current cycle AND created before the start of the current period)
    private func countPendingNotes(for type: ReviewType, context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()

        // 1. Determine Target Cycle (Where notes are COMING FROM)
        let targetLevel: Int16
        switch type {
        case .weekly: targetLevel = ReviewCycle.daily.rawValue // Review daily notes
        case .monthly: targetLevel = ReviewCycle.weekly.rawValue // Review weekly notes
        case .yearly: targetLevel = ReviewCycle.monthly.rawValue // Review monthly notes
        }

        // 2. Determine Date Threshold (Start of CURRENT period)
        let calendar = Calendar.current
        let now = Date()
        let thresholdDate: Date?

        switch type {
        case .weekly:
            thresholdDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        case .monthly:
            thresholdDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
        case .yearly:
            thresholdDate = calendar.date(from: calendar.dateComponents([.year], from: now))
        }

        guard let threshold = thresholdDate else { return 0 }

        let cyclePredicate = NSPredicate(format: "reviewCycle == %d", targetLevel)
        let archivePredicate = NSPredicate(format: "isArchived == NO")
        let datePredicate = NSPredicate(format: "createdDate < %@", threshold as NSDate)

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            cyclePredicate,
            archivePredicate,
            datePredicate,
        ])

        return (try? context.count(for: request)) ?? 0
    }

    // MARK: - Update Badge

    /// Update app badge with total pending sessions (not note count)
    func updateBadge(context: NSManagedObjectContext) {
        let total = calculateTotalPendingSessions(context: context)

        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(total)
        }
    }

    /// Clear app badge
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
