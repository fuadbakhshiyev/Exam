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
    /// When it last changed (ms since 1970; sync: the newer one wins). nil for older files.
    var t: Double? = nil
}

/// Ağıllı təkrar on the wire: box, due day and change time per question text (the question itself is
/// looked up in the bank), plus the questions dropped as mastered and when.
struct ReviewSync: Codable, Equatable, Sendable {
    struct Box: Codable, Equatable, Sendable { var b: Int; var d: String; var t: Double }
    var boxes: [String: Box] = [:]
    var removed: [String: Double] = [:]
    var seeded = false

    var isEmpty: Bool { boxes.isEmpty && removed.isEmpty }

    static func merge(_ a: ReviewSync, _ b: ReviewSync) -> ReviewSync {
        var out = ReviewSync(seeded: a.seeded || b.seeded)
        let keys = Set(a.boxes.keys).union(b.boxes.keys).union(a.removed.keys).union(b.removed.keys)
        for k in keys {
            // Newer change wins; same time (older entries have none): the later due day, then the higher box,
            // so both devices settle on the same entry.
            let box = [a.boxes[k], b.boxes[k]].compactMap { $0 }.max { ($0.t, $0.d, $0.b) < ($1.t, $1.d, $1.b) }
            let gone = [a.removed[k], b.removed[k]].compactMap { $0 }.max()
            if let gone, gone >= (box?.t ?? 0) { out.removed[k] = gone }
            else if let box { out.boxes[k] = box }
        }
        return out
    }
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

    /// Mastered questions dropped from the boxes (text → when), so another device does not bring them back.
    @ObservationIgnored private var removed: [String: Double] = [:]

    private struct FileShape: Codable {
        var seeded: Bool
        var entries: [String: ReviewEntry]
        var removed: [String: Double]?
    }

    private static var now: Double { Date().timeIntervalSince1970 * 1000 }

    init(fileURL: URL? = nil) {
        let url = fileURL ?? StudyStore.defaultFileURL().deletingLastPathComponent().appendingPathComponent("review.json")
        self.fileURL = url
        if let raw = try? Data(contentsOf: url), let f = try? JSONDecoder().decode(FileShape.self, from: raw) {
            entries = f.entries
            seeded = f.seeded
            removed = f.removed ?? [:]
        }
    }

    var syncValue: ReviewSync {
        ReviewSync(boxes: entries.mapValues { .init(b: $0.box, d: $0.due, t: $0.t ?? 0) }, removed: removed, seeded: seeded)
    }

    /// Boxes changed on other devices; a question unknown to this bank is skipped.
    func merge(_ remote: ReviewSync) {
        let merged = ReviewSync.merge(syncValue, remote)
        guard merged != syncValue else { return }
        var next: [String: ReviewEntry] = [:]
        for (k, b) in merged.boxes {
            if let e = entries[k] { next[k] = ReviewEntry(question: e.question, box: b.b, due: b.d, t: b.t) }
            else if let q = Self.bankQuestion(k) { next[k] = ReviewEntry(question: q, box: b.b, due: b.d, t: b.t) }
        }
        entries = next
        removed = merged.removed
        seeded = merged.seeded
        scheduleSave()
    }

    private static var textIndex: [String: Question]?

    private static func bankQuestion(_ text: String) -> Question? {
        if textIndex == nil {
            let b = QuestionBank.shared
            var idx: [String: Question] = [:]
            for q in b.all { idx[q.q] = idx[q.q] ?? q }
            for list in b.pdfExams.values { for exam in list { for q in exam { idx[q.q] = idx[q.q] ?? q } } }
            for list in b.pdfFinals.values { for exam in list { for q in exam.questions { idx[q.q] = idx[q.q] ?? q } } }
            textIndex = idx
        }
        return textIndex?[text]
    }

    /// "Statistikanı sıfırla": forget every scheduled review (re-seeds from the wrong lists later).
    func clear() {
        let t = Self.now
        for k in entries.keys { removed[k] = t }
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
            entries[q.q] = ReviewEntry(question: q, box: 1, due: Self.day(1), t: Self.now)
            removed[q.q] = nil
        } else if var e = entries[q.q], e.due <= Self.day(0) {
            e.box += 1
            e.t = Self.now
            if e.box > Self.intervals.count {
                entries[q.q] = nil
                removed[q.q] = e.t
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
        guard let raw = try? JSONEncoder().encode(FileShape(seeded: seeded, entries: entries, removed: removed)) else { return }
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
        return Array(review.due(where: { inScope($0) && isActive($0) }).prefix(limit)).map(\.question)
    }

    /// Due in-scope questions of one subject (its booklet questions included), most overdue first.
    func reviewDueQuestions(subject: String, limit: Int = 50) -> [Question] {
        review.seedIfNeeded(from: data.wrong)
        return Array(review.due(where: { inScope($0) && QuestionBank.baseCourse($0.c) == subject }).prefix(limit)).map(\.question)
    }

    /// Due counts per subject (Catalog order; only subjects with questions due first, then the rest).
    func reviewDueBySubject() -> [(subject: String, count: Int)] {
        var counts: [String: Int] = [:]
        for e in review.due(where: { inScope($0) }) { counts[QuestionBank.baseCourse(e.question.c), default: 0] += 1 }
        return activeSubjects.map { ($0, counts[$0] ?? 0) }
    }

    /// Number of due in-scope questions (uncapped). Read-only: call seedReviewIfNeeded() outside view updates.
    var reviewDueCount: Int { review.due(where: { inScope($0) && isActive($0) }).count }

    func seedReviewIfNeeded() { review.seedIfNeeded(from: data.wrong) }
}

extension QuizSession {
    /// Per-question stat attribution for sessions that mix subjects/units (review, weak topics):
    /// nil = the session's own stat. Weak-topic answers go to the question's unit bucket so the
    /// ranking reacts to practice.
    static func perQuestionStat(_ kind: Kind, _ q: Question) -> (course: String, cat: String, sub: String)? {
        switch kind {
        case .review, .reviewSubject:
            return (q.c, "review", "Bu günün təkrarı")
        case .allQuestions, .unlearned, .oldExamQuestions, .hardQuestions:
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
