import UserNotifications

enum NotificationService {
    private static let focusEndId = "pomm.focus.end"
    private static let breakEndId = "pomm.break.end"

    // MARK: - Public

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    /// Focus-end: tells the user it's time for a break and includes the break duration.
    static func scheduleFocusEndNotification(at date: Date, breakMinutes: Int?) {
        let content = UNMutableNotificationContent()
        content.title = "Focus done"
        if let bm = breakMinutes, bm > 0 {
            content.body = "Time for a \(minutesText(bm)) break."
        } else {
            content.body = "Your focus session has ended."
        }
        content.sound = .default

        let seconds = max(1, Int(date.timeIntervalSinceNow.rounded()))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: focusEndId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Break-end: celebrate the completed focus session; optionally include a quote.
    static func scheduleBreakEndNotification(at date: Date, includeQuote: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Break over"
        let base = "🎉 Great work!"
        content.body = includeQuote ? "\(base) \(randomFocusQuote())" : base
        content.sound = .default

        let seconds = max(1, Int(date.timeIntervalSinceNow.rounded()))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: breakEndId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // Only remove pending requests; do not remove delivered notifications immediately.
    static func cancelFocusPending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusEndId])
    }
    static func cancelBreakPending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [breakEndId])
    }
    static func cancelAllPending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusEndId, breakEndId])
    }

    // MARK: - Helpers

    private static func minutesText(_ m: Int) -> String {
        m == 1 ? "1-minute" : "\(m)-minute"
    }

    private static let focusQuotes: [String] = [
        "“Focus is the art of knowing what to ignore.” — James Clear",
        "“The successful warrior is the average man, with laser-like focus.” — Bruce Lee",
        "“What we choose to focus on and what we choose to ignore defines the quality of our life.” — Cal Newport",
        "“You must single out the few things that matter most and focus your mind on them.” — Marcus Aurelius",
        "“Concentrate all your thoughts upon the work at hand.” — Alexander Graham Bell",
        "“The main thing is to keep the main thing the main thing.” — Stephen R. Covey",
        "“Where your attention goes, your time goes.” — Naval Ravikant",
        "“It is not that we have a short time to live, but that we waste much of it.” — Seneca",
        "“The successful person has the habit of doing the things failures don’t like to do.” — Albert E.N. Gray",
        "“Clarity about what matters provides clarity about what does not.” — Greg McKeown",
        "“You will never reach your destination if you stop and throw stones at every dog that barks.” — Winston Churchill",
        "“Nothing is particularly hard if you divide it into small jobs.” — Henry Ford",
        "“It’s not the daily increase but daily decrease: hack away at the unessential.” — Bruce Lee",
        "“To do two things at once is to do neither.” — Publilius Syrus",
        "“The ability to simplify means to eliminate the unnecessary.” — Hans Hofmann",
        "“Starve your distractions; feed your focus.” — Anonymous",
        "“What gets scheduled gets done.” — Michael Hyatt",
        "“Simplicity is the ultimate sophistication.” — Leonardo da Vinci",
        "“Beware the barrenness of a busy life.” — Socrates",
        "“The shorter way to do many things is to do only one thing at a time.” — Mozart"
    ]

    private static func randomFocusQuote() -> String {
        focusQuotes.randomElement() ?? "“Focus brings results.”"
    }
}
