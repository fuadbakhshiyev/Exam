import Foundation
import Observation

// A running test: port of startUnit / loadContent / startSpecial (+ the start* wrappers) / renderQ /
// checkAnswer / nav / hint / flashcard / finishTest / reviewMissed from quiz.js.

struct QuizStartError: LocalizedError, Equatable {
    /// The web app's alert() text.
    let message: String
    var errorDescription: String? { message }
}

@MainActor
@Observable
final class QuizSession: Identifiable {
    enum Kind: Hashable {
        case unit(course: String, index: Int)           // startUnit (course "Mixed" → 20-question part)
        case mixedPart(Int)                             // = unit(course: "Mixed", index:)
        case multi(course: String?)                     // startMultiUnit (nil / "all" / "Ümumi Toplam" = every wrong list)
        case courseWrong(String)                        // startCourseWrongExam
        case courseMixed(String)                        // startCourseMixedExam (20 random)
        case mock                                       // startMock
        case hard                                       // startHard
        case pdfExam(subject: String, index: Int)       // startPdfExam
        case pdfExamWrong(subject: String, index: Int)  // startPdfExamWrQs
        case pdfSubjectAllWrong(String)                 // startPdfSubjectAllWrQs
        case pdfFrequent(String)                        // startPdfSubjectFrequentQs
        case finalExam(subject: String, id: Int)        // past Final / Bütünləmə / Yaz Okulu booklet (sinavId)
        case finalExamWrong(subject: String, id: Int)   // its wrong answers
        case finalSubjectAllWrong(String)               // wrong answers of every booklet of a subject
        case mixedOnly(String)                          // startMixedOnlyQs
        case conflicts                                  // startConflictingQuestionsQuiz
        case reviewCourse(course: String, correct: Bool) // reviewCourseAnswers
        case reviewAll(correct: Bool)                   // reviewAllAnswers
        case bookmarks                                  // showBookmarks
        case answerSearch(String)                       // "Test kimi işlə" of performAnswerSearch
        case textSearch(String)                         // handleSearch
        case search(String, SearchScope)                // unified search "Test kimi işlə"
        case wrongFor(String)                           // startWrongFor (Səhvlərim card)
        case reviewMissed(questions: [Question], course: String) // reviewMissed
        case simulation(SimulationConfig)               // "Real imtahan simulyasiyası" (Store/ExamSimulation.swift)
        case review                                     // "Bu günün təkrarı" (Leitner, StudyStore+Review.swift)
        case weakTopics                                 // "Zəif mövzular" (StudyStore+Plan.swift)
        case allQuestions(String)                       // "Bütün suallar" of a subject (StudyStore+AllQuestions.swift)
        case unlearned(String)                          // "Öyrənilməmişlər" of a subject (Store/LearningFeatures.swift)
    }

    struct Option: Hashable, Sendable {
        let text: String
        let originalIndex: Int
    }

    struct Item: Hashable, Sendable, Identifiable {
        let id: Int
        let question: Question
        /// Shuffled options; originalIndex is compared with question.a.
        let options: [Option]
    }

    struct Answer: Codable, Hashable, Sendable {
        /// Original option index, -1 for a hint.
        let chosen: Int
        let hint: Bool
    }

    /// q-meta badges: course + unit label.
    struct Meta: Hashable, Sendable {
        let course: String
        let unit: String?
        let accentHex: String
    }

    struct AnswerOutcome: Hashable, Sendable {
        let isCorrect: Bool
        /// The session moves on by itself 0.75 s after a correct answer.
        let willAutoAdvance: Bool
        let celebration: Celebration?
    }

    enum SegmentState: Hashable, Sendable { case none, done, wrong }

    struct MockSubjectResult: Hashable, Sendable, Identifiable {
        var id: String { subject }
        let subject: String
        let correct: Int    // D
        let wrong: Int      // Y
        let score: Double   // Bal (0…100), shown with 1 decimal
        var scoreText: String { String(format: "%.1f", score) }
    }

    struct MissedItem: Hashable, Sendable {
        let question: Question
        /// nil → "—" (hint).
        let chosenText: String?
        let correctText: String
    }

    struct Result: Hashable, Sendable {
        let correct: Int
        let wrong: Int
        let total: Int
        let net: Double            // c - w/4
        let score: Double          // max(0, net/total*100)
        let accuracy: Int          // round(c/total*100)
        let elapsed: String        // timer text at finish ("—" if empty)
        let isMock: Bool
        let mockSubjects: [MockSubjectResult]
        let averageMockScore: Double
        let confetti: Bool
        let missed: [MissedItem]
        var netText: String { String(format: "%.2f", net) }
        /// res-big colour: "active" ≥ 90, "finish" ≥ 50, else "wrong".
        var tone: String { score >= 90 ? "active" : (score >= 50 ? "finish" : "wrong") }
    }

