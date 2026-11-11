import Foundation
import Observation

// Surprise question (initSurpriseTimer / triggerSurpriseQuestion / resumeSurpriseTimer /
// dismissSurpriseModal / closeSurpriseModal): every 180 s a random non-Mixed question with a 30 s
// countdown. Tap an option to select it, tap it again to confirm. Time running out counts as wrong;
// closing before answering records nothing.

@MainActor
@Observable
final class SurpriseEngine {
    enum Feedback: Hashable, Sendable {
        case timeout   // "⏱️ Vaxt bitdi! Cavablandırılmadı."
        case correct   // "🎉 Doğrudur! Əla."
        case wrong     // "❌ Yanlışdır! Düzgün cavabı yoxlayın."

        var text: String {
            switch self {
            case .timeout: return "⏱️ Vaxt bitdi! Cavablandırılmadı."
            case .correct: return "🎉 Doğrudur! Əla."
            case .wrong: return "❌ Yanlışdır! Düzgün cavabı yoxlayın."
            }
        }
        var isPositive: Bool { self == .correct }
    }

    static let answerSeconds = 30

    /// The open question (nil = modal hidden).
    private(set) var question: Question?
    /// "<course> • Unit <u>"
    var metaText: String { question.map { "\($0.c) • Unit \($0.u)" } ?? "" }
    /// Option index selected by the first tap (options are in their original order).
    private(set) var selected: Int?
    /// Seconds left ("\(timeLeft)s").
    private(set) var timeLeft = SurpriseEngine.answerSeconds
    private(set) var isAnswered = false
    /// Option chosen when revealed (nil after a timeout).
    private(set) var chosen: Int?
    private(set) var feedback: Feedback?
    var isPresented: Bool { question != nil }
    /// Called after the modal closes (the web re-renders the home page here).
    @ObservationIgnored var onClose: (() -> Void)?

    @ObservationIgnored private let store: StudyStore
    @ObservationIgnored private let bank: QuestionBank
    @ObservationIgnored private var intervalTask: Task<Void, Never>?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    init(store: StudyStore, bank: QuestionBank = .shared) {
        self.store = store
        self.bank = bank
        store.surpriseEngine = self
    }

    // MARK: Settings (device-local, UserDefaults)

    static let enabledKey = "surprise_enabled"
    static let intervalKey = "surprise_interval_min"
    /// Interval choices in minutes for the Settings picker.
    static let intervalChoices = [1, 3, 5, 10, 15, 30]

    /// Whether surprise questions appear at all (default on, like the web app).
    var isEnabled: Bool = UserDefaults.standard.object(forKey: SurpriseEngine.enabledKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled { start() } else { stop() }
        }
    }

    /// Minutes between surprise questions (default 3, like the web app's 180 s).
    var intervalMinutes: Int = {
        let v = UserDefaults.standard.integer(forKey: SurpriseEngine.intervalKey)
        return v > 0 ? v : 3
    }() {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: Self.intervalKey)
            if isEnabled { start() }   // restart the cycle with the new interval
        }
    }

    /// initSurpriseTimer: a question every `intervalMinutes` while none is open (only when enabled).
    func start() {
        intervalTask?.cancel()
        guard isEnabled else { intervalTask = nil; return }
        let interval = Duration.seconds(intervalMinutes * 60)
        intervalTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self, self.isEnabled else { return }
                if !self.isPresented { self.trigger() }
            }
        }
    }

    func stop() {
        intervalTask?.cancel(); intervalTask = nil
        // An already open question keeps its countdown; only the cycle stops.
        if question == nil { countdownTask?.cancel(); countdownTask = nil }
    }

    /// triggerSurpriseQuestion: pauses the quiz timer and opens a random non-Mixed question.
    func trigger() {
        let pool = bank.all.filter { $0.c != Catalog.mixedKey && store.inScope($0) }
        guard let q = pool.randomElement() else { return }
        store.pauseQuizTimer()
        question = q
        selected = nil
        chosen = nil
        feedback = nil
        isAnswered = false
        timeLeft = Self.answerSeconds
        store.isSurpriseActive = true
        startCountdown()
    }

    /// First tap selects, a second tap on the same option confirms.
    func tap(_ optionIndex: Int) {
        guard question != nil, !isAnswered else { return }
        store.noteActivity()
        if selected == optionIndex { reveal(optionIndex) } else { selected = optionIndex }
    }

    /// Close button: stops the countdown first, so an unanswered question is not recorded.
    func dismiss() {
        countdownTask?.cancel(); countdownTask = nil
        close()
    }

    /// closeSurpriseModal: hides the modal and resumes the quiz timer of a running test.
    func close() {
        countdownTask?.cancel(); countdownTask = nil
        question = nil
        selected = nil
        store.isSurpriseActive = false
        store.resumeQuizTimer()
        onClose?()
    }

    // MARK: Lifecycle

    func sceneWillResignActive() {
        if store.isSurpriseActive { countdownTask?.cancel(); countdownTask = nil }
    }

    func sceneDidBecomeActive() {
        if store.isSurpriseActive && countdownTask == nil && !isAnswered && question != nil { startCountdown() }
    }

    // MARK: Private

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.timeLeft -= 1
                if self.timeLeft <= 0 {
                    self.countdownTask = nil
                    if !self.isAnswered { self.reveal(nil) }
                    return
                }
            }
        }
    }

    private func reveal(_ idx: Int?) {
        guard let q = question, !isAnswered else { return }
        isAnswered = true
        store.isSurpriseActive = false
        countdownTask?.cancel(); countdownTask = nil
        let isCorrect = idx == q.a
        chosen = idx
        store.recordSurpriseAnswer(q, isCorrect: isCorrect)
        feedback = idx == nil ? .timeout : (isCorrect ? .correct : .wrong)
    }
}
