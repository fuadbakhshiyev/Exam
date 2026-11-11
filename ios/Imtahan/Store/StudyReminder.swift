import Foundation
import Observation
import UserNotifications

/// Daily study reminder (Tənzimləmələr → Xatırlatma). Device-local settings in UserDefaults.
///
/// Instead of one repeating trigger (whose text can't change), it keeps a rolling set of one-shot
/// notifications: today's (only while today's goal isn't reached, with the remaining count) plus the
/// next 7 days with a generic text. It's rebuilt whenever today's count changes (widget snapshot pass),
/// at launch and when the app goes to the background.
@MainActor
@Observable
final class StudyReminder {
    static let shared = StudyReminder()

    static let goalChoices: [(count: Int, level: String)] = [
        (50, "Amateur"), (100, "Beginner"), (200, "Novice"), (300, "Intermediate"), (500, "Advanced"),
    ]

    private static let enabledKey = "reminder_enabled"
    private static let hourKey = "reminder_hour"
    private static let minuteKey = "reminder_minute"
    private static let goalKey = "reminder_goal"
    private static let idPrefix = "study-reminder-"
    private static let daysAhead = 7

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey); reschedule() }
    }
    var hour: Int {
        didSet { defaults.set(hour, forKey: Self.hourKey); reschedule() }
    }
    var minute: Int {
        didSet { defaults.set(minute, forKey: Self.minuteKey); reschedule() }
    }
    /// Questions per day after which today's reminder is skipped.
    var goal: Int {
        didSet { defaults.set(goal, forKey: Self.goalKey); reschedule() }
    }
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var answeredToday = 0
    @ObservationIgnored private var answeredDay = ""
    @ObservationIgnored private var lastSignature: String?

    private init() {
        let d = UserDefaults.standard
        isEnabled = d.bool(forKey: Self.enabledKey)
        hour = d.object(forKey: Self.hourKey) as? Int ?? 20
        minute = d.object(forKey: Self.minuteKey) as? Int ?? 0
        goal = d.object(forKey: Self.goalKey) as? Int ?? 50
    }

    var goalLevel: String { Self.goalChoices.first { $0.count == goal }?.level ?? "Amateur" }

    /// Reminder time as a Date today (for DatePicker .hourAndMinute).
    var time: Date {
        get { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date() }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            if c.hour != hour { hour = c.hour ?? 20 }
            if c.minute != minute { minute = c.minute ?? 0 }
        }
    }

    var isDenied: Bool { authorization == .denied }

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if isEnabled && isDenied { lastSignature = nil }
    }

    /// Toggle handler: asks for permission when turning on.
    func setEnabled(_ on: Bool) async {
        guard on else { isEnabled = false; return }
        await refreshAuthorization()
        if authorization == .notDetermined {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorization()
        }
        isEnabled = !isDenied
    }

    /// Today's answered count changed (or the app is going to the background).
    func refresh(answered: Int) {
        answeredToday = answered
        answeredDay = StudySnapshot.dayKey(Date())
        reschedule()
    }

    private func reschedule() {
        let now = Date()
        let todayKey = StudySnapshot.dayKey(now)
        let answered = answeredDay == todayKey ? answeredToday : 0
        let remaining = max(0, goal - answered)
        let sig = "\(isEnabled)|\(hour):\(minute)|\(goal)|\(todayKey)|\(remaining)"
        guard sig != lastSignature else { return }
        lastSignature = sig

        let center = UNUserNotificationCenter.current()
        let ids = (0...Self.daysAhead).map { "\(Self.idPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard isEnabled else { return }

        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        for offset in 0...Self.daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: start),
                  let fire = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Məşq vaxtıdır 📚"
            if offset == 0 {
                guard remaining > 0 else { continue }  // today's goal reached → no reminder today
                content.body = answered == 0
                    ? "Bu gün hələ sual həll etməmisən — hədəf: \(goalLevel) (\(goal) sual)."
                    : "Bu gün hələ \(remaining) sual qalıb — hədəf: \(goalLevel)."
            } else {
                content.body = "Gündəlik hədəfin: \(goalLevel) — \(goal) sual. Bir neçə sual həll edək?"
            }
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: ids[offset], content: content, trigger: trigger))
        }
    }
}