    enum FinishRequest: Hashable, Sendable {
        /// "Sınaq yarımçıqdır (Cavablandırılıb: a/t). Bitirməkdən əminsiniz?" → call finish() if confirmed.
        case needsConfirmation(String)
        case finished(Result)
    }

    /// Where closing the result goes (window.closeModal redirect).
    enum Exit: Hashable, Sendable {
        case overall
        case course(String)
        case home
    }

    // MARK: State

    nonisolated let id = UUID()
    let kind: Kind
    /// Header title (title-unit).
    private(set) var title: String
    /// Small course label (course-name-sm) with a "_pdf_N" suffix removed.
    private(set) var courseLabel: String
    /// state.course (stat attribution, wrong lists of Multi etc.).
    private(set) var course: String
    private(set) var category: String
    private(set) var currentTitle: String
    private(set) var selectionIndex: Int
    let isMockMode: Bool
    let isWrongMode: Bool
    let isMixedMode: Bool
    let isSearchMode: Bool
    /// Subject of pdf sessions (state.activePdfSubject).
    let pdfSubject: String?
    /// Exam mode at start: unit lists, Mixed parts and their stat keys stay consistent for the whole session.
    let examMode: ExamMode

    private(set) var items: [Item] = []
    var index: Int = 0 { didSet { if index != oldValue { cancelAutoAdvance(); flashcardRevealed = false } } }
    private(set) var answers: [Int: Answer] = [:]
    private(set) var correctCount = 0
    private(set) var wrongCount = 0
    var isFlashcard = false
    private(set) var flashcardRevealed = false
    var pagerOpen = false
    private(set) var result: Result?
    /// Exam state of a .simulation session (no feedback, changeable answers, countdown); nil otherwise.
    private(set) var simulation: ExamSimulation?
    /// Set when an auto-advance reached the end with unanswered questions; show the confirm, then finish().
    var pendingFinishConfirmation: String?
    private(set) var isClosed = false

    @ObservationIgnored private let store: StudyStore
    @ObservationIgnored private let bank: QuestionBank
    @ObservationIgnored private var autoAdvanceTask: Task<Void, Never>?
    @ObservationIgnored private var lastMissed: [Question] = []
    @ObservationIgnored private var lastMissedCourse: String = ""

    /// Starts the session (and its timer). Throws the web's alert text when there is nothing to ask.
    init(_ kind: Kind, store: StudyStore, bank: QuestionBank = .shared, restore: QuizProgress? = nil) throws {
        self.kind = kind
        self.store = store
        self.bank = bank
        examMode = store.examMode
        let p = try Self.plan(kind, store: store, bank: bank)
        title = p.title
        courseLabel = Self.stripPdfSuffix(p.label)
        course = p.course
        category = p.category
        currentTitle = p.currentTitle
        selectionIndex = p.selectionIndex
        pdfSubject = p.pdfSubject
        if p.isUnit {
            isMockMode = false; isWrongMode = false; isMixedMode = false; isSearchMode = false
        } else {
            let f = Self.flags(forTitle: p.title)
            isMockMode = p.isMock; isWrongMode = f.isWrong; isMixedMode = f.isMixed; isSearchMode = f.isSearch
        }
        if p.isUnit {
            loadUnit(p.selectionIndex)
        } else {
            items = Self.makeItems(p.questions)
        }
        if let r = restore, !r.questions.isEmpty {
            items = Self.items(from: r)
            answers = r.answers
            correctCount = r.correct
            wrongCount = r.wrong
            index = min(max(0, r.index), items.count - 1)
        }
        if case .simulation(let cfg) = kind { simulation = ExamSimulation(config: cfg, items: items, store: store) }
        store.startQuizTimer(course: p.timerCourse)
        store.quizTimerOwner = id
    }

    /// True while this session owns the quiz timer (a newer session takes it over).
    private var ownsTimer: Bool { store.quizTimerOwner == id && store.activeCourse != nil }

    // MARK: Plans (the start* functions)

    private struct Plan {
        var title: String
        var label: String
        var questions: [Question] = []
        var isMock = false
        var course: String
        var category: String
        var currentTitle: String
        var selectionIndex = 0
        var timerCourse: String
        var isUnit = false
        var pdfSubject: String?
    }

