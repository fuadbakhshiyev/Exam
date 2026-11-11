import Foundation
import Observation

// "Real imtahan simulyasiyası": an ATA AÖF style exam over several subjects. No feedback while answering,
// answers can be changed until the exam is handed in, a countdown auto-submits, and the answers are
// recorded (wrong/correct lists, wrongCounts, stats[subject].bd["simulation"]["Simulyasiya"]) only on submit.
// The session itself is a QuizSession of kind .simulation(config); this object holds the exam state.

/// Setup of one simulation (Kind.simulation payload).
struct SimulationConfig: Hashable, Sendable {
    enum Timing: Hashable, Sendable {
        /// ATA AÖF: 20 questions ≈ 30 minutes, i.e. 90 s per question.
        case standard
        case perSubject(minutes: Int)
        case total(minutes: Int)
    }

    var subjects: [String] = Catalog.subjects
    var questionsPerSubject = 20
    var timing: Timing = .standard
    /// Adds the vize PDF exams (and, in Final mode, the past final booklets) to the pool.
    var includePastExams = false

    static let secondsPerQuestion = 90
    static let questionChoices = [5, 10, 15, 20, 25, 30, 40]
    static let perSubjectMinuteChoices = [15, 30, 45, 60]
    static let totalMinuteChoices = [15, 30, 45, 60, 90, 120, 150, 180]

    /// Allowed time for an exam with `questionCount` questions over `subjectCount` subjects.
    func durationSeconds(questionCount: Int, subjectCount: Int) -> Int {
        switch timing {
        case .standard: return max(60, questionCount * Self.secondsPerQuestion)
        case .perSubject(let m): return m * 60 * max(1, subjectCount)
        case .total(let m): return m * 60
        }
    }
}

/// Outcome of a handed-in simulation.
struct SimulationResult: Hashable, Sendable {
    struct SubjectRow: Hashable, Sendable, Identifiable {
        var id: String { subject }
        let subject: String
        let correct: Int
        let wrong: Int
        let blank: Int
        var total: Int { correct + wrong + blank }
        /// ATA AÖF: 4 wrong answers cancel 1 correct one.
        var net: Double { Double(correct) - Double(wrong) / 4 }
        /// 0…100.
        var score: Double { total > 0 ? max(0, net / Double(total) * 100) : 0 }
    }

    enum Status: Hashable, Sendable { case correct, wrong, blank }

    struct ReviewItem: Hashable, Sendable, Identifiable {
        /// Position in the exam.
        let id: Int
        let subject: String
        /// 1-based number inside the subject.
        let number: Int
        let question: Question
        let status: Status
        let flagged: Bool
        /// "B · text" as displayed (shuffled letters); nil when blank.
        let chosenLine: String?
        let correctLine: String
    }

    let subjects: [SubjectRow]
    let review: [ReviewItem]
    let elapsedSeconds: Int
    let allowedSeconds: Int
    let autoSubmitted: Bool

    var correct: Int { subjects.reduce(0) { $0 + $1.correct } }
    var wrong: Int { subjects.reduce(0) { $0 + $1.wrong } }
    var blank: Int { subjects.reduce(0) { $0 + $1.blank } }
    var total: Int { correct + wrong + blank }
    var net: Double { Double(correct) - Double(wrong) / 4 }
    /// Mean of the subject scores (each subject is graded on its own).
    var average: Double { subjects.isEmpty ? 0 : subjects.reduce(0) { $0 + $1.score } / Double(subjects.count) }
}

@MainActor
@Observable
final class ExamSimulation {
    /// QuizSession course / timer key (not a stats key: answers are recorded under their subjects).
    static let courseKey = "Simulyasiya"
    static let statCategory = "simulation"
    static let statSub = "Simulyasiya"

    let config: SimulationConfig
    let items: [QuizSession.Item]
    /// Subject of every item.
    let itemSubjects: [String]
    /// Subjects in exam order.
    let subjects: [String]
    let startDate: Date
    let deadline: Date
    var allowedSeconds: Int { Int(deadline.timeIntervalSince(startDate).rounded()) }

    /// Item index → chosen original option index.
    private(set) var selections: [Int: Int] = [:]
    private(set) var flagged: Set<Int> = []
    private(set) var now: Date
    private(set) var result: SimulationResult?

    @ObservationIgnored private let store: StudyStore
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    init(config: SimulationConfig, items: [QuizSession.Item], store: StudyStore) {
        self.config = config
        self.items = items
        self.store = store
        itemSubjects = items.map { Self.subject(of: $0.question) }
        var seen = Set<String>()
        subjects = itemSubjects.filter { seen.insert($0).inserted }
        let start = Date()
        startDate = start
        now = start
        deadline = start.addingTimeInterval(TimeInterval(config.durationSeconds(questionCount: items.count, subjectCount: seen.count)))
        startTicking()
    }

    /// Subject of a pool question: Mixed → its subject (u = index + 1), pdf / final keys → their subject.
    nonisolated static func subject(of q: Question) -> String {
        if q.c == Catalog.mixedKey { return Catalog.subjects[studySafe: q.u - 1] ?? q.c }
        return QuestionBank.baseCourse(q.c)
    }

    /// Short subject label for pills and tables.
    nonisolated static func shortName(_ s: String) -> String {
        switch s {
        case "Grafik Üretim Teknikleri": "Grafik Üretim"
        case "Özgün Baskı Teknikleri": "Özgün Baskı"
        case "Web Tasarımının Temelleri": "Web Tasarımı"
        default: s
        }
    }

