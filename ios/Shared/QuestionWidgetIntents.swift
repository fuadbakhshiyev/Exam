import AppIntents
import Foundation

// Buttons of the interactive "Sual" widget (Button(intent:)). They run without opening the app and only
// touch the app group; WidgetKit reloads the widget when perform() returns.

struct AnswerWidgetQuestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Widget sualını cavabla"
    static let isDiscoverable = false

    @Parameter(title: "Sual") var questionID: String
    @Parameter(title: "Variant") var index: Int

    init() {}

    init(questionID: String, index: Int) {
        self.questionID = questionID
        self.index = index
    }

    func perform() async throws -> some IntentResult {
        guard let deck = QuestionWidgetStorage.loadDeck(),
              let q = deck.items.first(where: { $0.id == questionID }),
              q.options.indices.contains(index) else { return .result() }
        // One answer per question on screen.
        if QuestionWidgetStorage.loadFeedback()?.questionID == q.id { return .result() }

        let now = Date()
        let correct = index == q.correctIndex
        QuestionWidgetStorage.saveFeedback(.init(questionID: q.id, chosen: index, correct: correct, at: now))
        var pending = QuestionWidgetStorage.loadPending()
        pending.append(PendingWidgetAnswer(
            id: UUID().uuidString, at: now, isCorrect: correct, subject: q.subject,
            srcC: q.srcC, srcU: q.srcU, srcQ: q.srcQ, srcO: q.srcO, srcA: q.srcA))
        QuestionWidgetStorage.savePending(pending)
        QuestionWidgetStorage.bumpTally(correct: correct, now: now)
        QuestionWidgetStorage.postAnswered()
        return .result()
    }
}

struct NextWidgetQuestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Növbəti widget sualı"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        guard let deck = QuestionWidgetStorage.loadDeck(), !deck.items.isEmpty else { return .result() }
        let now = Date()
        let pos = QuestionWidgetStorage.cursor(for: deck).position(at: now)
        QuestionWidgetStorage.saveCursor(.init(deckID: deck.id, cursor: pos + 1, cursorDate: now))
        QuestionWidgetStorage.saveFeedback(nil)
        return .result()
    }
}
