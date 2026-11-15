import SwiftUI
import Charts

// Shared pieces of the study pages, built on native List rows (cp-mix, cp-list). Numbers live in Statistika.

extension RowTarget {
    /// The page this row navigates to; nil → the row starts a quiz.
    var route: Route? {
        switch self {
        case .mixedSubject(let s): return .mixedSubject(s)
        case .pdfSubject(let s): return .pdfSubject(s)
        case .course(let c):
            if c == Catalog.mixedKey { return .mixed }
            if c == Catalog.overallKey { return .overall }
            return .course(c)
        case .unit, .pdfExam, .pdfExamWrong, .pdfFrequent, .mixedOnly: return nil
        }
    }
}

/// Native segmented tab switch in its own clear section.
struct SegmentedSection<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T

    var body: some View {
        Section {
            Picker("Bölmə", selection: $selection.animation(.snappy(duration: 0.25))) {
                ForEach(items, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}

/// cp-mix: description, LabeledContent numbers and the start button.
struct MixSection: View {
    let title: String
    let description: String
    let info: MixTabInfo
    var countLabel: String = "Sual sayı"
    let action: () -> Void

    var body: some View {
        Section {
            LabeledContent(countLabel, value: info.questionCount).appRow()
            LabeledContent("Mənbə", value: info.sources).appRow()
            LabeledContent("Hələ işlənməmiş sual", value: "\(info.notYetAnswered)").appRow()
            if let last = info.last {
                if let subject = info.historySubject {
                    NavigationLink { MixedHistoryView(subject: subject) } label: {
                        LabeledContent("Son sınaq", value: last)
                    }
                    .appRow()
                } else {
                    LabeledContent("Son sınaq", value: last).appRow()
                }
            }
        } header: {
            Text(title)
        } footer: {
            Text(description)
        }
        Section {
            Button(action: action) {
                Text("Sınağa başla").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .largeControl()
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}

/// Leading glyph of a row. Subject-level rows keep the subject glyph; rows inside a subject page
/// (units, Mixed parts, pdf exams) get a two-digit number badge, special rows a small SF Symbol.
enum RowGlyph {
    case emoji(String)
    case subject(String)
    case number(Int)
    case symbol(String, Color)
}

/// Leading badge of a row inside a subject page: "01", "02", … (or an SF Symbol for special rows) in a
/// subtle rounded rect. Untouched → neutral, in progress → accent tint, completed → green tint + check.
struct UnitBadge: View {
    var number: Int? = nil
    var symbol: String? = nil
    var symbolTint: Color = Theme.textCaption
    /// 0…1 share of the row's questions answered (ignored for symbols).
    var progress: Double = 0
    /// Per-question last results of a unit: drawn as a ring (green known, red weak, grey untouched)
    /// and the badge is tinted by how well the answered questions are known.
    var mastery: UnitStatus? = nil
    @ScaledMetric(relativeTo: .subheadline) private var side: CGFloat = 36

    private static let ringWidth: CGFloat = 3
    private static let ringGap: CGFloat = 2

    /// Answered questions known: strong ≥ 80 %, fair ≥ 50 %, weak below.
    private var strengthTint: Color? {
        guard let m = mastery, m.answered > 0 else { return nil }
        let acc = Double(m.correct) / Double(m.answered)
        return acc >= 0.8 ? Theme.success : (acc >= 0.5 ? Theme.warning : Theme.danger)
    }
    private var allKnown: Bool { mastery.map { $0.total > 0 && $0.correct >= $0.total } ?? false }

    private enum Stage { case untouched, started, done }
    private var stage: Stage {
        guard number != nil else { return .untouched }
        return progress >= 1 ? .done : (progress > 0 ? .started : .untouched)
    }
    private var fill: Color {
        if mastery != nil { return strengthTint?.opacity(0.14) ?? Theme.surfaceInner }
        return switch stage {
        case .untouched: Theme.surfaceInner
        case .started: Theme.accent.opacity(0.14)
        case .done: Theme.success.opacity(0.16)
        }
    }
    private var ink: Color {
        if mastery != nil { return strengthTint ?? Theme.textCaption }
        return switch stage {
        case .untouched: Theme.textCaption
        case .started: Theme.accent
        case .done: Theme.success
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
        ZStack {
            shape.fill(fill)
            if let number {
                Text(verbatim: String(format: "%02d", number))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(ink)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(symbolTint)
            }
        }
        .frame(width: side, height: side)
        .overlay {
            if let mastery { ring(mastery) }
        }
        .padding(mastery != nil ? Self.ringWidth + Self.ringGap : 0)
        .overlay(alignment: .bottomTrailing) {
            if mastery != nil ? allKnown : stage == .done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: side * 0.36, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Theme.success)
                    .background(Circle().fill(Theme.surface).padding(-1.5))
                    .offset(x: side * 0.12, y: side * 0.12)
            }
        }
        .accessibilityHidden(true)
    }

    /// Concentric ring just outside the badge: correct share, then wrong share, on a faint track.
    private func ring(_ m: UnitStatus) -> some View {
        let outset = Self.ringGap + Self.ringWidth / 2
        let shape = RoundedRectangle(cornerRadius: side * 0.28 + outset, style: .continuous)
        let total = Double(max(m.total, 1))
        let ok = min(1, Double(m.correct) / total)
        let bad = min(1 - ok, Double(m.wrong) / total)
        let style = StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round)
        return ZStack {
            shape.stroke(Theme.surfaceInner, lineWidth: Self.ringWidth)
            if ok > 0 { shape.trim(from: 0, to: ok).stroke(Theme.success, style: style) }
            if bad > 0 { shape.trim(from: ok, to: ok + bad).stroke(Theme.danger, style: style) }
        }
        .padding(-outset)
        .animation(.snappy, value: m)
    }
}

extension RowGlyph {
    @ViewBuilder func tile(progress: Double, mastery: UnitStatus? = nil) -> some View {
        switch self {
        case .emoji(let e): LogoTile(emoji: e, size: 36)
        case .subject(let c): SubjectIcon(course: c, size: 36)
        case .number(let n): UnitBadge(number: n, progress: progress, mastery: mastery)
        case .symbol(let s, let c): UnitBadge(symbol: s, symbolTint: c)
        }
    }
    var isNumbered: Bool { if case .number = self { true } else { false } }
}

/// Content of one cpList row: name, size / done state, last tested and (subject rows) a thin progress line.
/// Accuracy and correct / wrong counts are in the Statistika tab.
struct StudyRowContent: View {
    let row: StudyListRow
    let glyph: RowGlyph
    var mastery: UnitStatus? = nil

    private var hasData: Bool { row.done > 0 }
    private var isDone: Bool { row.total > 0 && row.done >= row.total }
    private var fraction: Double { row.total > 0 ? min(1, Double(row.done) / Double(row.total)) : 0 }

    private var subtitle: String {
        var parts: [String] = []
        if var e = row.extra {
            // "0 / 4 imtahan" → "4 imtahan" while nothing is done yet.
            if e.hasPrefix("0 / ") { e.removeFirst(4) }
            parts.append(e)
        }
        if hasData && row.total > 0 && !isDone {
            parts.append("\(row.done)/\(row.total)")
        } else {
            parts.append("\(row.total) sual")
        }
        return parts.joined(separator: " · ")
    }

    private var masteryLabel: String? {
        guard let m = mastery else { return nil }
        return "\(m.correct) düz, \(m.wrong) səhv, \(m.unanswered) işlənməyib"
    }

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            glyph.tile(progress: fraction, mastery: mastery)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.name).font(.body).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer(minLength: 4)
                    // Numbered badges show the done state themselves.
                    if isDone && !glyph.isNumbered {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                    }
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(subtitle).font(.caption).foregroundStyle(Theme.textMuted).monospacedDigit().lineLimit(1)
                    Spacer(minLength: 4)
                    if hasData {
                        Text(row.lastStr).font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                            .layoutPriority(1)
                    }
                }
                if hasData && !isDone && !glyph.isNumbered {
                    ProgressLine(fraction: fraction, height: 3).padding(.top, 3)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(masteryLabel ?? (isDone ? "Tamamlanıb" : ""))
    }
}

/// A list row: NavigationLink for page targets, Button for quiz targets; red "Səhvlər" action when available.
struct StudyRow: View {
    let row: StudyListRow
    let glyph: RowGlyph
    var mastery: UnitStatus? = nil
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if let route = row.target.route {
                NavigationLink(value: route) { StudyRowContent(row: row, glyph: glyph, mastery: mastery) }
            } else {
                Button { router.open(row.target) } label: { StudyRowContent(row: row, glyph: glyph, mastery: mastery) }
                    .tint(Theme.text)
            }
        }
        .appRow()
        .modifier(BadActions(row: row))
    }
}

