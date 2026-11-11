import AppIntents
import SwiftUI
import WidgetKit

// Interactive "Sual" widget (Home Screen medium / large): one multiple-choice question from the deck the
// app writes to the app group (Shared/QuestionWidgetShared.swift). Options are Button(intent:) — answering
// and "Növbəti" run in place (Shared/QuestionWidgetIntents.swift); the question also rotates every hour.

struct QuestionEntry: TimelineEntry {
    let date: Date
    let question: WidgetQuestion?
    /// Feedback for `question` only.
    let feedback: WidgetQuestionFeedback?
    let tally: QuestionWidgetStorage.DayTally
}

struct QuestionProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuestionEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (QuestionEntry) -> Void) {
        let e = entry(at: Date())
        completion(e.question == nil && context.isPreview ? .sample : e)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestionEntry>) -> Void) {
        let now = Date()
        var entries = [entry(at: now)]
        if let deck = QuestionWidgetStorage.loadDeck(), !deck.items.isEmpty {
            // Next 12 hourly rotations.
            let cursor = QuestionWidgetStorage.cursor(for: deck)
            var t = now
            for _ in 0..<12 {
                t = cursor.nextRotation(after: t)
                entries.append(entry(at: t))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> QuestionEntry {
        let cur = QuestionWidgetStorage.current(at: date)
        let fb = QuestionWidgetStorage.loadFeedback()
        return QuestionEntry(date: date, question: cur?.question,
                             feedback: fb?.questionID == cur?.question.id ? fb : nil,
                             tally: QuestionWidgetStorage.tally(now: date))
    }
}

struct QuestionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: QuestionWidgetStorage.widgetKind, provider: QuestionProvider()) { entry in
            QuestionWidgetView(entry: entry)
                .widgetURL(URL(string: "imtahan://home"))
        }
        .configurationDisplayName("Sual")
        .description("Tətbiqi açmadan sual həll et")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private typealias P = QuestionWidgetPalette
private let letters = ["A", "B", "C", "D", "E", "F"]

struct QuestionWidgetView: View {
    let entry: QuestionEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let q = entry.question {
                if family == .systemLarge {
                    LargeQuestionView(q: q, feedback: entry.feedback, tally: entry.tally)
                } else {
                    MediumQuestionView(q: q, feedback: entry.feedback)
                }
            } else {
                EmptyQuestionView()
            }
        }
        .padding(family == .systemLarge ? 16 : 12)
        .containerBackground(P.bg, for: .widget)
    }
}

// MARK: Parts

private struct Caption: View {
    let q: WidgetQuestion
    var size: CGFloat = 10