    private static func plan(_ kind: Kind, store: StudyStore, bank: QuestionBank) throws -> Plan {
        func fail(_ m: String) -> QuizStartError { QuizStartError(message: m) }
        func special(_ qs: [Question], _ t: String, _ s: String, category: String = "review", currentTitle: String? = nil) -> Plan {
            Plan(title: t, label: s, questions: qs, course: s, category: category, currentTitle: currentTitle ?? t, timerCourse: s)
        }
        switch kind {
        case .unit(let c, let idx):
            if c == Catalog.mixedKey {
                guard store.scopedMixedParts.indices.contains(idx) else { throw fail("Bu hissə tapılmadı.") }
            } else if Catalog.unitCounts[c] != nil && !store.inScope(unit: idx + 1) {
                throw fail("Unit \(idx + 1) \(store.examMode.title) rejiminə daxil deyil (\(store.examMode.explanation.lowercased())). Rejimi Ayarlarda dəyişə bilərsiniz.")
            }
            return Plan(title: "", label: c, course: c, category: "units", currentTitle: "", selectionIndex: idx, timerCourse: c, isUnit: true)
        case .mixedPart(let idx):
            return try plan(.unit(course: Catalog.mixedKey, index: idx), store: store, bank: bank)
        case .multi(let c):
            let all = c == nil || c == "all" || c == Catalog.overallKey
            let name = all ? Catalog.overallKey : c!
            let arr = all ? store.allWrongQuestions() : store.scopedWrong(name)
            guard !arr.isEmpty else { throw fail("Multi bölməsi boşdur! Heç bir səhv cavablandırdığınız sual yoxdur. Əla!") }
            return special(arr, "Multi: Səhvlərin Təkrarı", name, category: "units", currentTitle: "Multi")
        case .courseWrong(let c):
            let arr = store.scopedWrong(c)
            guard !arr.isEmpty else { throw fail("Səhv cavablandırdığınız sual yoxdur.") }
            return special(arr, "Səhvlərin Təkrarı: " + c, c)
        case .courseMixed(let c):
            let qs = store.courseMixedPool(c)
            guard !qs.isEmpty else { throw fail("Bu fənn üzrə sual tapılmadı.") }
            return special(qs, "Qarışıq Sınaq: " + c, c)
        case .mock:
            var p = special(store.mockPool(), Catalog.mockKey, "Real Sınaq Rejimi", category: "mock")
            p.isMock = true
            p.course = Catalog.mockKey
            p.timerCourse = Catalog.mockKey
            return p
        case .hard:
            let pool = store.hardPool()
            guard !pool.isEmpty else { throw fail("Səhv yoxdur!") }
            var p = special(pool, "💀 Ən Çətinlər", "Səhvlər Təkrarı")
            p.course = "Hard"
            return p
        case .pdfExam(let subject, let idx):
            let qs = store.pdfExamQuestions(subject, idx)
            guard !qs.isEmpty else { throw fail("Bu imtahanda sual tapılmadı.") }
            let t = "İmtahan \(idx + 1)"
            var p = special(qs, t, StudyStore.pdfKey(subject, idx), category: "pdf-exam")
            p.selectionIndex = idx; p.pdfSubject = subject
            return p
        case .pdfExamWrong(let subject, let idx):
            let qs = store.pdfExamWrong(subject, idx)
            guard !qs.isEmpty else { throw fail("Bu imtahandan səhv cavablandırdığınız sual yoxdur!") }
            var p = special(qs, "İmtahan \(idx + 1) (Səhvlərin Təkrarı)", StudyStore.pdfKey(subject, idx), category: "pdf-exam")
            p.selectionIndex = idx; p.pdfSubject = subject
            return p
        case .pdfSubjectAllWrong(let subject):
            let qs = store.pdfSubjectAllWrong(subject)
            guard !qs.isEmpty else { throw fail("Bu fənnin PDF sınaqlarından heç bir səhv cavablandırdığınız sual yoxdur!") }
            var p = special(qs, "PDF Səhvlərin Təkrarı (Multi)", subject, category: "pdf-exam")
            p.selectionIndex = -1; p.pdfSubject = subject
            return p
        case .pdfFrequent(let subject):
            let qs = store.getMostFrequentQuestions(subject).map { f -> Question in
                var q = f.question; q.c = subject; q.u = -2; return q
            }
            guard !qs.isEmpty else { throw fail("Bu fənnin PDF sınaqlarında təkrarlanan sual tapılmadı.") }
            var p = special(qs, "Ən çox düşən suallar", subject, category: "pdf-exam")
            p.selectionIndex = -2; p.pdfSubject = subject
            return p
        case .finalExam(let subject, let id):
            let qs = store.finalExamQuestions(subject, id)
            guard !qs.isEmpty, let exam = bank.finalExam(subject: subject, id: id) else { throw fail("Bu imtahanda sual tapılmadı.") }
            // Stats: stats["<subject>_final_<id>"].bd["final-exam"][full booklet name]
            var p = special(qs, exam.name, QuestionBank.finalKey(subject, id), category: StudyStore.finalCategory)
            p.selectionIndex = id; p.pdfSubject = subject
            return p
        case .finalExamWrong(let subject, let id):
            let qs = store.finalExamWrong(subject, id)
            guard !qs.isEmpty else { throw fail("Bu imtahandan səhv cavablandırdığınız sual yoxdur!") }
            let name = bank.finalExam(subject: subject, id: id).map { finalExamShortName($0.name) } ?? "Final"
            var p = special(qs, "\(name) (Səhvlərin Təkrarı)", QuestionBank.finalKey(subject, id), category: StudyStore.finalCategory)
            p.selectionIndex = id; p.pdfSubject = subject
            return p
        case .finalSubjectAllWrong(let subject):
            let qs = store.finalSubjectAllWrong(subject)
            guard !qs.isEmpty else { throw fail("Bu fənnin final imtahanlarından heç bir səhv cavablandırdığınız sual yoxdur!") }
            var p = special(qs, "Final Səhvlərin Təkrarı (Multi)", subject, category: StudyStore.finalCategory)
            p.selectionIndex = -1; p.pdfSubject = subject
            return p
        case .mixedOnly(let subject):
            let qs = store.getMixedOnlyQuestions(subject)
            guard !qs.isEmpty else { throw fail("Bu fənn üçün yalnız Mixed-də olan hər hansı bir fərqli sual tapılmadı.") }
            var p = special(qs, "Yalnız Mixed-də olan suallar", subject, category: "mixed-only")
            p.selectionIndex = -3; p.pdfSubject = subject
            return p
        case .conflicts:
            let qs = store.conflictQuizQuestions()
            guard !qs.isEmpty else { throw fail("Ziddiyyətli sual tapılmadı.") }
            var p = special(qs, "Ziddiyyətli Suallar", "Bütün Fənlər", category: "conflicting-quiz")
            p.selectionIndex = -4
            return p
        case .reviewCourse(let c, let correct):
            let arr = store.subjectReviewQuestions(c, correct: correct)
            guard !arr.isEmpty else {
                throw fail(correct ? "Doğru cavablandırdığınız sual hələ ki yoxdur və ya əvvəllər yaddaşda saxlanılmayıb." : "Əla! Səhv cavablandırdığınız sual yoxdur.")
            }
            return special(arr, correct ? "Doğrular" : "Səhvlər", c)
        case .reviewAll(let correct):
            let arr = correct ? store.allCorrectQuestions() : store.allWrongQuestions()
            guard !arr.isEmpty else { throw fail(correct ? "Doğru cavablandırdığınız sual hələ ki yoxdur." : "Əla! Səhv cavablandırdığınız sual yoxdur.") }
            return special(arr, correct ? "Ümumi Doğrular" : "Ümumi Səhvlər", "Bütün Fənlər")
        case .bookmarks:
            let marks = store.scopedMarks
            guard !marks.isEmpty else { throw fail("Boşdur") }
            return special(marks, "⭐ Seçilmişlər", "")
        case .answerSearch(let query):
            return try plan(.search(query, .answer), store: store, bank: bank)
        case .textSearch(let query):
            return try plan(.search(query, .all), store: store, bank: bank)
        case .search(let query, let scope):
            let res = store.search(query, scope: scope).map(\.question)
            guard !res.isEmpty else { throw fail("\"\(query)\" — \(scope.title.lowercased()) üzrə heç nə tapılmadı.") }
            return special(res, "Axtarış Nəticələri", "Axtarış: " + query)
        case .wrongFor(let key):
            let arr = store.scopedWrong(key)
            guard !arr.isEmpty else { throw fail("Əla! Səhv yoxdur.") }
            return special(arr, "Səhvlər", key)
        case .reviewMissed(let qs, let c):
            guard !qs.isEmpty else { throw fail("Səhv yoxdur!") }
            return special(qs, "Səhvlərin Təkrarı", c)
        case .simulation(let cfg):
            let qs = store.simulationQuestions(cfg)
            guard !qs.isEmpty else { throw fail("Seçilmiş fənlər üzrə sual tapılmadı.") }
            return special(qs, "İmtahan simulyasiyası", ExamSimulation.courseKey, category: ExamSimulation.statCategory)
        case .review:
            let qs = store.reviewDueQuestions()
            guard !qs.isEmpty else { throw fail("Bu gün təkrar ediləcək sual yoxdur ✓") }
            return special(qs, "Bu günün təkrarı", "Ağıllı təkrar")
        case .allQuestions(let subject):
            let qs = store.allSubjectQuestions(subject).shuffled()
            guard !qs.isEmpty else { throw fail("Bu fənn üçün sual tapılmadı.") }
            return special(qs, "Bütün suallar", subject, category: "all-questions")
        case .unlearned(let subject):
            let qs = store.unlearnedQuestions(subject).shuffled()
            guard !qs.isEmpty else { throw fail("Bu fənnin bütün sualları öyrənilib ✓") }
            return special(qs, "Öyrənilməmişlər", subject, category: "all-questions")
        case .weakTopics:
            let qs = store.weakTopicQuestions()
            guard !qs.isEmpty else { throw fail("Zəif mövzu tapılmadı: hər ünitədən ən azı 5 sual cavablandırın.") }
            return special(qs, "Zəif mövzular", "Zəif mövzular")
        }
    }