/// Swipe action + context menu for rows whose wrong answers can be repeated.
private struct BadActions: ViewModifier {
    let row: StudyListRow
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        if let bad = row.badTarget, row.bad > 0 {
            content
                .swipeActions(edge: .trailing) {
                    Button("Səhvlər", systemImage: "arrow.counterclockwise") { router.open(bad) }.tint(Theme.danger)
                }
                .contextMenu {
                    Button("Səhvləri təkrarla (\(row.bad))", systemImage: "arrow.counterclockwise") { router.open(bad) }
                }
        } else {
            content
        }
    }
}

/// cpMulti: the wrong-answer review lead row (hidden by callers when there are no wrong answers).
struct MultiLeadRow: View {
    let wrongCount: Int
    let subtitle: String
    var lastStr: String? = nil
    let action: () -> Void

    init(multi: MultiRow, action: @escaping () -> Void) {
        wrongCount = multi.wrongCount
        var parts: [String] = []
        if multi.hard > 0 { parts.append("\(multi.hard) çətin") }
        if multi.veryHard > 0 { parts.append("\(multi.veryHard) çox çətin") }
        subtitle = parts.isEmpty ? "Səhv cavabları yenidən işləyin" : parts.joined(separator: " · ")
        lastStr = multi.lastStr == "Heç vaxt" ? nil : multi.lastStr
        self.action = action
    }
    init(wrongCount: Int, subtitle: String, lastStr: String? = nil, action: @escaping () -> Void) {
        self.wrongCount = wrongCount; self.subtitle = subtitle; self.lastStr = lastStr; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s12) {
                UnitBadge(symbol: "arrow.triangle.2.circlepath", symbolTint: Theme.warning)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Səhvlərin təkrarı").font(.body).foregroundStyle(Theme.text).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(wrongCount) səhv").font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.danger).monospacedDigit()
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(subtitle).font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                        Spacer(minLength: 4)
                        if let lastStr { Text(lastStr).font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1) }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .tint(Theme.text)
        .appRow()
    }
}

