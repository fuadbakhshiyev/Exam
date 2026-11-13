import Foundation
import Observation

// Learning helpers (device-local, never synced):
// - ExamDates: one exam day and time per subject (falls back to the general exam date, 09:00).
// - LearnSettings: "Səhvlər testin sonunda qayıtsın" switch.
// - MasteryStore: a question is "öyrənilib" after 2 correct answers in a row; a wrong answer or
//   "Bilmirəm" resets it. Keyed by normalized question text, so all copies of a question count together.

@MainActor
@Observable
final class ExamDates {
    static let shared = ExamDates()
    private static let key = "exam_dates"

    /// subject → seconds since 1970.
    private(set) var raw: [String: Double]

    private init() {
        raw = UserDefaults.standard.dictionary(forKey: Self.key) as? [String: Double] ?? [:]
    }

    func date(for subject: String) -> Date {
        if let t = raw[subject], t > 0 { return Date(timeIntervalSince1970: t) }
        return StudyStore.shared.examDate
    }

    func set(_ date: Date, for subject: String) {
        raw[subject] = date.timeIntervalSince1970
        UserDefaults.standard.set(raw, forKey: Self.key)
    }

    /// Whole days left for a subject (0 = today, negative = past).
    func daysLeft(_ subject: String) -> Int { StudyStore.daysUntil(date(for: subject)) }

    /// Has the subject's exam started already (date and time passed)?
    func isOver(_ subject: String, now: Date = Date()) -> Bool { date(for: subject) <= now }

    /// The nearest exam that has not started yet.
    var next: (subject: String, days: Int, date: Date)? {
        let now = Date()
        return Catalog.subjects.map { ($0, daysLeft($0), date(for: $0)) }
            .filter { $0.2 > now }
            .min { $0.2 < $1.2 }
    }

    /// "10:00"
    func timeText(_ subject: String) -> String {
        date(for: subject).formatted(date: .omitted, time: .shortened)
    }

    /// Changes whenever any date changes (daily plan snapshot tag).
    var tag: String {
        Catalog.subjects.map { String(Int(date(for: $0).timeIntervalSince1970)) }.joined(separator: ",")
    }
}

@MainActor
@Observable
final class LearnSettings {
    static let shared = LearnSettings()
    private static let requeueKey = "requeue_wrong"

    /// Wrong / "Bilmirəm" questions come back at the end of the same test until answered correctly.
    var requeueWrong: Bool {
        didSet { UserDefaults.standard.set(requeueWrong, forKey: Self.requeueKey) }
    }

    private init() {
        requeueWrong = UserDefaults.standard.object(forKey: Self.requeueKey) as? Bool ?? true
    }
}

@MainActor
@Observable
final class MasteryStore {
    static let shared = MasteryStore()
    /// Correct answers in a row needed to call a question learned.
    static let needed = 2

    /// normalized question text → correct answers in a row.
    private(set) var streaks: [String: Int] = [:]
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// question text → normalized key (normalizing is regex work; lists are checked on every render).
    @ObservationIgnored private var keyCache: [String: String] = [:]

    private func key(_ q: Question) -> String {
        if let k = keyCache[q.q] { return k }
        let k = StudyStore.normalizedQuestionText(q.q)
        keyCache[q.q] = k
        return k
    }

    private init() {
        fileURL = StudyStore.defaultFileURL().deletingLastPathComponent().appendingPathComponent("mastery.json")
        if let raw = try? Data(contentsOf: fileURL), let s = try? JSONDecoder().decode([String: Int].self, from: raw) {
            streaks = s
        }
    }

    func record(_ q: Question, isCorrect: Bool) {
        let key = key(q)
        guard !key.isEmpty else { return }
        streaks[key] = isCorrect ? min((streaks[key] ?? 0) + 1, Self.needed) : 0
        scheduleSave()
    }

    func isLearned(_ q: Question) -> Bool {
        (streaks[key(q)] ?? 0) >= Self.needed
    }

    func clear() {
        streaks = [:]
        flush()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.flush()
        }
    }

    func flush() {
        saveTask?.cancel(); saveTask = nil
        guard let raw = try? JSONEncoder().encode(streaks) else { return }
        let url = fileURL
        Task.detached(priority: .utility) { try? raw.write(to: url, options: .atomic) }
    }
}

extension StudyStore {
    /// "Öyrənilməmişlər": the subject's "Bütün suallar" set without the learned ones.
    func unlearnedQuestions(_ subject: String) -> [Question] {
        let m = MasteryStore.shared
        return allSubjectQuestions(subject).filter { !m.isLearned($0) }
    }

    /// (learned, total) over the subject's "Bütün suallar" set.
    func masteryProgress(_ subject: String) -> (learned: Int, total: Int) {
        let all = allSubjectQuestions(subject)
        let m = MasteryStore.shared
        return (all.filter { m.isLearned($0) }.count, all.count)
    }
}