    /// startSpecial's flags from the title keywords.
    nonisolated static func flags(forTitle t: String) -> (isWrong: Bool, isMixed: Bool, isSearch: Bool) {
        let l = t.lowercased()
        let isWrong = ["sehv", "səhv", "cetin", "çətin", "wrong", "hard", "multi"].contains { l.contains($0) }
        let isMixed = ["qarisig", "qarışıq", "mixed"].contains { l.contains($0) }
        let isSearch = ["axtar", "search"].contains { l.contains($0) }
        return (isWrong, isMixed, isSearch)
    }

    nonisolated static func stripPdfSuffix(_ s: String) -> String {
        s.replacingOccurrences(of: "_(pdf|final)_\\d+$", with: "", options: .regularExpression)
    }

    private static func makeItems(_ qs: [Question]) -> [Item] {
        qs.enumerated().map { i, q in
            Item(id: i, question: q, options: q.o.enumerated().map { Option(text: $0.element, originalIndex: $0.offset) }.shuffled())
        }
    }

    // MARK: Units (renderTopNav / loadContent)

    var isUnitSession: Bool {
        if case .unit = kind { return true }
        if case .mixedPart = kind { return true }
        return false
    }

    /// Unit/part names of the course (the nav pills); empty for special sessions.
    var unitTitles: [String] { isUnitSession ? store.unitTitles(course, mode: examMode) : [] }