/// buildPdfExamsHTML as a List section: Multi lead (if wrong answers), "Ən çox düşən suallar", then each exam.
struct PdfExamsSection: View {
    let subject: String
    var title: String = "İmtahanlar"
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let rows = store.pdfExamRows(subject)
        let wrong = store.pdfWrongCount(subject)
        let history = MixedExamHistory.shared.attempts(for: subject, vize: true)
        Section(title) {
            if rows.isEmpty {
                EmptyRow(title: "İmtahan tapılmadı", systemImage: "doc.text.magnifyingglass")
            } else {
                NavigationLink { MixedHistoryView(subject: subject, vize: true) } label: {
                    HStack(spacing: Theme.Space.s12) {
                        UnitBadge(symbol: "chart.line.uptrend.xyaxis", symbolTint: Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nəticələr").font(.body).foregroundStyle(Theme.text)
                            Text(history.first.map { "Son: \(ResultView.points($0.score)) bal · \(history.count) sınaq" }
                                 ?? "Hər vizenin balı və inkişaf qrafiki")
                                .font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .appRow()
                if wrong > 0 {
                    MultiLeadRow(wrongCount: wrong, subtitle: "Bütün vize imtahanlarındakı səhvlər") {
                        router.start(.pdfSubjectAllWrong(subject))
                    }
                }
                ForEach(rows) { r in
                    StudyRow(row: r, glyph: {
                        if case .pdfExam(_, let idx) = r.target { return .number(idx + 1) }
                        return .symbol("flame.fill", Theme.warning)   // "Ən çox düşən suallar"
                    }())
                }
            }
        }
    }
}

/// hx-empty inside a list: native ContentUnavailableView on a clear row.
struct EmptyRow: View {
    let title: String
    var systemImage: String = "tray"
    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage)
            .listRowBackground(Color.clear)
    }
}

extension View {
    /// Inline navigation bar title + subtitle of a pushed page.
    @ViewBuilder func pageTitle(_ title: String, subtitle: String? = nil,
                                displayMode: NavigationBarItem.TitleDisplayMode = .inline) -> some View {
        if let subtitle, !subtitle.isEmpty {
            navigationTitle(title).navigationSubtitle(subtitle).navigationBarTitleDisplayMode(displayMode)
        } else {
            navigationTitle(title).navigationBarTitleDisplayMode(displayMode)
        }
    }
}

