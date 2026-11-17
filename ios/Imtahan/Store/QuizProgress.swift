import Foundation

// Tests left half-way: the question order, option order, answers and position are kept per test
// (device-local, Application Support/Imtahan/quiz_progress.json) so starting the same test again can
// offer "Davam et" or "Yenidən başla". Answers were already recorded in the statistics when given, so
// resuming only restores the screen state. A finished test (result shown) or "Yenidən başla" removes it.

struct QuizProgress: Codable, Hashable, Sendable {
    var title: String
    var questions: [Question]
    /// Displayed option order of each question (original indices).
    var optionOrders: [[Int]]
    var answers: [Int: QuizSession.Answer]
    var index: Int
    var correct: Int
    var wrong: Int
    var savedAt: Date
    /// The test itself (QuizSession.Kind.wire), so Ana səhifə can reopen it. nil in older files.
    var kind: [String]? = nil
    /// Stat key of the test (subject / pdf key) and the subtitle shown in the quiz.
    var course: String? = nil
    var label: String? = nil
    /// "Testin sonunda" tests: the options picked so far (nothing is recorded before Bitir).
    var picks: [Int: Int]? = nil
    var revealAtEnd: Bool? = nil

    var answeredCount: Int { answers.count + (picks?.count ?? 0) }
    var total: Int { questions.count }
    /// Not finished yet (a "Testin sonunda" test may have every option picked but no result).
    var isOpen: Bool { answeredCount > 0 && answers.count < total }
}

/// Half-done tests on the wire: the newest few, plus the ones finished or dropped (key → when).
struct ProgressSync: Codable, Equatable, Sendable {
    var items: [String: QuizProgress] = [:]
    var removed: [String: Double] = [:]

    var isEmpty: Bool { items.isEmpty && removed.isEmpty }

    static func merge(_ a: ProgressSync, _ b: ProgressSync) -> ProgressSync {
        var out = ProgressSync()
        for k in Set(a.items.keys).union(b.items.keys).union(a.removed.keys).union(b.removed.keys) {
            let item = [a.items[k], b.items[k]].compactMap { $0 }.max { $0.savedAt < $1.savedAt }
            let gone = [a.removed[k], b.removed[k]].compactMap { $0 }.max()
            if let gone, gone >= (item?.savedAt.timeIntervalSince1970 ?? 0) * 1000 { out.removed[k] = gone }
            else if let item { out.items[k] = item }
        }
        return out
    }
}

@MainActor
@Observable
final class QuizProgressStore {
    static let shared = QuizProgressStore()
    /// Keep the most recent ones only.
    private static let limit = 40

    private(set) var items: [String: QuizProgress] = [:]
    @ObservationIgnored private let fileURL: URL

    private init() {
        fileURL = StudyStore.defaultFileURL().deletingLastPathComponent().appendingPathComponent("quiz_progress.json")
        if let raw = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([String: QuizProgress].self, from: raw) {
            items = saved
        }
    }

    func progress(_ key: String) -> QuizProgress? { items[key] }

    func save(_ p: QuizProgress, for key: String) {
        items[key] = p
        if items.count > Self.limit {
            for (k, _) in items.sorted(by: { $0.value.savedAt < $1.value.savedAt }).prefix(items.count - Self.limit) {
                items[k] = nil
            }
        }
        write()
    }

    func remove(_ key: String) {
        guard items.removeValue(forKey: key) != nil else { return }
        removed[key] = Date().timeIntervalSince1970 * 1000
        write()
        StudyStore.shared.onLocalChange?(true)
    }

    /// "Statistikanı sıfırla".
    func clear() {
        let t = Date().timeIntervalSince1970 * 1000
        for k in items.keys { removed[k] = t }
        items = [:]
        write()
    }

    struct OpenTest: Identifiable {
        var id: String { key }
        let key: String
        let progress: QuizProgress
        let kind: QuizSession.Kind
    }

    /// Half-done tests of this exam mode that can be reopened, newest first.
    func openTests(mode: ExamMode) -> [OpenTest] {
        items.filter { $0.key.hasPrefix(mode.rawValue + "|") && $0.value.isOpen }
            .sorted { $0.value.savedAt > $1.value.savedAt }
            .compactMap { k, p in Self.kind(of: p, key: k).map { OpenTest(key: k, progress: p, kind: $0) } }
    }

