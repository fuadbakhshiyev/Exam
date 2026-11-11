import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// iPhone system search (Spotlight) over every question: subjects, Mixed, vize pdf exams, past final booklets.
/// Only bundled question content is indexed — never stats, wrong lists or bookmarks. The index is rebuilt in the
/// background only when the bundled question data changes (version key in UserDefaults). A tap on a result
/// arrives as a `CSSearchableItemActionType` user activity → `Route.question(id)` (ImtahanApp).
enum QuestionSpotlight {
    /// Domain of every question item (lets the whole set be replaced at once).
    nonisolated static let domain = "questions"
    private nonisolated static let versionKey = "spotlight_questions_version"
    /// Bump when the indexed fields / labels change.
    private nonisolated static let schema = 1

    /// One indexable question with its display labels.
    struct Entry: Sendable {
        /// Stable id: FNV-1a hash of the question text (same as sync's QuestionHash).
        let id: String
        let question: Question
        /// Subject name ("Mixed" questions → their subject).
        let subject: String
        /// "Unit 3" / "Mixed" / "İmtahan 2" / "2025-2026 Final".
        let source: String
    }

    // MARK: Enumeration

    /// Walks every unique question (by id) in a fixed order; return false from `body` to stop.
    nonisolated static func forEachEntry(_ bank: QuestionBank, _ body: (Entry) -> Bool) {
        var seen = Set<String>()
        func emit(_ q: Question, _ subject: String, _ source: String) -> Bool {
            let id = QuestionHash.hash(q.q)
            guard !q.q.isEmpty, seen.insert(id).inserted else { return true }
            return body(Entry(id: id, question: q, subject: subject, source: source))
        }
        for q in bank.all {
            let ok: Bool
            if q.c == Catalog.mixedKey {
                ok = emit(q, Catalog.subjects[studySafe: q.u - 1] ?? Catalog.mixedKey, "Mixed")
            } else {
                ok = emit(q, q.c, q.u >= 1 ? "Unit \(q.u)" : "Tez-tez düşən")
            }
            if !ok { return }
        }
        for s in bank.pdfSubjects {
            for (i, exam) in (bank.pdfExams[s] ?? []).enumerated() {
                for q in exam where !emit(q, s, "İmtahan \(i + 1)") { return }
            }
        }
        for s in bank.pdfFinalSubjects {
            for exam in bank.finals(subject: s) {
                let name = finalExamShortName(exam.name)
                for q in exam.questions where !emit(q, s, name) { return }
            }
        }
    }

    /// The question behind a Spotlight item id.
    nonisolated static func entry(id: String, bank: QuestionBank = .shared) -> Entry? {
        var found: Entry?
        forEachEntry(bank) { e in
            if e.id == id { found = e; return false }
            return true
        }
        return found
    }

    // MARK: Indexing

    /// Rebuilds the "questions" domain in the background when the bundled data changed. Call at launch.
    nonisolated static func indexIfNeeded() {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        Task.detached(priority: .utility) {
            let bank = QuestionBank.shared
            let version = dataVersion(bank)
            guard UserDefaults.standard.string(forKey: versionKey) != version else { return }
            do {
                try await rebuild(bank)
                UserDefaults.standard.set(version, forKey: versionKey)
            } catch {
                // Not saved → retried on the next launch.
            }
        }
    }

    /// Schema + sizes of the bundled JSON files + question counts.
    private nonisolated static func dataVersion(_ bank: QuestionBank) -> String {
        let sizes = ["questions", "pdf_exams", "pdf_finals"].map { name -> String in
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return "0" }
            return String(size)
        }
        let pdf = bank.pdfExams.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.count } }
        let finals = bank.pdfFinals.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.questions.count } }
        return "\(schema)-\(sizes.joined(separator: "."))-\(bank.all.count).\(pdf).\(finals)"
    }

    private nonisolated static func rebuild(_ bank: QuestionBank) async throws {
        let index = CSSearchableIndex.default()
        try await index.deleteSearchableItems(withDomainIdentifiers: [domain])
        var batch: [CSSearchableItem] = []
        var pending: [[CSSearchableItem]] = []
        forEachEntry(bank) { e in
            if let item = item(for: e) { batch.append(item) }
            if batch.count == 500 { pending.append(batch); batch = [] }
            return true
        }
        if !batch.isEmpty { pending.append(batch) }
        for chunk in pending {
            try Task.checkCancellation()
            try await index.indexSearchableItems(chunk)
        }
    }

    private nonisolated static func item(for e: Entry) -> CSSearchableItem? {
        let q = e.question
        let title = RichText.plain(q.q).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let options = q.o.map { RichText.plain($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let correct = options[studySafe: q.a] ?? ""

        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = title
        attrs.displayName = title
        attrs.contentDescription = (correct.isEmpty ? "" : "✓ \(correct)\n") + "\(e.subject) · \(e.source)"
        attrs.keywords = (options.filter { !$0.isEmpty && $0.count <= 120 } + [e.subject]).uniqued()
        let item = CSSearchableItem(uniqueIdentifier: e.id, domainIdentifier: domain, attributeSet: attrs)
        item.expirationDate = .distantFuture   // default is 30 days; we only re-index when the data changes
        return item
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Store helpers for the detail page

extension StudyStore {
    /// What "işlə" in the question page starts: the question's unit / Mixed part / pdf exam / final booklet.
    func studyTarget(for q: Question) -> (title: String, kind: QuizSession.Kind)? {
        if let f = QuestionBank.parseFinalKey(q.c) {
            return ("Bu imtahanı işlə", .finalExam(subject: f.subject, id: f.id))
        }
        if let r = q.c.range(of: "_pdf_", options: .backwards), let idx = Int(q.c[r.upperBound...]) {
            return ("Bu imtahanı işlə", .pdfExam(subject: String(q.c[..<r.lowerBound]), index: idx))
        }
        if q.c == Catalog.mixedKey {
            guard let i = scopedMixedParts.firstIndex(where: { $0.questions.contains { $0.q == q.q } }) else { return nil }
            return ("Bu hissəni işlə", .unit(course: Catalog.mixedKey, index: i))
        }
        guard q.u >= 1, Catalog.unitCounts[q.c] != nil else { return nil }
        return ("Bu ünitəni işlə", .unit(course: q.c, index: q.u - 1))
    }
}
