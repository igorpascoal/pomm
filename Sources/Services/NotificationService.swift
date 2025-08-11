//
//  NotificationService.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import UserNotifications

enum NotificationService {
    private static let timerId = "pomm.timer.end"

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    static func scheduleTimerEndNotification(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Time’s up"
        content.body = "Your focus session has ended."
        content.sound = .default

        let seconds = max(1, Int(date.timeIntervalSinceNow.rounded()))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: timerId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func cancelPending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [timerId])
    }
}
