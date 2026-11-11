import Foundation
import UIKit
import WidgetKit

// Interactive "Sual" widget (ImtahanWidgets/QuestionWidget.swift), app side:
// • writes a deck of in-scope, text-only questions to the app group (new deck when the exam mode changes,
//   the deck is mostly used up or a day old);
// • imports the answers given on the widget (pending queue in the app group) into the normal bookkeeping:
//   stats[subject].bd["widget"]["Widget sualı"], wrong/correct lists, wrong counts, daily history → sync.
// Runs from WidgetSnapshotWriter.writeNow (launch, background, debounced data changes), on every
// foreground and on the widget's Darwin notification while the app is running.

extension StudyStore {
    static let questionWidgetDeckSize = 40
    static let questionWidgetStatCategory = "widget"
    static let questionWidgetStatSub = "Widget sualı"
    private static let appliedIDsKey = "qw_applied_answer_ids"

    /// Import pending answers, then refresh the deck if needed. Cheap when nothing changed.
    func syncQuestionWidget(now: Date = Date()) {
        QuestionWidgetBridge.shared.install(self)
        let imported = importWidgetAnswers()
        let rebuilt = refreshQuestionWidgetDeckIfNeeded(now: now)
        if imported || rebuilt { WidgetCenter.shared.reloadTimelines(ofKind: QuestionWidgetStorage.widgetKind) }
    }

    // MARK: Deck

    @discardableResult
    func refreshQuestionWidgetDeckIfNeeded(now: Date = Date(), force: Bool = false) -> Bool {
        if !force, let deck = QuestionWidgetStorage.loadDeck(), !deck.items.isEmpty, deck.mode == examMode.rawValue {
            let used = QuestionWidgetStorage.cursor(for: deck).position(at: now)
            let fresh = now.timeIntervalSince(deck.createdAt) < 24 * 3600
            if fresh && used < deck.items.count - 8 { return false }
        }
        let deck = makeQuestionWidgetDeck(now: now)
        guard !deck.items.isEmpty else { return false }
        QuestionWidgetStorage.saveDeck(deck, now: now)
        return true
    }

    func makeQuestionWidgetDeck(now: Date = Date()) -> WidgetQuestionDeck {
        let subjects = Set(Catalog.subjects)
        let pool = bank.all.filter { q in
            (subjects.contains(q.c) || q.c == Catalog.mixedKey)
                && q.o.count >= 2 && q.o.indices.contains(q.a)
                && inScope(q)
                && RichText.imageNames(q.q).isEmpty
                && q.o.allSatisfy { RichText.imageNames($0).isEmpty }
        }
        // Prefer questions not yet answered correctly; top up from the rest.
        var correctTexts = Set<String>()
        for list in data.correct.values { for q in list { correctTexts.insert(q.q) } }
        let unseen = pool.filter { !correctTexts.contains($0.q) }.shuffled()
        let seen = pool.filter { correctTexts.contains($0.q) }.shuffled()

        let deckID = String(UUID().uuidString.prefix(8))
        var items: [WidgetQuestion] = []
        var usedTexts = Set<String>()
        for q in unseen + seen {
            guard items.count < Self.questionWidgetDeckSize, !usedTexts.contains(q.q) else { continue }
            let text = RichText.plain(q.q)
            let opts = q.o.map { RichText.plain($0) }
            guard (8...220).contains(text.count), opts.allSatisfy({ (1...70).contains($0.count) }) else { continue }
            usedTexts.insert(q.q)
            let order = Array(opts.indices).shuffled()
            items.append(WidgetQuestion(
                id: "\(deckID)-\(items.count)",
                subject: Self.questionWidgetSubject(q),
                unitLabel: bank.unit(of: q).map { "Ünitə \($0)" } ?? "",
                text: text,
                options: order.map { opts[$0] },
                correctIndex: order.firstIndex(of: q.a) ?? 0,
                srcC: q.c, srcU: q.u, srcQ: q.q, srcO: q.o, srcA: q.a))
        }
        return WidgetQuestionDeck(id: deckID, mode: examMode.rawValue, createdAt: now, items: items)
    }

    /// Subject a question belongs to (Mixed: u = 1-based index into Catalog.subjects).
    static func questionWidgetSubject(_ q: Question) -> String {
        if q.c == Catalog.mixedKey {
            return Catalog.subjects.indices.contains(q.u - 1) ? Catalog.subjects[q.u - 1] : "Qarışıq"
        }
        return QuestionBank.baseCourse(q.c)
    }

    /// stats key for a widget answer: the subject (Mixed without a known subject → "Mixed").
    static func questionWidgetStatCourse(_ q: Question) -> String {
        let s = questionWidgetSubject(q)
        return Catalog.subjects.contains(s) ? s : Catalog.mixedKey
    }

    // MARK: Answers

    /// Applies answers given on the widget once each (dedupe by answer id). Returns true if any were applied.
    @discardableResult
    func importWidgetAnswers() -> Bool {
        let pending = QuestionWidgetStorage.loadPending()
        guard !pending.isEmpty else { return false }
        var applied = defaults.stringArray(forKey: Self.appliedIDsKey) ?? []
        let appliedSet = Set(applied)
        let fresh = pending.filter { !appliedSet.contains($0.id) }.sorted { $0.at < $1.at }

        if !fresh.isEmpty {
            batch {
                for p in fresh {
                    let q = Question(c: p.srcC, u: p.srcU, q: p.srcQ, o: p.srcO, a: p.srcA)
                    recordQuizAnswer(q, isCorrect: p.isCorrect, removeFromWrongWhenCorrect: false,
                                     stat: (Self.questionWidgetStatCourse(q), Self.questionWidgetStatCategory,
                                            Self.questionWidgetStatSub))
                }
            }
            applied.append(contentsOf: fresh.map(\.id))
            if applied.count > 500 { applied.removeFirst(applied.count - 500) }
            defaults.set(applied, forKey: Self.appliedIDsKey)
        }
        // Drop what is applied; re-read so an answer the widget added meanwhile survives.
        let done = Set(applied)
        QuestionWidgetStorage.savePending(QuestionWidgetStorage.loadPending().filter { !done.contains($0.id) })
        return !fresh.isEmpty
    }
}

/// Foreground + Darwin-notification hooks (installed once, on the first sync).
@MainActor
final class QuestionWidgetBridge {
    static let shared = QuestionWidgetBridge()
    private weak var store: StudyStore?
    private var installed = false

    func install(_ store: StudyStore) {
        self.store = store
        guard !installed else { return }
        installed = true
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil,
                                               queue: .main) { _ in
            Task { @MainActor in QuestionWidgetBridge.shared.store?.syncQuestionWidget() }
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { _, _, _, _, _ in
            Task { @MainActor in
                guard let store = QuestionWidgetBridge.shared.store, store.importWidgetAnswers() else { return }
                WidgetCenter.shared.reloadTimelines(ofKind: QuestionWidgetStorage.widgetKind)
            }
        }, QuestionWidgetStorage.darwinName as CFString, nil, .deliverImmediately)
    }
}
