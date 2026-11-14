import SwiftUI
import Charts

// Building blocks of the Statistika detail pages, after Apple Health: a range picker and a big chart
// with its summary on top, then "Əsas məqamlar" (highlights) and grouped cards.

// MARK: - Data

enum StatsRange: Int, CaseIterable, Identifiable, Sendable {
    case week, month, all
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .week: "Həftə"
        case .month: "Ay"
        case .all: "Hamısı"
        }
    }
}

/// What the big chart plots.
enum StatsSeries: Sendable {
    /// Stacked correct / wrong answers per day.
    case answers
    /// Daily accuracy line (days without answers are gaps).
    case accuracy
    /// Minutes per day.
    case minutes
    /// Wrong answers per day.
    case wrong
}

extension StudyStore {
    /// Days of a range ending today (oldest first), in-scope history only; `course` narrows to one
    /// subject (its pdf / final booklets included).
    func statsDays(_ range: StatsRange, course: String? = nil, now: Date = Date()) -> [StatsDay] {
        let count: Int
        switch range {
        case .week: count = 7
        case .month: count = 30
        case .all:
            let first = data.history.keys.sorted().first.flatMap { Self.date(fromDayKey: $0) } ?? now
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: first),
                                                       to: Calendar.current.startOfDay(for: now)).day ?? 0
            count = min(max(days + 1, 7), 365)
        }
        return (0..<count).reversed().map { back in
            let date = Calendar.current.date(byAdding: .day, value: -back, to: now) ?? now
            let key = Self.dayKey(date)
            var c = 0, w = 0, t = 0
            for (k, v) in data.history[key]?.courses ?? [:] where historyKeyInScope(k) {
                if let course, QuestionBank.baseCourse(k) != course { continue }
                c += v.correct; w += v.wrong; t += v.time
            }
            return StatsDay(day: key, correct: c, wrong: w, seconds: t)
        }
    }
}

extension StatsDay {
    var date: Date { StudyStore.date(fromDayKey: day) ?? Date() }
    var minutes: Int { Int((Double(seconds) / 60).rounded()) }
}

// MARK: - Chart card

/// Range picker, the period's headline number, and the chart (drag to read a single day).
struct HealthChartCard: View {
    let series: StatsSeries
    let tint: Color
    var course: String? = nil
    @Environment(StudyStore.self) private var store
    @State private var range: StatsRange = .week
    @State private var selected: Date?