    /// The saved kind, or (files from before it was saved) the kind read back from the key.
    static func kind(of p: QuizProgress, key: String) -> QuizSession.Kind? {
        if let w = p.kind, let k = QuizSession.Kind(wire: w) { return k }
        return QuizSession.Kind(legacyKey: key)
    }

    // MARK: Sync (Sync/ExtrasSync.swift)

    /// Finished / dropped tests (key → ms), so another device does not offer them again.
    private var removed: [String: Double] {
        get { (UserDefaults.standard.dictionary(forKey: Self.removedKey) as? [String: Double]) ?? [:] }
        set {
            let cutoff = (Date().timeIntervalSince1970 - 30 * 86_400) * 1000
            UserDefaults.standard.set(newValue.filter { $0.value > cutoff }, forKey: Self.removedKey)
        }
    }
    private static let removedKey = "quiz_progress_removed"
    /// Only the newest few travel (each one carries its questions).
    private static let syncLimit = 6

    var syncValue: ProgressSync {
        let newest = items.filter { Self.kind(of: $0.value, key: $0.key) != nil }.sorted { $0.value.savedAt > $1.value.savedAt }.prefix(Self.syncLimit)
        return ProgressSync(items: Dictionary(uniqueKeysWithValues: newest.map { ($0.key, $0.value) }), removed: removed)
    }

    func merge(_ remote: ProgressSync) {
        var changed = false
        for (k, p) in remote.items where (items[k]?.savedAt ?? .distantPast) < p.savedAt
            && (removed[k] ?? 0) < p.savedAt.timeIntervalSince1970 * 1000 {
            items[k] = p
            changed = true
        }
        var gone = removed
        for (k, t) in remote.removed {
            if let p = items[k], p.savedAt.timeIntervalSince1970 * 1000 <= t { items[k] = nil; changed = true }
            if (gone[k] ?? 0) < t { gone[k] = t }
        }
        removed = gone
        if changed { write() }
    }

    private func write() {
        guard let raw = try? JSONEncoder().encode(items) else { return }
        let url = fileURL
        Task.detached(priority: .utility) { try? raw.write(to: url, options: .atomic) }
    }
}

extension QuizSession {
    /// Identity of a test for resuming (nil = never resumed: simulation has its own exam state,
    /// "Səhvlərin təkrarı" after a result is a one-off). Includes the exam mode: Vize/Final sets differ.
    static func progressKey(for kind: Kind, mode: ExamMode) -> String? {
        switch kind {
        case .simulation, .reviewMissed: nil
        case .unit(let c, let i): "\(mode.rawValue)|unit|\(c)|\(i)"
        case .mixedPart(let i): "\(mode.rawValue)|unit|\(Catalog.mixedKey)|\(i)"
        default: "\(mode.rawValue)|\(String(describing: kind))"
        }
    }

    /// Key of what is on screen now (a unit session may have switched unit with the picker).
    var progressKey: String? {
        isUnitSession ? "\(examMode.rawValue)|unit|\(course)|\(selectionIndex)" : Self.progressKey(for: kind, mode: examMode)
    }

    var progressSnapshot: QuizProgress {
        QuizProgress(title: title, questions: items.map(\.question),
                     optionOrders: items.map { $0.options.map(\.originalIndex) },
                     answers: answers, index: index, correct: correctCount, wrong: wrongCount, savedAt: Date(),
                     kind: resumeKind.wire, course: course, label: courseLabel,
                     picks: picks.isEmpty ? nil : picks, revealAtEnd: revealAtEnd ? true : nil)
    }

    /// What reopens the test on screen (a unit session may have switched unit with the picker).
    private var resumeKind: Kind {
        isUnitSession ? .unit(course: course, index: selectionIndex) : kind
    }