    /// Pill labels: "Unit N" for subjects, the part name for Mixed.
    var unitPillLabels: [String] {
        unitTitles.enumerated().map { course != Catalog.mixedKey ? "Unit \($0.offset + 1)" : $0.element }
    }

    /// loadContent(idx): switches to another unit of the same course and starts over.
    func loadUnit(_ idx: Int) {
        guard isUnitSession else { return }
        cancelAutoAdvance()
        saveProgress()   // switching unit with the picker keeps the old one resumable
        selectionIndex = idx
        index = 0
        answers = [:]; correctCount = 0; wrongCount = 0
        result = nil
        let names = store.unitTitles(course, mode: examMode)
        currentTitle = names[studySafe: idx] ?? ""
        title = currentTitle.isEmpty ? "Seçim Yoxdur" : currentTitle
        let qs: [Question]
        if currentTitle.isEmpty {
            qs = []
        } else if course == Catalog.mixedKey {
            qs = bank.mixedPartQuestions(idx, mode: examMode)
        } else {
            qs = bank.questions(course: course).filter { $0.u == idx + 1 }
        }
        items = Self.makeItems(qs.shuffled())
    }

    // MARK: Current question (renderQ)

    var total: Int { items.count }
    var current: Item? { items[studySafe: index] }
    var currentAnswer: Answer? { answers[index] }
    var isLast: Bool { index == items.count - 1 }
    var answeredCount: Int { answers.count }
    /// "3 / 20"
    var counterText: String { "\(index + 1) / \(total)" }
    var progress: Double { total > 0 ? Double(answeredCount) / Double(total) : 0 }
    /// Pager >40 questions: "N% Tamamlandı".
    var percentComplete: Int { total > 0 ? Int((Double(index) / Double(total) * 100).rounded()) : 0 }

    /// Progress segments (≤ 40 questions): done = answered right, wrong = wrong or hint.
    var segments: [SegmentState] {
        items.indices.map { i in
            guard let a = answers[i] else { return .none }
            return a.chosen == items[i].question.a ? .done : .wrong
        }
    }

    /// Timer is shown only in mock and pdf exam sessions.
    var showsTimer: Bool { isMockMode || isCourseMixed || course.contains("_pdf_") || QuestionBank.isFinalKey(course) }

    /// Graded sessions: points so far (100 over all questions, 4 wrong cancel 1 correct).
    var liveScore: Double {
        guard !items.isEmpty else { return 0 }
        return max(0, (Double(correctCount) - Double(wrongCount) / 4) / Double(items.count) * 100)
    }
    var timerText: String { store.quizTimerText }

    /// Shows the course/unit badges above the question.
    var showsMeta: Bool {
        if isSubjectPool || isCourseMixed { return true }
        return isMockMode || isWrongMode || isSearchMode || category == "mixed" || category == "exams" || currentTitle == "Multi" || course == Catalog.mixedKey
    }