/// Destructive "reset statistics" row with the web confirmation; clears the cloud copy when signed in.
struct ResetStatsButton: View {
    var title: String = "Statistikanı sıfırla"
    @Environment(StudyStore.self) private var store
    @Environment(SyncService.self) private var sync
    @State private var confirm = false
    @State private var resetting = false

    var body: some View {
        Button(role: .destructive) { confirm = true } label: {
            HStack {
                Text(title)
                if resetting { Spacer(); ProgressView() }
            }
        }
        .disabled(resetting)
        .appRow()
        .confirmationDialog("Bu semestrin bütün nəticələri silinəcək (hesaba daxil olmusunuzsa, buludda da)!",
                            isPresented: $confirm, titleVisibility: .visible) {
            Button("Sıfırla", role: .destructive) { reset() }
            Button("Ləğv et", role: .cancel) {}
        }
    }

    private func reset() {
        resetting = true
        Task {
            if sync.user != nil {
                do { try await sync.deleteCloud() } catch { print("Error deleting cloud data:", error) }
            }
            store.resetAll()
            resetting = false
        }
    }
}

/// "Son sınaq" → every finished mixed exam of a subject: best / average score and each attempt.
struct MixedHistoryView: View {
    let subject: String
    /// Past vize booklets instead of the 20-question mixed exam.
    var vize: Bool = false
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let list = MixedExamHistory.shared.attempts(for: subject, vize: vize)
        HealthPage {
            if list.isEmpty {
                ContentUnavailableView("Hələ bal yoxdur", systemImage: "list.number",
                                       description: Text(vize
                                           ? "Vize imtahanını bitirəndə balı burada saxlanacaq. Əvvəlki imtahanların balı yazılmayıb."
                                           : "Qarışıq sınağı bitirəndə nəticəsi burada saxlanacaq. Əvvəlki sınaqların balı yazılmayıb."))
                .frame(maxWidth: .infinity)
            } else {
                let best = list.map(\.score).max() ?? 0
                let avg = list.map(\.score).reduce(0, +) / Double(list.count)
                HStack(spacing: Theme.Space.s8) {
                    StatTile(label: "Son", value: ResultView.points(list[0].score), tone: tone(list[0].score))
                    StatTile(label: "Ən yaxşı", value: ResultView.points(best), tone: tone(best))
                    StatTile(label: "Ortalama", value: ResultView.points((avg * 10).rounded() / 10))
                }

                MixedProgressChart(attempts: Array(list.reversed()))

                HealthSectionTitle(text: "Sınaqlar (\(list.count))")
                HealthGroup {
                    ForEach(list) { a in
                        HStack(spacing: Theme.Space.s12) {
                            Text(ResultView.points(a.score))
                                .font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(tone(a.score))
                                .frame(minWidth: 52, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.date.formatted(.dateTime.day().month(.wide).hour().minute().locale(Locale(identifier: "az"))))
                                    .foregroundStyle(Theme.text)
                                if let exam = a.exam {
                                    Text(exam).font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
                                }
                                Text("\(a.correct) düz · \(a.wrong) səhv · \(a.blank) boş" + (a.seconds > 0 ? " · \(StatsFormat.duration(a.seconds))" : ""))
                                    .font(.footnote).monospacedDigit().foregroundStyle(Theme.textMuted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Theme.Space.s10)
                        .accessibilityElement(children: .combine)
                    }
                }
                Text("Bal: 100 üzərindən, 4 səhv 1 düzü aparır.")
                    .font(.footnote).foregroundStyle(Theme.textMuted).padding(.horizontal, Theme.Space.s4)
            }

            if !vize {
                Button { router.start(.courseMixed(subject)) } label: {
                    Label("Yeni sınaq", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .largeControl()
                .padding(.top, Theme.Space.s12)
            }
        }
        .navigationTitle(vize ? "Vize nəticələri" : "Qarışıq sınaq")
        .navigationSubtitle(subject)
        .navigationBarTitleDisplayMode(.large)
    }

    private func tone(_ v: Double) -> Color { v >= 85 ? Theme.success : (v >= 50 ? Theme.warning : Theme.danger) }
}

/// "İnkişaf": each mixed exam's score as points on a line, the running average as a second line,
/// and the overall average as a dashed rule. Drag to read one attempt.
struct MixedProgressChart: View {
    /// Oldest first.
    let attempts: [MixedExamAttempt]
    @State private var selected: Int?

    private struct Point: Identifiable {
        let id: Int
        let score: Double
        let average: Double
        let date: Date
        let label: String
    }

    var body: some View {
        let pts = points
        let avg = pts.last?.average ?? 0
        let first = pts.first?.average ?? 0
        let pick = selected.flatMap { s in pts.first { $0.id == s } }
        VStack(alignment: .leading, spacing: Theme.Space.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pick.map { $0.label.uppercased(with: Locale(identifier: "az")) } ?? "ORTALAMA").font(.caption.weight(.semibold)).foregroundStyle(Theme.textMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(ResultView.points(((pick?.score ?? avg) * 10).rounded() / 10))
                        .font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                    Text("bal").font(.headline).foregroundStyle(Theme.textMuted)
                }
                Text(pick.map { "\($0.date.formatted(.dateTime.day().month(.wide).hour().minute().locale(Locale(identifier: "az")))) · ortalama \(ResultView.points(($0.average * 10).rounded() / 10))" }
                     ?? trendText(first: first, avg: avg, count: pts.count))
                    .font(.subheadline).foregroundStyle(Theme.textMuted)
            }
            .animation(.snappy, value: selected)

            if pts.count >= 2 {
                Chart {
                    ForEach(pts) { p in
                        LineMark(x: .value("Sınaq", p.id), y: .value("Bal", p.score), series: .value("Növ", "Bal"))
                            .foregroundStyle(Theme.accent.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        PointMark(x: .value("Sınaq", p.id), y: .value("Bal", p.score))
                            .foregroundStyle(Theme.accent)
                            .symbolSize(pts.count > 20 ? 18 : 36)
                        LineMark(x: .value("Sınaq", p.id), y: .value("Bal", p.average), series: .value("Növ", "Ortalama"))
                            .foregroundStyle(Theme.success)
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    RuleMark(y: .value("Keçid", 50))
                        .foregroundStyle(Theme.textMuted.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("50").font(.caption2).foregroundStyle(Theme.textMuted)
                        }
                    if let s = selected {
                        RuleMark(x: .value("Seçilmiş", s)).foregroundStyle(Theme.textMuted.opacity(0.5))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXScale(domain: 1...max(pts.count, 2))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(pts.count, 6))) { v in
                        AxisGridLine().foregroundStyle(Theme.border)
                        AxisValueLabel { if let i = v.as(Int.self) { Text("\(i)") } }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, 25, 50, 75, 100]) { _ in
                        AxisGridLine().foregroundStyle(Theme.border)
                        AxisValueLabel()
                    }
                }
                .chartXSelection(value: $selected)
                .frame(height: 200)

                HStack(spacing: Theme.Space.s12) {
                    CountDot(text: "Sınaq balı", color: Theme.accent)
                    CountDot(text: "Ortalama", color: Theme.success)
                }
                .font(.caption)
            } else {
                Text("Qrafik üçün ən azı 2 sınaq lazımdır.").font(.footnote).foregroundStyle(Theme.textMuted)
            }
        }
        .padding(Theme.Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var points: [Point] {
        var sum = 0.0
        return attempts.enumerated().map { i, a in
            sum += a.score
            return Point(id: i + 1, score: a.score, average: sum / Double(i + 1), date: a.date,
                         label: a.exam.map { "\($0) · sınaq \(i + 1)" } ?? "Sınaq \(i + 1)")
        }
    }

    /// "İlk 3 sınaqdan bəri ortalama 12 bal artıb."
    private func trendText(first: Double, avg: Double, count: Int) -> String {
        guard count >= 2 else { return "\(count) sınaq" }
        let recent = attempts.suffix(3).map(\.score).reduce(0, +) / Double(min(3, attempts.count))
        let diff = Int((recent - avg).rounded())
        if diff > 0 { return "\(count) sınaq · son sınaqlar ortalamadan \(diff) bal yüksəkdir" }
        if diff < 0 { return "\(count) sınaq · son sınaqlar ortalamadan \(-diff) bal aşağıdır" }
        return "\(count) sınaq · nəticələr sabitdir"
    }
}
