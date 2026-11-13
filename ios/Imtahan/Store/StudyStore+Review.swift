import Foundation
import Observation

// "Ağıllı təkrar": a Leitner box per question (key = question text, like wrongCounts). Device-local
// (Application Support/Imtahan/review.json), never part of StudyData, so the sync wire format is unchanged.
// Wrong answer → box 1, due tomorrow. A correct answer to a due question moves it up a box
// (intervals 1, 3, 7, 14 days); past the last box it is mastered and dropped.

struct ReviewEntry: Codable, Hashable, Sendable {
    var question: Question
    /// 1…ReviewStore.intervals.count
    var box: Int
    /// Local "YYYY-MM-DD" (StudyStore.dayKey); due when ≤ today.
    var due: String
}

@MainActor
@Observable
final class ReviewStore {
    static let shared = ReviewStore()

    /// Days until the next review after landing in box i+1.
    static let intervals = [1, 3, 7, 14]

    private(set) var entries: [String: ReviewEntry] = [:]
    /// True once the wrong lists were copied in (or an answer was recorded).
    private(set) var seeded = false

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private struct FileShape: Codable {
        var seeded: Bool
        var entries: [String: ReviewEntry]
    }

    init(fileURL: URL? = nil) {
        let url = fileURL ?? StudyStore.defaultFileURL().deletingLastPathComponent().appendingPathComponent("review.json")
        self.fileURL = url
        if let raw = try? Data(contentsOf: url), let f = try? JSONDecoder().decode(FileShape.self, from: raw) {
            entries = f.entries
            seeded = f.seeded
        }
    }

    /// "Statistikanı sıfırla": forget every scheduled review (re-seeds from the wrong lists later).
    func clear() {
        entries = [:]
        seeded = false
        flush()
    }

    static func day(_ offset: Int, from date: Date = Date()) -> String {
        StudyStore.dayKey(Calendar.current.date(byAdding: .day, value: offset, to: date) ?? date)
    }

    /// First run: every currently-wrong question is due today. Waits until there is something to copy
    /// (a fresh device may get its wrong lists from the cloud a moment later).
    func seedIfNeeded(from wrong: [String: [Question]]) {
        guard !seeded else { return }
        let today = Self.day(0)
        var added = false
        for key in wrong.keys.sorted() {
            for q in wrong[key] ?? [] where entries[q.q] == nil {
                entries[q.q] = ReviewEntry(question: q, box: 1, due: today)
                added = true
            }
        }
        guard added else { return }
        seeded = true
        scheduleSave()
    }

    /// Bookkeeping for one answer.
    func record(_ q: Question, isCorrect: Bool) {
        seeded = true
        if !isCorrect {
            entries[q.q] = ReviewEntry(question: q, box: 1, due: Self.day(1))
        } else if var e = entries[q.q], e.due <= Self.day(0) {
            e.box += 1
            if e.box > Self.intervals.count {
                entries[q.q] = nil
            } else {
                e.due = Self.day(Self.intervals[e.box - 1])
                entries[q.q] = e
            }
        } else {
            return
        }
        scheduleSave()
    }

    /// Due entries matching `filter`, most overdue first (then lower box).
    func due(where filter: (Question) -> Bool) -> [ReviewEntry] {
        let today = Self.day(0)
        return entries.values
            .filter { $0.due <= today && filter($0.question) }
            .sorted { ($0.due, $0.box, $0.question.q) < ($1.due, $1.box, $1.question.q) }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            self.flush()
        }
    }

    /// Writes the file now.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard let raw = try? JSONEncoder().encode(FileShape(seeded: seeded, entries: entries)) else { return }
        let url = fileURL
        Task.detached(priority: .utility) { try? raw.write(to: url, options: .atomic) }
    }
}

extension StudyStore {
    var review: ReviewStore { ReviewStore.shared }

    /// Hook called from recordQuizAnswer / recordSurpriseAnswer.
    func recordReview(_ q: Question, isCorrect: Bool) {
        review.seedIfNeeded(from: data.wrong)
        review.record(q, isCorrect: isCorrect)
    }

    /// Due in-scope questions for "Bu günün təkrarı" (cap 50, most overdue first).
    func reviewDueQuestions(limit: Int = 50) -> [Question] {
        review.seedIfNeeded(from: data.wrong)
        return Array(review.due(where: { inScope($0) }).prefix(limit)).map(\.question)
    }

    /// Number of due in-scope questions (uncapped). Read-only: call seedReviewIfNeeded() outside view updates.
    var reviewDueCount: Int { review.due(where: { inScope($0) }).count }

    func seedReviewIfNeeded() { review.seedIfNeeded(from: data.wrong) }
}

extension QuizSession {
    /// Per-question stat attribution for sessions that mix subjects/units (review, weak topics):
    /// nil = the session's own stat. Weak-topic answers go to the question's unit bucket so the
    /// ranking reacts to practice.
    static func perQuestionStat(_ kind: Kind, _ q: Question) -> (course: String, cat: String, sub: String)? {
        switch kind {
        case .review:
            return (q.c, "review", "Bu günün təkrarı")
        case .allQuestions, .unlearned:
            // Unit answers count for that unit (as on its own page); unknown-unit booklet questions go to review.
            guard Catalog.unitCounts[q.c] != nil, q.u >= 1 else { return (q.c, "review", "Bütün suallar") }
            return (q.c, "units", "Unit \(q.u)")
        case .weakTopics:
            guard Catalog.unitCounts[q.c] != nil, q.u >= 1 else { return (q.c, "review", "Zəif mövzular") }
            return (q.c, "units", "Unit \(q.u)")
        default:
            return nil
        }
    }
}