    // MARK: Timer

    var remainingSeconds: Int { max(0, Int(deadline.timeIntervalSince(now).rounded(.up))) }
    var elapsedSeconds: Int { min(allowedSeconds, max(0, Int(now.timeIntervalSince(startDate)))) }
    var isLowTime: Bool { remainingSeconds <= 5 * 60 }

    /// "1:05:09" / "24:30".
    nonisolated static func clock(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    private func startTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard result == nil else { stop(); return }
        let d = Date()
        // Only publish whole-second changes (the clock shows seconds).
        if Int(d.timeIntervalSince(startDate)) != Int(now.timeIntervalSince(startDate)) { now = d }
        // An exam is study time: keep the platform timer from going idle while thinking.
        store.noteActivity()
        if d >= deadline { now = d; submit(auto: true) }
    }

    /// Stops the countdown (leaving or after submitting).
    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    // MARK: Answering

    var answeredCount: Int { selections.count }
    var unansweredCount: Int { items.count - selections.count }

    /// Selects an option; tapping the selected option again clears the answer.
    func select(item i: Int, originalIndex: Int) {
        guard result == nil, items.indices.contains(i) else { return }
        store.noteActivity()
        selections[i] = selections[i] == originalIndex ? nil : originalIndex
    }

    func toggleFlag(_ i: Int) {
        guard result == nil, items.indices.contains(i) else { return }
        if flagged.contains(i) { flagged.remove(i) } else { flagged.insert(i) }
    }

    /// Index range of a subject's questions.
    func indices(of subject: String) -> [Int] { itemSubjects.indices.filter { itemSubjects[$0] == subject } }

    /// 1-based number of item i inside its subject.
    func number(of i: Int) -> Int {
        guard itemSubjects.indices.contains(i) else { return i + 1 }
        let s = itemSubjects[i]
        return itemSubjects[..<i].filter { $0 == s }.count + 1
    }

    func answered(in subject: String) -> Int { indices(of: subject).filter { selections[$0] != nil }.count }

    // MARK: Submit

    /// Hands the exam in: records every answer once and builds the result. Idempotent.
    @discardableResult
    func submit(auto: Bool = false) -> SimulationResult {
        if let result { return result }
        stop()
        let elapsed = min(allowedSeconds, max(0, Int(Date().timeIntervalSince(startDate))))
        var rows: [String: (c: Int, w: Int, b: Int)] = [:]
        var review: [SimulationResult.ReviewItem] = []
        var counters: [String: Int] = [:]
        store.batch {
            for (i, item) in items.enumerated() {
                let q = item.question
                let subj = itemSubjects[i]
                counters[subj, default: 0] += 1
                let status: SimulationResult.Status
                if let chosen = selections[i] {
                    let ok = chosen == q.a
                    status = ok ? .correct : .wrong
                    _ = store.recordQuizAnswer(q, isCorrect: ok, removeFromWrongWhenCorrect: false,
                                               stat: (subj, Self.statCategory, Self.statSub))
                } else {
                    status = .blank
                }
                var r = rows[subj] ?? (0, 0, 0)
                switch status {
                case .correct: r.c += 1
                case .wrong: r.w += 1
                case .blank: r.b += 1
                }
                rows[subj] = r
                review.append(.init(id: i, subject: subj, number: counters[subj] ?? 1, question: q, status: status,
                                    flagged: flagged.contains(i), chosenLine: selections[i].flatMap { line(item, $0) },
                                    correctLine: line(item, q.a) ?? ""))
            }
        }
        let r = SimulationResult(
            subjects: subjects.map { s in
                let v = rows[s] ?? (0, 0, 0)
                return .init(subject: s, correct: v.c, wrong: v.w, blank: v.b)
            },
            review: review, elapsedSeconds: elapsed, allowedSeconds: allowedSeconds, autoSubmitted: auto)
        result = r
        store.noteSimulationFinished(average: r.average)   // Nailiyyətlər
        return r
    }

    /// "B · text" of an original option index with its displayed letter.
    private func line(_ item: QuizSession.Item, _ original: Int) -> String? {
        guard let pos = item.options.firstIndex(where: { $0.originalIndex == original }) else { return nil }
        return "\(QuizSession.letters[studySafe: pos] ?? "?") · \(item.options[pos].text)"
    }
}

extension StudyStore {
    /// In-scope question pool of one subject: its own units, the Mixed-only questions and, optionally,
    /// the vize PDF exams and (Final mode) the past final booklets. Deduplicated by question text.
    func simulationPool(subject: String, includePastExams: Bool) -> [Question] {
        var seen = Set<String>()
        var out: [Question] = []
        func add(_ qs: [Question]) {
            for q in qs where q.a >= 0 && q.a < q.o.count && seen.insert(Self.cleanText(q.q)).inserted { out.append(q) }
        }
        add(scopedQuestions(course: subject))
        add(getMixedOnlyQuestions(subject))
        if includePastExams {
            for i in bank.exams(subject: subject).indices { add(pdfExamQuestions(subject, i)) }
            if examMode == .final { for e in bank.finals(subject: subject) { add(e.questions) } }
        }
        return out
    }

    /// The exam: `questionsPerSubject` random questions of each chosen subject, subject by subject.
    func simulationQuestions(_ config: SimulationConfig) -> [Question] {
        Catalog.subjects.filter { config.subjects.contains($0) }.flatMap {
            Array(simulationPool(subject: $0, includePastExams: config.includePastExams).shuffled().prefix(config.questionsPerSubject))
        }
    }
}