    func meta(for q: Question) -> Meta {
        if q.c == Catalog.mixedKey {
            let subj = Catalog.subjects[studySafe: q.u - 1] ?? Catalog.mixedKey
            return Meta(course: subj, unit: currentTitle.isEmpty ? nil : currentTitle, accentHex: Catalog.styles[subj]?.accent ?? "#ec4899")
        }
        if QuestionBank.isFinalKey(q.c) {
            let subj = QuestionBank.baseCourse(q.c)
            return Meta(course: subj, unit: q.u >= 1 ? "Unit \(q.u)" : nil, accentHex: Catalog.styles[subj]?.accent ?? "#8b5cf6")
        }
        if isSubjectPool || isCourseMixed {
            return Meta(course: q.c, unit: q.u >= 1 ? "Unit \(q.u)" : "Keçmiş imtahan", accentHex: Catalog.styles[q.c]?.accent ?? "#8b5cf6")
        }
        // CONFIG[q.c].units[q.u - 1] is always "Unit N" for subjects; other keys fall back to the same text.
        return Meta(course: q.c, unit: "Unit \(q.u)", accentHex: Catalog.styles[q.c]?.accent ?? "#8b5cf6")
    }

    var currentMeta: Meta? {
        guard showsMeta, let q = current?.question else { return nil }
        return meta(for: q)
    }

    /// "N Səhv" badge after the question text (wrongCounts ≥ 2; red from 3).
    var hardBadgeCount: Int? {
        guard let q = current?.question else { return nil }
        let n = store.wrongCount(q.q)
        return n >= 2 ? n : nil
    }

    var isCurrentBookmarked: Bool { current.map { store.isBookmarked($0.question) } ?? false }

    /// Mock subject pills (unique q.c in order).
    var mockSubjects: [String] {
        guard isMockMode else { return [] }
        var seen = Set<String>()
        return items.map(\.question.c).filter { seen.insert($0).inserted }
    }

    func jumpToSubject(_ s: String) {
        if let i = items.firstIndex(where: { $0.question.c == s }) { index = i }
    }

    /// Letter of an option position.
    nonisolated static let letters = ["A", "B", "C", "D", "E", "F", "G"]

    /// "Düzgün cavab: B · text" line.
    var correctLine: String? {
        guard let item = current, let pos = item.options.firstIndex(where: { $0.originalIndex == item.question.a }) else { return nil }
        return "\(Self.letters[studySafe: pos] ?? "?") · \(item.options[pos].text)"
    }

    /// Feedback title after answering: "İpucu" / "Düzdür" / "Səhv".
    var feedbackTitle: String? {
        guard let a = currentAnswer, let q = current?.question else { return nil }
        if a.hint { return "İpucu" }
        if a.chosen == Self.dontKnowChoice { return "Bilmirəm" }
        return a.chosen == q.a ? "Düzdür" : "Səhv"
    }

    /// "Keç" / "Bitir" before answering, "Davam" / "Nəticəyə bax" after.
    var nextButtonTitle: String {
        if currentAnswer == nil { return isLast ? "Bitir" : "Keç" }
        return isLast ? "Nəticəyə bax" : "Davam"
    }

    /// Flashcard mode hides the options until revealed (or answered).
    var optionsHidden: Bool { isFlashcard && currentAnswer == nil && !flashcardRevealed }

    /// Text for speech (speakQuestion, tr-TR): question + shuffled options.
    var speechText: String? {
        guard let item = current else { return nil }
        return RichText.plain(item.question.q) + ". " + item.options.map { RichText.plain($0.text) }.joined(separator: ". ")
    }

    // MARK: Answering (checkAnswer)

    /// Answers the current question with an original option index. Returns nil if already answered.
    @discardableResult
    func choose(_ originalIndex: Int) -> AnswerOutcome? {
        guard !isClosed, result == nil, answers[index] == nil, let item = current else { return nil }
        store.noteActivity()
        let q = item.question
        let isCorrect = originalIndex == q.a
        answers[index] = Answer(chosen: originalIndex, hint: false)
        if isCorrect { correctCount += 1 } else { wrongCount += 1 }

        let stat = answerStat(q)
        let cel = store.recordQuizAnswer(q, isCorrect: isCorrect, removeFromWrongWhenCorrect: isWrongMode, stat: stat)
        if isCorrect { scheduleAutoAdvance() } else if requeuesWrong { requeue(item) }
        saveProgress()
        return AnswerOutcome(isCorrect: isCorrect, willAutoAdvance: isCorrect, celebration: cel)
    }

