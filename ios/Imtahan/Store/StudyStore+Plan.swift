import Foundation

// Exam countdown, per-subject daily plan and weak units (Home "Bu gün" area). Everything is derived from
// existing data; the exam date and today's plan snapshot are device-local (UserDefaults), never synced.

struct DailyPlanRow: Hashable, Sendable, Identifiable {
    var id: String { subject }
    let subject: String
    /// Questions planned for today (fixed for the day).
    let planned: Int
    /// Answered today in this subject (history).
    let doneToday: Int
    /// In-scope questions never answered yet.
    let remaining: Int
    /// 0-based unit to start: first in-scope unit with unanswered questions.
    let nextUnit: Int
    var isComplete: Bool { doneToday >= planned }
}

struct WeakUnit: Hashable, Sendable, Identifiable {
    var id: String { "\(subject)#\(unit)" }
    let subject: String
    /// 1-based
    let unit: Int
    let correct: Int
    let answered: Int
    var accuracy: Int { answered > 0 ? Int((Double(correct) / Double(answered) * 100).rounded()) : 0 }
    /// "Özgün Baskı · Ünitə 4"
    var title: String { "\(StudyStore.shortSubject(subject)) · Ünitə \(unit)" }
}

extension StudyStore {
    static let examDateKey = "exam_date"
    private static let planSnapshotKey = "daily_plan_snapshot"

    /// Default exam date: the last day of Catalog.studyPeriod (2026-11-22).
    static var defaultExamDate: Date {
        let p = Catalog.studyPeriod.end.split(separator: "-").compactMap { Int($0) }
        var dc = DateComponents(); dc.year = p[studySafe: 0]; dc.month = p[studySafe: 1]; dc.day = p[studySafe: 2]; dc.hour = 9
        return Calendar.current.date(from: dc) ?? Date()
    }

    /// İmtahan tarixi (Settings). Stored in UserDefaults; not observed, so views read it via @AppStorage.
    var examDate: Date {
        get {
            let t = defaults.double(forKey: Self.examDateKey)
            return t > 0 ? Date(timeIntervalSince1970: t) : Self.defaultExamDate
        }
        set { defaults.set(newValue.timeIntervalSince1970, forKey: Self.examDateKey) }
    }

    /// Whole days from today to the exam day (0 = today, negative = past).
    static func daysUntil(_ exam: Date, now: Date = Date()) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: exam)).day ?? 0
    }

    /// "Grafik Üretim", "Özgün Baskı", "Reklam Grafiği", "Tasarım Okumaları", "Web Tasarımı".
    nonisolated static func shortSubject(_ s: String) -> String {
        switch s {
        case "Grafik Üretim Teknikleri": return "Grafik Üretim"
        case "Özgün Baskı Teknikleri": return "Özgün Baskı"
        case "Web Tasarımının Temelleri": return "Web Tasarımı"
        default: return s
        }
    }

    // MARK: Daily plan

    /// Texts of a subject's questions that were ever answered (union of its correct and wrong lists).
    private func answeredTexts(_ subject: String) -> Set<String> {
        Set((data.correct[subject] ?? []).map(\.q)).union((data.wrong[subject] ?? []).map(\.q))
    }

    /// In-scope questions of a subject never answered, and the first unit that still has some.
    private func remaining(_ subject: String) -> (count: Int, nextUnit: Int) {
        let seen = answeredTexts(subject)
        var count = 0
        var first: Int?
        for q in scopedQuestions(course: subject) where !seen.contains(q.q) {
            count += 1
            if q.u >= 1, first.map({ q.u - 1 < $0 }) ?? true { first = q.u - 1 }
        }
        return (count, first ?? 0)
    }

    /// Today's answered count of one subject from the history (unit, wrong-list, pdf… sessions of that subject).
    func todayAnswered(_ subject: String) -> Int {
        guard let dc = data.history[Self.dayKey()]?.courses[subject] else { return 0 }
        return dc.correct + dc.wrong
    }

    /// Per-subject plan: remaining ÷ days left (rounded up). The target is fixed for the day (snapshot in
    /// UserDefaults keyed by day, mode and exam date) so it does not shrink while you study.
    func dailyPlan() -> [DailyPlanRow] {
        let dates = ExamDates.shared
        let today = Self.dayKey()
        let tag = "\(today)|\(examMode.rawValue)|\(dates.tag)"
        var snap = defaults.dictionary(forKey: Self.planSnapshotKey) as? [String: Int] ?? [:]
        let fresh = defaults.string(forKey: Self.planSnapshotKey + "_tag") != tag
        if fresh { snap = [:] }
        var changed = fresh
        let rows = Catalog.subjects.map { s -> DailyPlanRow in
            let r = remaining(s)
            let done = todayAnswered(s)
            let planned: Int
            if let p = snap[s] {
                planned = p
            } else {
                // First look today: include what was already answered today so the target stays honest.
                // Each subject is spread over the days left until its own exam (none after it).
                let left = dates.daysLeft(s)
                let days = max(1, left)
                planned = (r.count == 0 || left < 0) ? 0 : Int((Double(r.count + done) / Double(days)).rounded(.up))
                snap[s] = planned
                changed = true
            }
            return DailyPlanRow(subject: s, planned: planned, doneToday: done, remaining: r.count, nextUnit: r.nextUnit)
        }
        if changed {
            defaults.set(snap, forKey: Self.planSnapshotKey)
            defaults.set(tag, forKey: Self.planSnapshotKey + "_tag")
        }
        return rows
    }

    // MARK: Weak units

    /// In-scope subject units with ≥ minAnswered answers, lowest accuracy first.
    func weakUnits(limit: Int = 5, minAnswered: Int = 5) -> [WeakUnit] {
        var out: [WeakUnit] = []
        for s in Catalog.subjects {
            for (key, st) in data.stats[s]?.bd["units"] ?? [:] {
                guard key.hasPrefix("Unit "), let n = Int(key.dropFirst(5)), inScope(unit: n),
                      n <= (Catalog.unitCounts[s] ?? 0) else { continue }
                let answered = st.c + st.w
                guard answered >= minAnswered else { continue }
                out.append(WeakUnit(subject: s, unit: n, correct: st.c, answered: answered))
            }
        }
        out.sort { a, b in
            let la = Double(a.correct) / Double(a.answered), lb = Double(b.correct) / Double(b.answered)
            return la != lb ? la < lb : (a.answered != b.answered ? a.answered > b.answered : a.id < b.id)
        }
        return Array(out.prefix(limit))
    }

    /// "Zəif mövzular" session: questions of the weakest units, shuffled, cap 30.
    func weakTopicQuestions(limit: Int = 30) -> [Question] {
        let units = weakUnits()
        guard !units.isEmpty else { return [] }
        // An even share from each weak unit, so a large unit does not crowd out the weakest one.
        let per = Int((Double(limit) / Double(units.count)).rounded(.up))
        var pool: [Question] = []
        for u in units { pool += bank.unitQuestions(course: u.subject, unit: u.unit).shuffled().prefix(per) }
        return Array(pool.shuffled().prefix(limit))
    }
}