    /// Stores the half-done test (nothing when unanswered or finished).
    func saveProgress() {
        guard let key = progressKey else { return }
        guard result == nil, !answers.isEmpty || !picks.isEmpty, answers.count < items.count else {
            if result != nil || answers.count >= items.count { QuizProgressStore.shared.remove(key) }
            return
        }
        QuizProgressStore.shared.save(progressSnapshot, for: key)
        StudyStore.shared.onLocalChange?(false)
    }

    func clearProgress() {
        if let key = progressKey { QuizProgressStore.shared.remove(key) }
    }

    /// Rebuilt items for a saved order.
    static func items(from p: QuizProgress) -> [Item] {
        p.questions.enumerated().map { i, q in
            let order = p.optionOrders[studySafe: i] ?? Array(q.o.indices)
            return Item(id: i, question: q, options: order.compactMap { o in
                q.o.indices.contains(o) ? Option(text: q.o[o], originalIndex: o) : nil
            })
        }
    }
}

extension QuizSession.Kind {
    /// Plain tokens for saving a test's identity (nil: the simulation and one-off reviews are never resumed).
    var wire: [String]? {
        switch self {
        case .unit(let c, let i): ["unit", c, String(i)]
        case .mixedPart(let i): ["mixedPart", String(i)]
        case .multi(let c): ["multi"] + (c.map { [$0] } ?? [])
        case .courseWrong(let c): ["courseWrong", c]
        case .courseMixed(let c): ["courseMixed", c]
        case .mock: ["mock"]
        case .hard: ["hard"]
        case .pdfExam(let s, let i): ["pdfExam", s, String(i)]
        case .pdfExamWrong(let s, let i): ["pdfExamWrong", s, String(i)]
        case .pdfSubjectAllWrong(let s): ["pdfSubjectAllWrong", s]
        case .pdfFrequent(let s): ["pdfFrequent", s]
        case .finalExam(let s, let id): ["finalExam", s, String(id)]
        case .finalExamWrong(let s, let id): ["finalExamWrong", s, String(id)]
        case .finalSubjectAllWrong(let s): ["finalSubjectAllWrong", s]
        case .mixedOnly(let s): ["mixedOnly", s]
        case .conflicts: ["conflicts"]
        case .reviewCourse(let c, let ok): ["reviewCourse", c, ok ? "1" : "0"]
        case .reviewAll(let ok): ["reviewAll", ok ? "1" : "0"]
        case .bookmarks: ["bookmarks"]
        case .answerSearch(let q): ["answerSearch", q]
        case .textSearch(let q): ["textSearch", q]
        case .search(let q, let scope): ["search", q, scope.rawValue]
        case .wrongFor(let s): ["wrongFor", s]
        case .review: ["review"]
        case .reviewSubject(let s): ["reviewSubject", s]
        case .weakTopics: ["weakTopics"]
        case .allQuestions(let s): ["allQuestions", s]
        case .unlearned(let s): ["unlearned", s]
        case .oldExamQuestions(let s, let t): ["oldExamQuestions", s, t ?? ""]
        case .reviewMissed, .simulation: nil
        }
    }