    var body: some View {
        Text(q.unitLabel.isEmpty ? q.subject : "\(q.subject) · \(q.unitLabel)")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(P.muted)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

private struct ResultBadge: View {
    let feedback: WidgetQuestionFeedback
    var size: CGFloat = 10

    var body: some View {
        Label(feedback.correct ? "Düzdür" : "Səhv", systemImage: feedback.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(feedback.correct ? P.success : P.danger)
            .lineLimit(1)
            .fixedSize()
    }
}

private struct NextButton: View {
    let answered: Bool
    var size: CGFloat = 10

    var body: some View {
        Button(intent: NextWidgetQuestionIntent()) {
            HStack(spacing: 3) {
                Text("Növbəti")
                Image(systemName: "chevron.right").font(.system(size: size - 1, weight: .bold))
            }
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(answered ? Color.white : P.accent)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(answered ? P.accent : P.accent.opacity(0.16), in: Capsule())
            .fixedSize()
        }
        .buttonStyle(.plain)
    }
}

private struct OptionButton: View {
    let q: WidgetQuestion
    let index: Int
    let feedback: WidgetQuestionFeedback?
    var fontSize: CGFloat = 10.5
    var badge: CGFloat = 15

    private enum Look { case idle, right, wrong, dim }

    private var look: Look {
        guard let feedback else { return .idle }
        if index == q.correctIndex { return .right }
        if index == feedback.chosen { return .wrong }
        return .dim
    }

    private var tint: Color {
        switch look {
        case .right: P.success
        case .wrong: P.danger
        default: P.accent
        }
    }

    var body: some View {
        Button(intent: AnswerWidgetQuestionIntent(questionID: q.id, index: index)) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(look == .idle || look == .dim ? tint.opacity(0.18) : tint)
                    if look == .right || look == .wrong {
                        Image(systemName: look == .right ? "checkmark" : "xmark")
                            .font(.system(size: badge * 0.5, weight: .heavy))
                            .foregroundStyle(.white)
                    } else {
                        Text(letters[index])
                            .font(.system(size: badge * 0.6, weight: .bold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: badge, height: badge)
                Text(q.options[index])
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(P.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if look == .right || look == .wrong {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint.opacity(0.7), lineWidth: 1)
                }
            }
            .opacity(look == .dim ? 0.55 : 1)
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch look {
        case .right: P.success.opacity(0.18)
        case .wrong: P.danger.opacity(0.18)
        default: P.surface
        }
    }
}

// MARK: Families

private struct MediumQuestionView: View {
    let q: WidgetQuestion
    let feedback: WidgetQuestionFeedback?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(q.unitLabel.isEmpty ? q.subject : "\(q.subject) · \(q.unitLabel)")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(P.muted)
                    .lineLimit(2)
                Text(q.text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(P.text)
                    .lineLimit(7)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HStack(spacing: 6) {
                    NextButton(answered: feedback != nil)
                    if let feedback { ResultBadge(feedback: feedback) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack(spacing: 3) {
                ForEach(q.options.indices, id: \.self) { i in
                    OptionButton(q: q, index: i, feedback: feedback, fontSize: 10, badge: 14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .invalidatableContent()
        }
        .id(q.id)
        .transition(.push(from: .trailing))
    }
}

private struct LargeQuestionView: View {
    let q: WidgetQuestion
    let feedback: WidgetQuestionFeedback?
    let tally: QuestionWidgetStorage.DayTally

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Caption(q: q, size: 11)
                Spacer(minLength: 4)
                if let feedback { ResultBadge(feedback: feedback, size: 11) }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(q.text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(P.text)
                    .lineLimit(7)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 5) {
                    ForEach(q.options.indices, id: \.self) { i in
                        OptionButton(q: q, index: i, feedback: feedback, fontSize: 12.5, badge: 18)
                    }
                }
                .frame(maxHeight: .infinity)
                .invalidatableContent()
            }
            .id(q.id)
            .transition(.push(from: .trailing))
            HStack(spacing: 10) {
                stat("checkmark.circle.fill", tally.correct, P.success)
                stat("xmark.circle.fill", tally.wrong, P.danger)
                Text("bu gün")
                    .font(.system(size: 11))
                    .foregroundStyle(P.muted)
                Spacer(minLength: 4)
                NextButton(answered: feedback != nil, size: 12)
            }
        }
    }

    private func stat(_ icon: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(P.text)
                .contentTransition(.numericText(value: Double(value)))
        }
    }
}

private struct EmptyQuestionView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.system(size: 24))
                .foregroundStyle(P.accent)
            Text("Sualları yükləmək üçün tətbiqi bir dəfə aç")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(P.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension QuestionEntry {
    static let sample = QuestionEntry(
        date: Date(),
        question: WidgetQuestion(
            id: "sample", subject: "Reklam Grafiği", unitLabel: "Ünitə 3",
            text: "Reklamda hedef kitlenin dikkatini ilk anda çeken öge aşağıdakilerden hangisidir?",
            options: ["Başlık", "Slogan", "Logo", "Gövde metni", "Kurumsal kimlik"],
            correctIndex: 0, srcC: "", srcU: 0, srcQ: "", srcO: [], srcA: 0),
        feedback: nil,
        tally: .init(day: "", correct: 0, wrong: 0))
}
