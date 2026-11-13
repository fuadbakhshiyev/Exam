import Foundation
import Observation

// Learning helpers. Device-local, plus a small extra cloud field next to the semester data
// (Sync/ExtrasSync.swift) so the phone and the Mac share exam dates and what is learned:
// - ExamDates: one exam day and time per subject (falls back to the general exam date, 09:00).
// - LearnSettings: "Səhvlər testin sonunda qayıtsın" switch.
// - MasteryStore: a question is "öyrənilib" after 2 correct answers in a row; a wrong answer or
//   "Bilmirəm" resets it. Keyed by normalized question text, so all copies of a question count together.

@MainActor
@Observable
final class ExamDates {
    static let shared = ExamDates()
    private static let key = "exam_dates"

    private static let updatedKey = "exam_dates_updated"

    /// subject → seconds since 1970.
    private(set) var raw: [String: Double]
    /// subject → when it was last changed (sync: the newer change wins).
    private(set) var updated: [String: Double]

    private init() {
        raw = UserDefaults.standard.dictionary(forKey: Self.key) as? [String: Double] ?? [:]
        updated = UserDefaults.standard.dictionary(forKey: Self.updatedKey) as? [String: Double] ?? [:]
    }

    private func persist() {
        UserDefaults.standard.set(raw, forKey: Self.key)
        UserDefaults.standard.set(updated, forKey: Self.updatedKey)
    }

    /// Sync: subject → [date, updatedAt].
    var syncValue: [String: [Double]] {
        raw.reduce(into: [:]) { $0[$1.key] = [$1.value, updated[$1.key] ?? 0] }
    }

    func merge(_ remote: [String: [Double]]) {
        var changed = false
        for (s, v) in remote where v.count == 2 && v[0] > 0 && v[1] > (updated[s] ?? -1) {
            raw[s] = v[0]; updated[s] = v[1]; changed = true
        }
        if changed { persist() }
    }

    func date(for subject: String) -> Date {
        if let t = raw[subject], t > 0 { return Date(timeIntervalSince1970: t) }
        return StudyStore.shared.examDate
    }

    func set(_ date: Date, for subject: String) {
        raw[subject] = date.timeIntervalSince1970
        updated[subject] = Date().timeIntervalSince1970
        persist()
        StudyStore.shared.onLocalChange?(true)   // push to the cloud soon
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

    /// QuestionHash of the normalized text → correct answers in a row.
    private(set) var streaks: [String: Int] = [:]
    /// Same key → when it last changed (sync: the newer answer wins).
    @ObservationIgnored private var stamps: [String: Double] = [:]
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// question text → key (normalizing is regex work; lists are checked on every render).
    @ObservationIgnored private var keyCache: [String: String] = [:]

    private struct FileShape: Codable { var streaks: [String: Int]; var stamps: [String: Double] }

    private func key(_ q: Question) -> String {
        if let k = keyCache[q.q] { return k }
        let n = StudyStore.normalizedQuestionText(q.q)
        let k = n.isEmpty ? "" : QuestionHash.hash(n)
        keyCache[q.q] = k
        return k
    }

    private init() {
        fileURL = StudyStore.defaultFileURL().deletingLastPathComponent().appendingPathComponent("mastery.json")
        guard let raw = try? Data(contentsOf: fileURL) else { return }
        if let f = try? JSONDecoder().decode(FileShape.self, from: raw) {
            streaks = f.streaks; stamps = f.stamps
        } else if let old = try? JSONDecoder().decode([String: Int].self, from: raw) {
            // First version: keyed by the normalized text itself.
            let now = Date().timeIntervalSince1970
            for (text, v) in old { let k = QuestionHash.hash(text); streaks[k] = v; stamps[k] = now }
        }
    }

    func record(_ q: Question, isCorrect: Bool) {
        let key = key(q)
        guard !key.isEmpty else { return }
        streaks[key] = isCorrect ? min((streaks[key] ?? 0) + 1, Self.needed) : 0
        stamps[key] = Date().timeIntervalSince1970
        scheduleSave()
    }

    func isLearned(_ q: Question) -> Bool {
        (streaks[key(q)] ?? 0) >= Self.needed
    }

    func clear() {
        streaks = [:]
        stamps = [:]
        flush()
    }

    /// Sync: key → [streak, changedAt].
    var syncValue: [String: [Double]] {
        streaks.reduce(into: [:]) { $0[$1.key] = [Double($1.value), stamps[$1.key] ?? 0] }
    }

    func merge(_ remote: [String: [Double]]) {
        var changed = false
        for (k, v) in remote where v.count == 2 && v[1] > (stamps[k] ?? -1) {
            streaks[k] = Int(v[0]); stamps[k] = v[1]; changed = true
        }
        if changed { flush() }
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
        guard let raw = try? JSONEncoder().encode(FileShape(streaks: streaks, stamps: stamps)) else { return }
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