    init?(wire w: [String]) {
        guard let head = w.first else { return nil }
        func s(_ i: Int) -> String? { w.indices.contains(i) ? w[i] : nil }
        func n(_ i: Int) -> Int? { s(i).flatMap(Int.init) }
        switch head {
        case "unit": guard let c = s(1), let i = n(2) else { return nil }; self = .unit(course: c, index: i)
        case "mixedPart": guard let i = n(1) else { return nil }; self = .mixedPart(i)
        case "multi": self = .multi(course: s(1))
        case "courseWrong": guard let c = s(1) else { return nil }; self = .courseWrong(c)
        case "courseMixed": guard let c = s(1) else { return nil }; self = .courseMixed(c)
        case "mock": self = .mock
        case "hard": self = .hard
        case "pdfExam": guard let c = s(1), let i = n(2) else { return nil }; self = .pdfExam(subject: c, index: i)
        case "pdfExamWrong": guard let c = s(1), let i = n(2) else { return nil }; self = .pdfExamWrong(subject: c, index: i)
        case "pdfSubjectAllWrong": guard let c = s(1) else { return nil }; self = .pdfSubjectAllWrong(c)
        case "pdfFrequent": guard let c = s(1) else { return nil }; self = .pdfFrequent(c)
        case "finalExam": guard let c = s(1), let i = n(2) else { return nil }; self = .finalExam(subject: c, id: i)
        case "finalExamWrong": guard let c = s(1), let i = n(2) else { return nil }; self = .finalExamWrong(subject: c, id: i)
        case "finalSubjectAllWrong": guard let c = s(1) else { return nil }; self = .finalSubjectAllWrong(c)
        case "mixedOnly": guard let c = s(1) else { return nil }; self = .mixedOnly(c)
        case "conflicts": self = .conflicts
        case "reviewCourse": guard let c = s(1) else { return nil }; self = .reviewCourse(course: c, correct: s(2) == "1")
        case "reviewAll": self = .reviewAll(correct: s(1) == "1")
        case "bookmarks": self = .bookmarks
        case "answerSearch": guard let q = s(1) else { return nil }; self = .answerSearch(q)
        case "textSearch": guard let q = s(1) else { return nil }; self = .textSearch(q)
        case "search": guard let q = s(1), let sc = s(2).flatMap(SearchScope.init(rawValue:)) else { return nil }; self = .search(q, sc)
        case "wrongFor": guard let c = s(1) else { return nil }; self = .wrongFor(c)
        case "review": self = .review
        case "reviewSubject": guard let c = s(1) else { return nil }; self = .reviewSubject(c)
        case "weakTopics": self = .weakTopics
        case "allQuestions": guard let c = s(1) else { return nil }; self = .allQuestions(c)
        case "unlearned": guard let c = s(1) else { return nil }; self = .unlearned(c)
        case "oldExamQuestions":
            guard let c = s(1) else { return nil }
            let t = s(2) ?? ""
            self = .oldExamQuestions(c, topic: t.isEmpty ? nil : t)
        default: return nil
        }
    }
}

extension QuizSession.Kind {
    /// A progress key written before the kind was saved: "vize|unit|<course>|<i>" or
    /// "vize|" + String(describing: kind), e.g. `unlearned("Reklam Grafiği")`, `pdfExam(subject: "X", index: 2)`.
    init?(legacyKey key: String) {
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let body = parts[1]
        if body.hasPrefix("unit|") {
            let u = body.split(separator: "|").map(String.init)
            guard u.count >= 3 else { return nil }
            self.init(wire: ["unit", u[1...(u.count - 2)].joined(separator: "|"), u[u.count - 1]])
            return
        }
        guard let open = body.firstIndex(of: "("), body.hasSuffix(")") else {
            self.init(wire: [body])
            return
        }
        let name = String(body[..<open])
        let inner = body[body.index(after: open)..<body.index(before: body.endIndex)]
        // Split on top-level commas, outside quotes.
        var args: [String] = [], cur = "", quoted = false, escaped = false, depth = 0
        for ch in inner {
            if escaped { cur.append(ch); escaped = false; continue }
            if ch == "\\" && quoted { cur.append(ch); escaped = true; continue }
            if ch == "\"" { quoted.toggle() }
            if !quoted && ch == "(" { depth += 1 }
            if !quoted && ch == ")" { depth -= 1 }
            if ch == "," && !quoted && depth == 0 { args.append(cur); cur = ""; continue }
            cur.append(ch)
        }
        if !cur.isEmpty { args.append(cur) }
        var tokens: [String] = []
        for raw in args {
            var v = raw.trimmingCharacters(in: .whitespaces)
            // "label: value"
            if !v.hasPrefix("\""), let colon = v.range(of: ": ") { v = String(v[colon.upperBound...]) }
            if v == "nil" { continue }
            if v.hasPrefix("Optional("), v.hasSuffix(")") { v = String(v.dropFirst(9).dropLast()) }
            if v.hasPrefix("\""), v.hasSuffix("\""), v.count >= 2 {
                v = String(v.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            } else if v == "true" { v = "1" } else if v == "false" { v = "0" }
            else if v.contains(".") && Int(v) == nil { v = String(v.split(separator: ".").last ?? "") }
            tokens.append(v)
        }
        self.init(wire: [name] + tokens)
    }
}