    var body: some View {
        let days = store.statsDays(range, course: course)
        let pick = selected.flatMap { s in days.first { Calendar.current.isDate($0.date, inSameDayAs: s) } }
        VStack(alignment: .leading, spacing: Theme.Space.s12) {
            Picker("Dövr", selection: $range) {
                ForEach(StatsRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            headline(days, pick)
                .contentTransition(.numericText())
                .animation(.snappy, value: pick?.day)

            chart(days)
                .frame(height: 200)
                .animation(.snappy, value: range)
        }
        .padding(Theme.Space.s16)
        .card()
        .onChange(of: range) { selected = nil }
    }

    // MARK: Headline

    private func headline(_ days: [StatsDay], _ pick: StatsDay?) -> some View {
        let (caption, value, unit) = pick.map(dayValue) ?? summary(days)
        return VStack(alignment: .leading, spacing: 2) {
            Text(caption.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(Theme.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Theme.text)
                Text(unit).font(.headline).foregroundStyle(Theme.textMuted)
            }
            Text(pick.map { Self.dayText($0.date) } ?? Self.rangeText(days))
                .font(.subheadline).foregroundStyle(Theme.textMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private func summary(_ days: [StatsDay]) -> (String, String, String) {
        let active = days.filter { $0.answered > 0 || $0.seconds > 0 }
        switch series {
        case .answers:
            return ("Cəmi", "\(days.reduce(0) { $0 + $1.answered })", "sual")
        case .wrong:
            return ("Cəmi", "\(days.reduce(0) { $0 + $1.wrong })", "səhv")
        case .accuracy:
            let c = days.reduce(0) { $0 + $1.correct }, n = days.reduce(0) { $0 + $1.answered }
            return ("Ortalama", n > 0 ? "\(StudyStore.pct(c, n))" : "—", n > 0 ? "%" : "")
        case .minutes:
            let total = days.reduce(0) { $0 + $1.seconds }
            let avg = active.isEmpty ? 0 : total / active.count
            let v = StatisticsView.timeParts(avg)
            return ("Gündəlik ortalama", v.value, v.unit)
        }
    }

    private func dayValue(_ d: StatsDay) -> (String, String, String) {
        switch series {
        case .answers: ("\(d.correct) düz · \(d.wrong) səhv", "\(d.answered)", "sual")
        case .wrong: ("Səhv", "\(d.wrong)", "sual")
        case .accuracy: ("Dəqiqlik", d.accuracy.map { "\(Int($0.rounded()))" } ?? "—", d.accuracy == nil ? "" : "%")
        case .minutes: { let v = StatisticsView.timeParts(d.seconds); return ("Vaxt", v.value, v.unit) }()
        }
    }

    // MARK: Chart

    @ChartContentBuilder
    private func marks(_ d: StatsDay) -> some ChartContent {
        let x = PlottableValue.value("Gün", d.date, unit: .day)
        switch series {
        case .answers:
            BarMark(x: x, y: .value("Sual", d.correct))
                .foregroundStyle(by: .value("Növ", "Düz"))
            BarMark(x: x, y: .value("Sual", d.wrong))
                .foregroundStyle(by: .value("Növ", "Səhv"))
        case .wrong:
            BarMark(x: x, y: .value("Səhv", d.wrong)).foregroundStyle(tint)
        case .minutes:
            BarMark(x: x, y: .value("Dəq", d.minutes)).foregroundStyle(tint)
        case .accuracy:
            if let a = d.accuracy {
                LineMark(x: x, y: .value("%", a))
                    .foregroundStyle(tint)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                PointMark(x: x, y: .value("%", a)).foregroundStyle(tint).symbolSize(range == .week ? 40 : 14)
            }
        }
    }

    private func chart(_ days: [StatsDay]) -> some View {
        Chart {
            ForEach(days) { marks($0) }
            if let s = selected {
                RuleMark(x: .value("Seçilmiş", s, unit: .day))
                    .foregroundStyle(Theme.textMuted.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartForegroundStyleScale(["Düz": Theme.success, "Səhv": Theme.danger])
        .chartLegend(series == .answers ? .visible : .hidden)
        .chartLegend(position: .bottom, alignment: .leading)
        .chartYScale(domain: series == .accuracy ? 0...100 : 0...max(yMax(days), 4))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xStride(days.count))) { _ in
                AxisGridLine().foregroundStyle(Theme.border)
                AxisValueLabel(format: days.count <= 7 ? .dateTime.weekday(.abbreviated) : .dateTime.day().month(.abbreviated),
                               centered: days.count <= 7)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.border)
                AxisValueLabel()
            }
        }
        .environment(\.locale, Locale(identifier: "az"))
        .chartXSelection(value: $selected)
    }

    private func yMax(_ days: [StatsDay]) -> Int {
        days.map { d in
            switch series {
            case .answers: d.answered
            case .wrong: d.wrong
            case .minutes: d.minutes
            case .accuracy: 100
            }
        }.max() ?? 0
    }

    private func xStride(_ n: Int) -> Int { n <= 7 ? 1 : n <= 31 ? 7 : max(n / 5, 7) }

    static func dayText(_ d: Date) -> String {
        d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "az")))
    }

    static func rangeText(_ days: [StatsDay]) -> String {
        guard let a = days.first?.date, let b = days.last?.date else { return "" }
        let f = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(Locale(identifier: "az"))
        return "\(a.formatted(f)) – \(b.formatted(f.year()))"
    }
}

// MARK: - Highlights

struct Highlight: Identifiable {
    let id = UUID()
    let symbol: String
    let tint: Color
    let title: String
    let text: String
}

/// One "Əsas məqamlar" card: tinted title with its symbol, then a sentence.
struct HighlightCard: View {
    let item: Highlight
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s8) {
            Label(item.title, systemImage: item.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.tint)
                .symbolVariant(.fill)
            Text(item.text).font(.body).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }
}

