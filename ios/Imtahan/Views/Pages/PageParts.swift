import SwiftUI

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
            LabeledContent("Hələ işlənməyib", value: "\(info.notYetAnswered)").appRow()
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
            .controlSize(.large)
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
    @ScaledMetric(relativeTo: .subheadline) private var side: CGFloat = 36

    private enum Stage { case untouched, started, done }
    private var stage: Stage {
        guard number != nil else { return .untouched }
        return progress >= 1 ? .done : (progress > 0 ? .started : .untouched)
    }
    private var fill: Color {
        switch stage {
        case .untouched: Theme.surfaceInner
        case .started: Theme.accent.opacity(0.14)
        case .done: Theme.success.opacity(0.16)
        }
    }
    private var ink: Color {
        switch stage {
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
        .overlay(alignment: .bottomTrailing) {
            if stage == .done {
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
}

extension RowGlyph {
    @ViewBuilder func tile(progress: Double) -> some View {
        switch self {
        case .emoji(let e): LogoTile(emoji: e, size: 36)
        case .subject(let c): SubjectIcon(course: c, size: 36)
        case .number(let n): UnitBadge(number: n, progress: progress)
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

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            glyph.tile(progress: fraction)
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
        .accessibilityValue(isDone ? "Tamamlanıb" : "")
    }
}

/// A list row: NavigationLink for page targets, Button for quiz targets; red "Səhvlər" action when available.
struct StudyRow: View {
    let row: StudyListRow
    let glyph: RowGlyph
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if let route = row.target.route {
                NavigationLink(value: route) { StudyRowContent(row: row, glyph: glyph) }
            } else {
                Button { router.open(row.target) } label: { StudyRowContent(row: row, glyph: glyph) }
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
        Section(title) {
            if rows.isEmpty {
                EmptyRow(title: "İmtahan tapılmadı", systemImage: "doc.text.magnifyingglass")
            } else {
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
