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

    var answeredCount: Int { answers.count }
    var total: Int { questions.count }
}

@MainActor
final class QuizProgressStore {
    static let shared = QuizProgressStore()
    /// Keep the most recent ones only.
    private static let limit = 40

    private(set) var items: [String: QuizProgress] = [:]
    private let fileURL: URL

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
        write()
    }

    /// "Statistikanı sıfırla".
    func clear() {
        items = [:]
        write()
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
                     answers: answers, index: index, correct: correctCount, wrong: wrongCount, savedAt: Date())
    }

    /// Stores the half-done test (nothing when unanswered or finished).
    func saveProgress() {
        guard let key = progressKey else { return }
        guard result == nil, !answers.isEmpty, answers.count < items.count else {
            if result != nil || answers.count >= items.count { QuizProgressStore.shared.remove(key) }
            return
        }
        QuizProgressStore.shared.save(progressSnapshot, for: key)
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