    /// Statistics bucket of an answer in this session.
    private func answerStat(_ q: Question) -> (course: String, cat: String, sub: String)? {
        var stat: (course: String, cat: String, sub: String)?
        if isMockMode {
            stat = (Catalog.mockKey, "mock", "Sınaq")
        } else if !course.isEmpty && !isSearchMode {
            var cat = category, sub = currentTitle
            if currentTitle == "Multi" { cat = "units"; sub = "Multi" }
            else if isWrongMode { cat = "wrong"; sub = "Səhvlərin Təkrarı" }
            else if isMixedMode { cat = "mixed"; sub = "Qarışıq Sınaq" }
            else if cat == "units" {
                sub = course == Catalog.mixedKey
                    ? (bank.mixedParts(for: examMode)[studySafe: selectionIndex]?.statKey ?? "Unit \(selectionIndex + 1)")
                    : "Unit \(selectionIndex + 1)"
            }
            stat = (course, cat, sub)
        }
        if let s = Self.perQuestionStat(kind, q) { stat = s }
        return stat
    }

    /// "Bilmirəm": shows the answer and counts as a wrong answer (stats, wrong list, review, mastery).
    func dontKnow() {
        guard !isClosed, result == nil, answers[index] == nil, let item = current else { return }
        store.noteActivity()
        answers[index] = Answer(chosen: Self.dontKnowChoice, hint: false)
        wrongCount += 1
        _ = store.recordQuizAnswer(item.question, isCorrect: false, removeFromWrongWhenCorrect: false, stat: answerStat(item.question))
        if requeuesWrong { requeue(item) }
        saveProgress()
    }

    /// Answer.chosen of a "Bilmirəm".
    static let dontKnowChoice = -2

    /// Wrong answers come back at the end of the test (Ayarlar switch). Not in exams that are graded
    /// in points, the mock exam or the simulation: there the question count is the exam.
    var requeuesWrong: Bool {
        LearnSettings.shared.requeueWrong && simulation == nil && !isMockMode && !isGradedExam
    }

    /// Questions added at the end by `requeue` (shown with a "Təkrar" badge).
    func isRequeued(_ item: Item) -> Bool {
        items.firstIndex { $0.question.q == item.question.q }.map { $0 < item.id } ?? false
    }

    private func requeue(_ item: Item) {
        let q = item.question
        // Once per pending copy: no new copy while an unanswered one is still waiting further on.
        let pending = items.indices.contains { $0 > index && items[$0].question.q == q.q && answers[$0] == nil }
        guard !pending else { return }
        items.append(Item(id: items.count, question: q,
                          options: q.o.enumerated().map { Option(text: $0.element, originalIndex: $0.offset) }.shuffled()))
    }

    /// Answers by displayed position (A = 0 …), like the 1-5 / A-E keyboard shortcuts.
    @discardableResult
    func chooseDisplayed(_ position: Int) -> AnswerOutcome? {
        guard let opt = current?.options[studySafe: position] else { return nil }
        return choose(opt.originalIndex)
    }

