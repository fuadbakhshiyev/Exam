import SwiftUI

// Shared row anatomy of the Statistika tab and its detail pages:
// leading tinted SF Symbol · title · trailing value (· chevron when it opens something).

/// Accuracy ring + answered / total and a one-line share; a friendly line while nothing is answered.
struct AccuracySummaryRow: View {
    let answered: Int
    let total: Int
    let correct: Int
    let wrong: Int

    var body: some View {
        let acc = answered > 0 ? StudyStore.pct(correct, answered) : 0
        let denom = Double(max(answered, 1))
        HStack(spacing: Theme.Space.s16) {
            RingDial(accent: Double(correct) / denom, danger: Double(wrong) / denom, lineWidth: 8) {
                VStack(spacing: 0) {
                    Text(answered > 0 ? "\(acc)%" : "—").font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Theme.text)
                    Text("dəqiqlik").font(.system(size: 9)).foregroundStyle(Theme.textMuted)
                }
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(answered)).font(.title2.weight(.bold)).foregroundStyle(Theme.text)
                    Text(total > 0 ? "/ \(String(total)) sual" : "cavab").font(.subheadline).foregroundStyle(Theme.textMuted)
                }
                .monospacedDigit()
                .lineLimit(1)
                if total > 0 && answered > 0 {
                    SplitBar(total: max(total, answered), ok: correct, bad: wrong, height: 4)
                    Text("Sualların \(min(100, StudyStore.pct(answered, total)))%-i işlənib")
                        .font(.footnote).foregroundStyle(Theme.textMuted)
                } else if answered == 0 {
                    Text("Hələ başlanmayıb").font(.footnote).foregroundStyle(Theme.textMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Space.s4)
        .accessibilityElement(children: .combine)
    }
}

/// "Düz cavablar  123 ›" — starts a review of those answers.
struct ReviewCountRow: View {
    let title: String
    let count: Int
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                StatLabel(title: title, symbol: symbol, tint: tint)
                Spacer(minLength: 8)
                Text("\(count)").monospacedDigit().foregroundStyle(Theme.textMuted)
                Chevron()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .appRow()
    }
}

/// Icon + title on the left, a value on the right (never wraps the value under the title).
struct ValueRow: View {
    let title: String
    let symbol: String
    let value: String
    var tint: Color = Theme.accent
    var body: some View {
        // Side by side when it fits; otherwise the value moves under the title instead of truncating it.
        ViewThatFits(in: .horizontal) {
            HStack {
                StatLabel(title: title, symbol: symbol, tint: tint).fixedSize()
                Spacer(minLength: 8)
                valueText
            }
            VStack(alignment: .leading, spacing: 2) {
                StatLabel(title: title, symbol: symbol, tint: tint)
                valueText.padding(.leading, 40)
            }
        }
    }

    private var valueText: some View {
        Text(value).monospacedDigit().foregroundStyle(Theme.textMuted).lineLimit(1).fixedSize()
    }
}

/// Tinted symbol + title, the leading half of every Statistika row.
struct StatLabel: View {
    let title: String
    let symbol: String
    var tint: Color = Theme.accent
    var body: some View {
        Label {
            Text(title).foregroundStyle(Theme.text).lineLimit(1)
        } icon: {
            IconTile(symbol: symbol, color: tint)
        }
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold)).foregroundStyle(Theme.textMuted)
            .accessibilityHidden(true)
    }
}

struct CountDot: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).foregroundStyle(Theme.textValue).monospacedDigit()
        }
    }
}

/// A subject in "Fənlər": answered / total, accuracy and a thin correct / wrong bar once started.
struct SubjectStatsRowView: View {
    let row: SubjectStatsRow

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            SubjectIcon(course: row.key, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(StatsFormat.title(row.key)).font(.body).foregroundStyle(Theme.text).lineLimit(1)
                HStack(alignment: .firstTextBaseline) {
                    Text(subtitle).font(.caption).foregroundStyle(Theme.textMuted).monospacedDigit().lineLimit(1)
                    Spacer(minLength: 4)
                    if let acc = row.accuracy {
                        Text("\(acc)%").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(StatsFormat.tone(acc))
                    }
                }
                if row.total > 0 && row.answered > 0 {
                    SplitBar(total: max(row.total, row.answered), ok: row.correct, bad: row.wrong, height: 3)
                        .padding(.top, 3)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if row.total == 0 { return "\(row.answered) cavab" }
        if row.answered == 0 { return "\(row.total) sual · başlanmayıb" }
        return "\(min(row.answered, row.total))/\(row.total) işlənib"
    }
}

/// A unit / part / exam line: title + accuracy, "c · w" dots + detail, and a thin bar.
struct StatsLineRow: View {
    let title: String
    let correct: Int
    let wrong: Int
    let total: Int
    let detail: String

    var body: some View {
        let answered = correct + wrong
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.body).foregroundStyle(Theme.text).lineLimit(1)
                Spacer(minLength: 4)
                if answered > 0 {
                    let acc = StudyStore.pct(correct, answered)
                    Text("\(acc)%").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(StatsFormat.tone(acc))
                }
            }
            HStack(alignment: .firstTextBaseline) {
                if answered > 0 {
                    HStack(spacing: Theme.Space.s8) {
                        CountDot(text: "\(correct)", color: Theme.success)
                        CountDot(text: "\(wrong)", color: Theme.danger)
                    }
                }
                Spacer(minLength: 4)
                Text(detail).foregroundStyle(Theme.textMuted).lineLimit(1)
            }
            .font(.caption)
            if answered > 0 {
                SplitBar(total: max(total, answered), ok: correct, bad: wrong, height: 3).padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Formatting

enum StatsFormat {
    /// Seconds → "3 saat 40 dəq"; "1 dəq-dən az" / "0 dəq" below a minute.
    static func duration(_ seconds: Int) -> String {
        CompactFormat.duration(seconds) ?? (seconds > 0 ? "1 dəq-dən az" : "0 dəq")
    }

    /// Display name of a stats key (the mock key carries its emoji).
    static func title(_ key: String) -> String {
        key == Catalog.mockKey ? "Böyük sınaq" : key
    }

    static func tone(_ acc: Int) -> Color {
        acc >= 80 ? Theme.success : (acc < 60 ? Theme.danger : Theme.text)
    }
}

extension StatDetailType: Identifiable {
    var id: String { rawValue }

    var rowTitle: String {
        switch self {
        case .total: "İşlənən suallar"
        case .correct: "Düz cavablar"
        case .wrong: "Səhv cavablar"
        case .accuracy: "Dəqiqlik"
        case .time: "Vaxt"
        }
    }

    var symbol: String {
        switch self {
        case .total: "number"
        case .correct: "checkmark.circle"
        case .wrong: "xmark.circle"
        case .accuracy: "target"
        case .time: "clock"
        }
    }

    var tint: Color {
        switch self {
        case .correct: Theme.success
        case .wrong: Theme.danger
        default: Theme.accent
        }
    }

    var valueTint: Color {
        switch self {
        case .correct: Theme.success
        case .wrong: Theme.danger
        default: Theme.text
        }
    }
}
