import Foundation
import SwiftUI

// Compiled into both the app and the ImtahanWidgets extension.
// Interactive "Sual" widget: the app writes a small deck of plain-text questions to the app group
// (Store/StudyStore+QuestionWidget.swift); the widget shows one at a time and answers it in place
// (Shared/QuestionWidgetIntents.swift). Answers wait in a "pending" queue in the app group until the app
// imports them into the normal bookkeeping (stats, wrong/correct lists, wrong counts → sync).

/// One question as the widget shows it. The original data (c/u/q/o/a) rides along so the app can record
/// the answer exactly like a quiz answer, even after the deck has been replaced.
struct WidgetQuestion: Codable, Sendable, Hashable, Identifiable {
    /// Stable within a deck (deck id + position).
    var id: String
    var subject: String
    /// "Ünitə 3" or "" when unknown.
    var unitLabel: String
    /// Plain question text (RichText.plain).
    var text: String
    /// Plain options in display (shuffled) order.
    var options: [String]
    /// Index of the correct option in `options`.
    var correctIndex: Int

    // Source question (Question.c / u / q / o / a, raw HTML).
    var srcC: String
    var srcU: Int
    var srcQ: String
    var srcO: [String]
    var srcA: Int
}

struct WidgetQuestionDeck: Codable, Sendable, Equatable {
    var id: String
    /// ExamMode raw value the deck was built for.
    var mode: String
    var createdAt: Date
    var items: [WidgetQuestion]
}

/// Which question is on screen: `cursor` at `cursorDate`, then one more for every full hour.
struct WidgetQuestionCursor: Codable, Sendable, Equatable {
    var deckID: String
    var cursor: Int
    var cursorDate: Date

    /// Absolute (not wrapped) position at `date`.
    func position(at date: Date) -> Int {
        cursor + max(0, Int(date.timeIntervalSince(cursorDate) / 3600))
    }

    /// Next moment the hourly rotation changes the position (after `date`).
    func nextRotation(after date: Date) -> Date {
        let hours = max(0, Int(date.timeIntervalSince(cursorDate) / 3600)) + 1
        return cursorDate.addingTimeInterval(Double(hours) * 3600)
    }
}

/// The user's answer to the question on screen (shown green / red until the question changes).
struct WidgetQuestionFeedback: Codable, Sendable, Equatable {
    var questionID: String
    var chosen: Int
    var correct: Bool
    var at: Date
}

/// An answer waiting for the app. `id` is unique per tap (dedupe on import).
struct PendingWidgetAnswer: Codable, Sendable, Hashable, Identifiable {
    var id: String
    var at: Date
    var isCorrect: Bool
    var subject: String
    var srcC: String
    var srcU: Int
    var srcQ: String
    var srcO: [String]
    var srcA: Int
}

enum QuestionWidgetStorage {
    static let appGroup = "group.az.fuadb.imtahan"
    /// WidgetKit kind of the question widget.
    static let widgetKind = "ImtahanQuestion"
    /// Darwin notification posted by the widget after an answer (the app imports while running).
    static let darwinName = "az.fuadb.imtahan.questionwidget.answered"

    static let deckKey = "qw_deck"
    static let cursorKey = "qw_cursor"
    static let feedbackKey = "qw_feedback"
    static let pendingKey = "qw_pending"
    static let statsKey = "qw_session_stats"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let raw = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: raw)
    }

    private static func save<T: Encodable>(_ value: T?, _ key: String) {
        guard let value, let raw = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key); return
        }
        defaults.set(raw, forKey: key)
    }

    static func loadDeck() -> WidgetQuestionDeck? { load(WidgetQuestionDeck.self, deckKey) }
    static func loadCursor() -> WidgetQuestionCursor? { load(WidgetQuestionCursor.self, cursorKey) }
    static func loadFeedback() -> WidgetQuestionFeedback? { load(WidgetQuestionFeedback.self, feedbackKey) }
    static func loadPending() -> [PendingWidgetAnswer] { load([PendingWidgetAnswer].self, pendingKey) ?? [] }

    static func saveCursor(_ c: WidgetQuestionCursor) { save(c, cursorKey) }
    static func saveFeedback(_ f: WidgetQuestionFeedback?) { save(f, feedbackKey) }
    static func savePending(_ p: [PendingWidgetAnswer]) { save(p.isEmpty ? nil : p, pendingKey) }

    /// New deck → cursor back to its first question, feedback cleared.
    static func saveDeck(_ deck: WidgetQuestionDeck, now: Date = Date()) {
        save(deck, deckKey)
        saveCursor(WidgetQuestionCursor(deckID: deck.id, cursor: 0, cursorDate: now))
        saveFeedback(nil)
    }

    /// Cursor that belongs to `deck` (a fresh one when the stored cursor is for another deck).
    static func cursor(for deck: WidgetQuestionDeck) -> WidgetQuestionCursor {
        if let c = loadCursor(), c.deckID == deck.id { return c }
        return WidgetQuestionCursor(deckID: deck.id, cursor: 0, cursorDate: deck.createdAt)
    }

    /// Question on screen at `date`.
    static func current(at date: Date = Date()) -> (deck: WidgetQuestionDeck, question: WidgetQuestion, position: Int)? {
        guard let deck = loadDeck(), !deck.items.isEmpty else { return nil }
        let pos = cursor(for: deck).position(at: date)
        return (deck, deck.items[pos % deck.items.count], pos)
    }

    /// Today's widget tally (correct, wrong), reset at local midnight.
    struct DayTally: Codable, Sendable, Equatable {
        var day: String
        var correct: Int
        var wrong: Int
    }

    static func tally(now: Date = Date()) -> DayTally {
        let today = StudySnapshot.dayKey(now)
        if let t = load(DayTally.self, statsKey), t.day == today { return t }
        return DayTally(day: today, correct: 0, wrong: 0)
    }

    static func bumpTally(correct: Bool, now: Date = Date()) {
        var t = tally(now: now)
        if correct { t.correct += 1 } else { t.wrong += 1 }
        save(t, statsKey)
    }

    static func postAnswered() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(darwinName as CFString), nil, nil, true)
    }
}

/// Cublya colors for the question widget.
enum QuestionWidgetPalette {
    static let bg = Color(red: 0x02 / 255, green: 0x02 / 255, blue: 0x02 / 255)
    static let surface = Color(red: 0x19 / 255, green: 0x19 / 255, blue: 0x19 / 255)
    static let border = Color(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2C / 255)
    static let accent = Color(red: 0x3B / 255, green: 0x8E / 255, blue: 0xFF / 255)
    static let text = Color.white
    static let caption = Color(red: 0xC5 / 255, green: 0xC4 / 255, blue: 0xC4 / 255)
    static let muted = Color(red: 0x8A / 255, green: 0x8A / 255, blue: 0x8A / 255)
    static let success = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    static let danger = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)
}
