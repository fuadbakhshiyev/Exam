import Foundation
import Observation
import UserNotifications

/// Kilid ekranında sual: a question arrives as a notification every N minutes (within an hour range);
/// the option buttons (long-press / pull down) answer it without opening the app. The answer is recorded
/// like a surprise answer (stats, wrong/correct lists, Ağıllı təkrar, mastery), then a result notification
/// says whether it was right.
///
/// iOS keeps at most 64 pending notifications, so a rolling batch is scheduled ahead and refilled
/// whenever the app runs (launch, foreground/background, and after every answer from a notification).
@MainActor
@Observable
final class LockScreenQuestions {
    static let shared = LockScreenQuestions()

    static let enabledKey = "lockq_enabled"
    static let intervalKey = "lockq_interval_min"
    static let startKey = "lockq_start_hour"
    static let endKey = "lockq_end_hour"
    static let intervalChoices = [5, 10, 15, 30, 60]

    nonisolated static let idPrefix = "lockq-"
    nonisolated static let resultID = "lockq-result"
    private static let thread = "lockq"
    private static let batch = 48          // leaves room for the reminder, weekly report and Pomodoro
    private static let actionPrefix = "lockq-opt-"
    private static let letters = ["A", "B", "C", "D", "E", "F"]

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey); reschedule() }
    }
    var intervalMinutes: Int {
        didSet { defaults.set(intervalMinutes, forKey: Self.intervalKey); reschedule() }
    }
    /// Questions come only from startHour:00 up to endHour:00.
    var startHour: Int {
        didSet { defaults.set(startHour, forKey: Self.startKey); reschedule() }
    }
    var endHour: Int {
        didSet { defaults.set(endHour, forKey: Self.endKey); reschedule() }
    }
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    var isDenied: Bool { authorization == .denied }

    @ObservationIgnored private let defaults = UserDefaults.standard
    /// How the last notification answer went; shown as the next question's subtitle.
    @ObservationIgnored private var lastResult: String?

    private init() {
        let d = UserDefaults.standard
        isEnabled = d.bool(forKey: Self.enabledKey)
        intervalMinutes = d.object(forKey: Self.intervalKey) as? Int ?? 5
        startHour = d.object(forKey: Self.startKey) as? Int ?? 9
        endHour = d.object(forKey: Self.endKey) as? Int ?? 23
        NotificationCenter.default.addObserver(forName: SyncedPrefs.didApply, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { LockScreenQuestions.shared.reloadSyncedSettings() }
        }
    }

    /// Settings changed on another device.
    private func reloadSyncedSettings() {
        let d = defaults
        let on = d.bool(forKey: Self.enabledKey)
        if on != isEnabled { isEnabled = on }
        let iv = d.object(forKey: Self.intervalKey) as? Int ?? 5
        if iv != intervalMinutes { intervalMinutes = iv }
        let s = d.object(forKey: Self.startKey) as? Int ?? 9
        if s != startHour { startHour = s }
        let e = d.object(forKey: Self.endKey) as? Int ?? 23
        if e != endHour { endHour = e }
    }

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
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

    var hoursText: String { String(format: "%02d:00–%02d:00", startHour, endHour) }

    // MARK: Scheduling

    /// Rebuilds the pending batch (new questions, fire times from now). Cheap enough to call often.
    func reschedule() {
        Task { await rescheduleNow() }
    }

    func rescheduleNow() async {
        let center = UNUserNotificationCenter.current()
        let enabled = isEnabled, interval = intervalMinutes, start = startHour, end = endHour
        do {
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) && !$0.hasPrefix(Self.resultID) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            guard enabled else {
                center.setNotificationCategories([])
                return
            }
            let times = Self.fireTimes(from: Date(), every: interval, start: start, end: end, count: Self.batch)
            let questions = pickQuestions(times.count)
            // Categories first, so the buttons exist when the first question arrives.
            center.setNotificationCategories(Set(questions.indices.map {
                Self.category(id: "\(Self.idPrefix)cat-\($0)", for: questions[$0])
            }))
            for (i, (fire, q)) in zip(times, questions).enumerated() {
                let catID = "\(Self.idPrefix)cat-\(i)"
                let content = UNMutableNotificationContent()
                content.title = "\(QuestionBank.baseCourse(q.c)) · Unit \(q.u)"
                if i == 0, let lastResult { content.subtitle = lastResult }
                content.body = Self.body(of: q)
                content.sound = .default
                content.threadIdentifier = Self.thread
                content.categoryIdentifier = catID
                content.userInfo = ["lockq": Self.encode(q)]
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                try? await center.add(UNNotificationRequest(identifier: "\(Self.idPrefix)\(i)", content: content,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }

    /// Next `count` times on the interval grid inside [start, end) hours, after `now`.
    nonisolated static func fireTimes(from now: Date, every minutes: Int, start: Int, end: Int, count: Int) -> [Date] {
        let cal = Calendar.current
        var out: [Date] = []
        var t = now.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        let limit = now.addingTimeInterval(3 * 86_400)
        while out.count < count && t < limit {
            let h = cal.component(.hour, from: t)
            let inside = start < end ? (h >= start && h < end) : (h >= start || h < end)   // e.g. 22–02 wraps
            if inside || start == end {
                out.append(t)
                t = t.addingTimeInterval(TimeInterval(minutes * 60))
            } else {
                // Jump to the next start hour.
                let base = cal.date(bySettingHour: start, minute: 0, second: 0, of: t) ?? t
                t = base > t ? base : cal.date(byAdding: .day, value: 1, to: base) ?? limit
            }
        }
        return out
    }

    /// Due Ağıllı təkrar questions first, then wrong ones, then not yet learned, then the rest
    /// (random inside each group). Questions with pictures are skipped (a notification can't show them).
    private func pickQuestions(_ n: Int) -> [Question] {
        let store = StudyStore.shared
        let allowed = Set(Self.activeSubjects)
        let pool = QuestionBank.shared.all.filter {
            $0.c != Catalog.mixedKey && store.inScope($0) && allowed.contains(QuestionBank.baseCourse($0.c))
                && !$0.q.contains("<img") && !$0.o.contains { $0.contains("<img") } && (2...6).contains($0.o.count)
        }
        guard !pool.isEmpty else { return [] }
        store.seedReviewIfNeeded()
        let due = Set(store.reviewDueQuestions(limit: 10_000).map(\.q))
        let wrong = Set(store.data.wrong.values.flatMap { $0 }.map(\.q))
        let correct = Set(store.data.correct.values.flatMap { $0 }.map(\.q))
        func rank(_ q: Question) -> Int {
            due.contains(q.q) ? 0 : wrong.contains(q.q) ? 1 : !correct.contains(q.q) ? 2 : 3
        }
        var out: [Question] = []
        var seen = Set<String>()
        for q in pool.shuffled().sorted(by: { rank($0) < rank($1) }) where seen.insert(q.q).inserted {
            out.append(q)
            if out.count == n { break }
        }
        // Small pools repeat.
        while out.count < n, let q = pool.randomElement() { out.append(q) }
        return out
    }

    /// The Sürpriz sual subjects (every subject when none is chosen).
    private static var activeSubjects: [String] {
        let chosen = Set(UserDefaults.standard.stringArray(forKey: SurpriseEngine.subjectsKey) ?? [])
        let list = Catalog.subjects.filter { chosen.contains($0) }
        let active = Catalog.activeSubjects
        let left = list.filter(active.contains)
        return left.isEmpty ? active : left
    }

    private static func body(of q: Question) -> String {
        let opts = q.o.enumerated().map { "\(letters[$0.offset]) \(RichText.plain($0.element))" }
        return RichText.plain(q.q) + "\n\n" + opts.joined(separator: "\n")
    }

    private static func category(id: String, for q: Question) -> UNNotificationCategory {
        let actions = q.o.indices.map { i in
            var title = "\(letters[i]) \(RichText.plain(q.o[i]))"
            if title.count > 60 { title = String(title.prefix(58)) + "…" }
            return UNNotificationAction(identifier: "\(actionPrefix)\(i)", title: title, options: [])
        }
        return UNNotificationCategory(identifier: id, actions: actions, intentIdentifiers: [], options: [])
    }

    private static func encode(_ q: Question) -> String {
        guard let d = try? JSONEncoder().encode(q) else { return "" }
        return String(decoding: d, as: UTF8.self)
    }

    // MARK: Answers

    /// Whether a notification belongs to this feature (shown as a banner even while the app is open).
    nonisolated static func owns(_ id: String) -> Bool { id.hasPrefix(idPrefix) }

    /// A notification action. Returns true when it was a lock-screen question answer.
    @discardableResult
    func handle(actionID: String, userInfo: [AnyHashable: Any]) async -> Bool {
        guard actionID.hasPrefix(Self.actionPrefix), let i = Int(actionID.dropFirst(Self.actionPrefix.count)),
              let s = userInfo["lockq"] as? String, let d = s.data(using: .utf8),
              let q = try? JSONDecoder().decode(Question.self, from: d), q.o.indices.contains(i) else { return false }
        let correct = i == q.a
        StudyStore.shared.recordSurpriseAnswer(q, isCorrect: correct)

        let content = UNMutableNotificationContent()
        content.title = correct ? "✓ Düzdür!" : "✗ Səhvdir"
        content.body = correct
            ? "\(Self.letters[i]) \(RichText.plain(q.o[i]))"
            : "Sənin cavabın: \(Self.letters[i]) \(RichText.plain(q.o[i]))\nDüzgün cavab: \(Self.letters[q.a]) \(RichText.plain(q.o[safe: q.a] ?? ""))"
        content.sound = .default
        content.threadIdentifier = Self.thread
        let center = UNUserNotificationCenter.current()
        // Earlier results go away; the new one gets its own id (removing and re-adding the same id races,
        // and the removal could take the new result with it).
        let old = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(Self.resultID) }
        center.removeDeliveredNotifications(withIdentifiers: old)
        let id = "\(Self.resultID)-\(Int(Date().timeIntervalSince1970 * 1000))"
        try? await center.add(UNNotificationRequest(identifier: id, content: content,
                                                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
        // The next question also says how the last one went, in case the result banner was missed.
        lastResult = correct ? "Əvvəlki: ✓ Düz" : "Əvvəlki: ✗ Səhv (düzgün: \(Self.letters[q.a]))"
        // Answering keeps the queue topped up even if the app is never opened.
        await rescheduleNow()
        return true
    }

    /// App opened: clear old unanswered questions from Notification Center and top up the queue.
    func appDidBecomeActive() {
        lastResult = nil
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        Task { @MainActor in
            let delivered = await center.deliveredNotifications().map(\.request.identifier).filter(Self.owns)
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
        reschedule()
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