extension StudyStore {
    /// This week vs the week before, the best day and the streak, as plain sentences.
    func statsHighlights(_ series: StatsSeries, course: String? = nil) -> [Highlight] {
        let days = statsDays(.month, course: course).suffix(14)
        let prev = Array(days.prefix(7)), cur = Array(days.suffix(7))
        func sum(_ d: [StatsDay], _ f: (StatsDay) -> Int) -> Int { d.reduce(0) { $0 + f($1) } }
        var out: [Highlight] = []

        switch series {
        case .answers, .wrong:
            let a = sum(cur, \.answered), b = sum(prev, \.answered)
            if a > 0 || b > 0 {
                let text: String
                if b == 0 { text = "Bu həftə \(a) sual işləmisiniz." }
                else if a >= b { text = "Bu həftə keçən həftədən \(a - b) sual çox işləmisiniz (\(a) / \(b))." }
                else { text = "Bu həftə keçən həftədən \(b - a) sual az işləmisiniz (\(a) / \(b))." }
                out.append(Highlight(symbol: a >= b ? "arrow.up.right.circle" : "arrow.down.right.circle",
                                     tint: .indigo, title: "Həftəlik müqayisə", text: text))
            }
            if series == .wrong {
                let w = sum(cur, \.wrong), n = sum(cur, \.answered)
                if n > 0 {
                    out.append(Highlight(symbol: "xmark.octagon", tint: Theme.danger, title: "Səhv payı",
                                         text: "Bu həftə hər 100 cavabdan \(StudyStore.pct(w, n))-i səhv olub."))
                }
            }
        case .accuracy:
            let ca = sum(cur, \.correct), na = sum(cur, \.answered)
            let cb = sum(prev, \.correct), nb = sum(prev, \.answered)
            if na > 0 {
                let a = StudyStore.pct(ca, na)
                let text = nb > 0
                    ? (a >= StudyStore.pct(cb, nb)
                       ? "Bu həftə dəqiqliyiniz \(a)% — keçən həftədən \(a - StudyStore.pct(cb, nb)) bənd yüksək."
                       : "Bu həftə dəqiqliyiniz \(a)% — keçən həftədən \(StudyStore.pct(cb, nb) - a) bənd aşağı.")
                    : "Bu həftə dəqiqliyiniz \(a)%."
                out.append(Highlight(symbol: "target", tint: Theme.success, title: "Həftəlik dəqiqlik", text: text))
            }
        case .minutes:
            let a = sum(cur, \.seconds), b = sum(prev, \.seconds)
            if a > 0 {
                let text = b > 0
                    ? "Bu həftə \(StatsFormat.duration(a)) oxumusunuz, keçən həftə \(StatsFormat.duration(b))."
                    : "Bu həftə \(StatsFormat.duration(a)) oxumusunuz."
                out.append(Highlight(symbol: "clock", tint: Theme.warning, title: "Həftəlik vaxt", text: text))
            }
        }

        if let best = days.max(by: { $0.answered < $1.answered }), best.answered > 0, series != .minutes {
            out.append(Highlight(symbol: "star", tint: .yellow, title: "Ən yaxşı gün",
                                 text: "\(HealthChartCard.dayText(best.date)): \(best.answered) sual, \(StudyStore.pct(best.correct, best.answered))% düz."))
        }
        if course == nil {
            let s = studyStreak()
            if s.days > 1 {
                out.append(Highlight(symbol: "flame", tint: .orange, title: "Ardıcıllıq",
                                     text: "\(s.days) gündür ardıcıl sual işləyirsiniz\(s.includesToday ? "" : " — bu gün də davam edin")."))
            }
        }
        return out
    }
}

// MARK: - Grouped card

/// A Health-style group: rows separated by inset dividers inside one card.
struct HealthGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content()) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.offset) { i, v in
                    v
                    if i < subviews.count - 1 { Divider().padding(.leading, 52) }
                }
            }
        }
        .padding(.horizontal, Theme.Space.s16)
        .card()
    }
}

/// Icon tile · title · value (· chevron); a button when `action` is given.
struct HealthRow: View {
    let title: String
    let symbol: String
    var tint: Color = Theme.accent
    var value: String? = nil
    /// Shows a chevron without an action (the row sits inside a NavigationLink).
    var chevron = false
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) { label(chevron: true) }.buttonStyle(.plain)
        } else {
            label(chevron: chevron)
        }
    }

    private func label(chevron: Bool) -> some View {
        HStack(spacing: Theme.Space.s12) {
            IconTile(symbol: symbol, color: tint)
            Text(title).foregroundStyle(Theme.text).lineLimit(2)
            Spacer(minLength: 8)
            if let value {
                Text(value).monospacedDigit().foregroundStyle(Theme.textMuted).lineLimit(1).fixedSize()
            }
            if chevron { Chevron() }
        }
        .padding(.vertical, Theme.Space.s12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Bold section title used between cards.
struct HealthSectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.title3.weight(.bold)).foregroundStyle(Theme.text)
            .padding(.top, Theme.Space.s12)
            .padding(.leading, Theme.Space.s4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// "Haqqında" footnote card.
struct HealthAbout: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(Theme.textMuted)
            .padding(Theme.Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
    }
}

/// Scroll container shared by every detail page.
struct HealthPage<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s12) { content() }
                .padding(.horizontal, Theme.Space.s16)
                .padding(.bottom, Theme.Space.s24)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg.ignoresSafeArea())
    }
}