    private func scheduleAutoAdvance() {
        cancelAutoAdvance()
        let at = index
        autoAdvanceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled, let self else { return }
            self.autoAdvance(from: at)
        }
    }

    private func autoAdvance(from at: Int) {
        autoAdvanceTask = nil
        guard !isClosed, result == nil, index == at else { return }
        if index == items.count - 1 {
            switch requestFinish() {
            case .needsConfirmation(let m): pendingFinishConfirmation = m
            case .finished: break
            }
        } else {
            nav(1)
        }
    }

    private func cancelAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
    }

    // MARK: Navigation & tools

    func nav(_ d: Int) {
        let next = index + d
        if next >= 0 && next < items.count { index = next }
    }

    func go(to i: Int) { if items.indices.contains(i) { index = i } }

    /// "Keç"/"Davam" button: next question, or the finish request on the last one.
    func next() -> FinishRequest? {
        if isLast { return requestFinish() }
        nav(1)
        return nil
    }

    func previous() { nav(-1) }

    /// İpucu: marks the question as a hint (shows the answer, counts as not correct in the result, no stat).
    func hint() {
        guard answers[index] == nil, current != nil else { return }
        answers[index] = Answer(chosen: -1, hint: true)
        saveProgress()
    }

    func toggleFlashcard() { isFlashcard.toggle(); flashcardRevealed = false }
    func revealFlashcard() { flashcardRevealed = true }

    @discardableResult
    func toggleBookmark() -> Bool {
        guard let q = current?.question else { return false }
        return store.toggleBookmark(q)
    }

    /// resetUnit: start the same questions again.
    func reset() {
        cancelAutoAdvance()
        index = 0; answers = [:]; correctCount = 0; wrongCount = 0; result = nil
        clearProgress()
    }

    // MARK: Finish (finishTest)

    func requestFinish() -> FinishRequest {
        if answeredCount < total {
            return .needsConfirmation("Sınaq yarımçıqdır (Cavablandırılıb: \(answeredCount)/\(total)). Bitirməkdən əminsiniz?")
        }
        return .finished(finish())
    }

    /// Ends the test without asking, stops the timer and builds the result.
    @discardableResult
    func finish() -> Result {
        if let result { return result }
        cancelAutoAdvance()
        pendingFinishConfirmation = nil
        let elapsed = ownsTimer ? store.quizTimerText : ""
        let elapsedSeconds = ownsTimer ? store.quizElapsedSeconds : 0
        if ownsTimer { store.stopQuizTimer() }
        var c = 0, w = 0
        var order: [String] = []
        var sub: [String: (c: Int, w: Int, n: Int)] = [:]
        for (i, item) in items.enumerated() {
            let k = item.question.c
            if sub[k] == nil { order.append(k); sub[k] = (0, 0, 0) }
            sub[k]!.n += 1
            if let a = answers[i] {
                if a.chosen == item.question.a { c += 1; sub[k]!.c += 1 } else { w += 1; sub[k]!.w += 1 }
            }
        }
        let total = items.count
        let net = Double(c) - Double(w) / 4
        let score = total > 0 ? max(0, net / Double(total) * 100) : 0
        let mock = order.map { k -> MockSubjectResult in
            let s = sub[k]!
            let subNet = Double(s.c) - Double(s.w) / 4
            return MockSubjectResult(subject: k, correct: s.c, wrong: s.w, score: s.n > 0 ? max(0, subNet / Double(s.n) * 100) : 0)
        }
        let avg = mock.isEmpty ? 0 : mock.reduce(0) { $0 + $1.score } / Double(mock.count)
        var missed: [MissedItem] = []
        for (i, item) in items.enumerated() {
            guard let a = answers[i], a.chosen != item.question.a else { continue }
            let q = item.question
            missed.append(MissedItem(question: q, chosenText: a.chosen >= 0 ? q.o[studySafe: a.chosen] : nil, correctText: q.o[studySafe: q.a] ?? ""))
        }
        lastMissed = missed.map(\.question)
        lastMissedCourse = course
        let r = Result(correct: c, wrong: w, total: total, net: net, score: score,
                       accuracy: total > 0 ? Int((Double(c) / Double(total) * 100).rounded()) : 0,
                       elapsed: elapsed.isEmpty ? "—" : elapsed, isMock: isMockMode, mockSubjects: mock,
                       averageMockScore: avg, confetti: isMockMode ? avg >= 50 : score >= 50, missed: missed)
        result = r
        clearProgress()
        // Nailiyyətlər: graded past-exam score, a whole "Bütün suallar" pool answered to the end.
        if isCourseMixed && c + w > 0 {
            MixedExamHistory.shared.add(MixedExamAttempt(subject: course, date: Date(), correct: c, wrong: w,
                                                         total: total, score: score, seconds: elapsedSeconds))
        }
        store.noteTestFinished(subject: course, gradedScore: isGradedExam && total > 0 ? score : nil,
                               finishedPool: isSubjectPool && total > 0 && c + w == total)
        return r
    }

    /// "Səhvləri təkrarla (N)": a new session with the missed questions.
    func reviewMissed() throws -> QuizSession {
        close()
        return try QuizSession(.reviewMissed(questions: lastMissed, course: lastMissedCourse), store: store, bank: bank)
    }

    /// Leaving the quiz (the dashboards call stopTimer).
    func close() {
        guard !isClosed else { return }
        saveProgress()
        isClosed = true
        cancelAutoAdvance()
        if ownsTimer { store.stopQuizTimer() }
    }

    /// closeModal redirect after the result.
    var exit: Exit {
        if course == Catalog.overallKey || course == Catalog.mockKey { return .overall }
        if Catalog.configKeys.contains(course) { return .course(course) }
        return .home
    }
}

extension QuizSession {
    /// Real exam-like sessions (past vize / final booklets, Mixed parts and the 20-question mixed exam)
    /// are graded like ATA AÖF: 100 points over the questions, 4 wrong answers cancel 1 correct.
    var isGradedExam: Bool {
        switch kind {
        case .pdfExam, .finalExam, .mixedPart, .courseMixed: true
        case .unit(let course, _): course == Catalog.mixedKey
        default: false
        }
    }
}

extension QuizSession {
    /// "Bütün suallar" / "Öyrənilməmişlər": a subject's whole pool, every question tagged with its unit.
    var isSubjectPool: Bool {
        switch kind {
        case .allQuestions, .unlearned: true
        default: false
        }
    }

    /// A subject's "Qarışıq sınaq" (20 random questions from its units): each question shows its unit.
    var isCourseMixed: Bool {
        if case .courseMixed = kind { true } else { false }
    }
}
