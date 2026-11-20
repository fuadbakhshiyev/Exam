import SwiftUI

/// Subject page (renderCoursePage): Bölmələr / Qarışıq sınaq / Vize tabs. Its numbers live in Statistika.
struct CourseView: View {
    let course: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    enum Tab: Hashable { case units, mixed, exams }
    @State private var tab: Tab = .units

    var body: some View {
        let page = store.coursePage(course)
        List {
            SegmentedSection(items: [(Tab.units, "Bölmələr"), (.mixed, "Qarışıq sınaq"), (.exams, "Vize")], selection: $tab)
            switch tab {
            case .units: units(page)
            case .mixed:
                MixSection(title: "Qarışıq sınaq",
                           description: "Fənnin ünitələrindən 20 qarışıq sual, əvvəlcə hələ işlənməmiş suallar. İmtahan kimi qiymətləndirilir: 100 bal, 4 səhv 1 düzü aparır; taymer işləyir.",
                           info: page.mixTab) { router.start(.courseMixed(course)) }
            case .exams:
                PdfExamsSection(subject: course, title: "Vize imtahanları")
            }
        }
        .appListStyle()
        .pageTitle(course, subtitle: page.subtitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Statistika", systemImage: "chart.bar.xaxis") { router.openStats(course) }
            }
        }
    }

    /// Review rows (Səhvlərin təkrarı, Mixed-only) on top, then the numbered units.
    @ViewBuilder private func units(_ page: CoursePage) -> some View {
        if SubjectSummaries.summary(for: course) != nil {
            Section {
                SummaryRow { router.push(.summary(course)) }
            }
        }
        Section {
            AllQuestionsRow(count: store.allSubjectQuestions(course).count, mode: store.examMode) {
                router.start(.allQuestions(course))
            }
            let m = store.masteryProgress(course)
            UnlearnedRow(learned: m.learned, total: m.total) { router.start(.unlearned(course)) }
        } footer: {
            Text(store.examMode == .vize
                 ? "1–7-ci ünitələrin bütün sualları (Mixed və keçmiş vizelərdə təkrarlananlar bir dəfə), qarışıq. Sual 2 dəfə ardıcıl düz cavablananda öyrənilmiş sayılır."
                 : "Bütün ünitələrin sualları (Mixed və keçmiş imtahanlarda təkrarlananlar bir dəfə), qarışıq. Sual 2 dəfə ardıcıl düz cavablananda öyrənilmiş sayılır.")
        }
        let sortable = store.sortableQuestions(course)
        let dc = DifficultyStore.shared.counts(sortable)
        Section {
            SortRow(total: sortable.count, easy: dc.easy, hard: dc.hard) { router.push(.sortQuestions(course)) }
            HardRow(hard: dc.hard) { router.start(.hardQuestions(course)) }
        } footer: {
            Text("Bütün suallara (köhnə imtahan sualları da daxil) cavabı ilə bax, hər birini \"Asan\" və ya \"Çətin\" kimi qeyd et. Sonra yalnız çətinləri öyrən.")
        }
        let old = store.oldExamQuestions(course).count
        if old > 0 {
            Section {
                let topics = store.oldExamTopics(course).count
                OldExamRow(count: old, topics: topics) {
                    if topics > 1 { router.push(.oldExams(course)) } else { router.start(.oldExamQuestions(course, topic: nil)) }
                }
            } footer: {
                Text("Keçmiş imtahanlarda çıxan, amma indiki ünitələrin heç birində olmayan suallar. Çoxu köhnə kitabdandır; \"Bütün suallar\"a və öyrənmə sayına daxil deyil.")
            }
        }
        if page.multi.wrongCount > 0 || page.mixedOnlyRow != nil {
            Section {
                if page.multi.wrongCount > 0 {
                    MultiLeadRow(multi: page.multi) { router.start(.multi(course: course)) }
                }
                if let mo = page.mixedOnlyRow {
                    StudyRow(row: mo, glyph: .symbol("square.stack.3d.up.fill", Theme.accent))
                }
            }
        }
        Section {
            if page.units.isEmpty {
                EmptyRow(title: "Bölmə tapılmadı", systemImage: "list.number")
            } else {
                let statuses = Dictionary(store.unitStatuses(course).map { ($0.unit, $0) }, uniquingKeysWith: { a, _ in a })
                ForEach(Array(page.units.enumerated()), id: \.element.id) { i, r in
                    let n = unitNumber(r, fallback: i)
                    StudyRow(row: r, glyph: .number(n), mastery: statuses[n])
                }
            }
        } header: {
            Text("Bölmələr")
        } footer: {
            if !page.units.isEmpty {
                Text("Nömrənin ətrafındakı xətt: yaşıl — düz bildiyin suallar, qırmızı — səhv etdiklərin, boz — hələ işlənməyənlər. Nömrənin rəngi bildiyin payı göstərir: yaşıl yaxşı, narıncı orta, qırmızı zəif.")
            }
        }
    }

    private func unitNumber(_ r: StudyListRow, fallback i: Int) -> Int {
        if case .unit(_, let idx) = r.target { return idx + 1 }
        return i + 1
    }
}

/// "Bütün suallar  136 sual ▶" — the subject's whole question set as one shuffled test.
private struct AllQuestionsRow: View {
    let count: Int
    let mode: ExamMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s12) {
                IconTile(symbol: "square.stack.3d.down.right.fill", color: Theme.accent, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bütün suallar").font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                    Text("\(count) sual · \(mode == .vize ? "Unit 1–7" : "Unit 1–14") · qarışıq")
                        .font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.fill").font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .appRow()
        .accessibilityLabel("Bütün suallar, \(count) sual")
    }
}

/// "Xülasə ›" — the subject's study sheet, unit by unit.
private struct SummaryRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s12) {
                IconTile(symbol: "doc.text.fill", color: Theme.success, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Xülasə").font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                    Text("Ünitələrin qısa konspekti və tələ suallar")
                        .font(.caption).foregroundStyle(Theme.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textMuted)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appRow()
    }
}

/// "Sualları çeşidlə  40 / 215 qeyd olunub ›"
private struct SortRow: View {
    let total: Int
    let easy: Int
    let hard: Int
    let action: () -> Void

    var body: some View {
        let marked = easy + hard
        Button(action: action) {
            HStack(spacing: Theme.Space.s12) {
                IconTile(symbol: "hand.raised.fingers.spread.fill", color: Theme.warning, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sualları çeşidlə").font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                    ProgressLine(fraction: total > 0 ? Double(marked) / Double(total) : 0, height: 4)
                    Text(marked == 0 ? "\(total) sual · asan və ya çətin kimi qeyd et"
                                     : "\(marked) / \(total) qeyd olunub · \(easy) asan · \(hard) çətin")
                        .font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textMuted)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(total == 0)
        .appRow()
        .accessibilityLabel("Sualları çeşidlə, \(marked) / \(total) qeyd olunub, \(hard) çətin")
    }
}

/// "Çətinləri öyrən  12 sual ▶" — the questions marked Çətin, shuffled.
private struct HardRow: View {
    let hard: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s12) {
                IconTile(symbol: "flame.fill", color: Theme.danger, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Çətinləri öyrən").font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                    Text(hard == 0 ? "Hələ çətin kimi qeyd olunmuş sual yoxdur" : "\(hard) sual · qarışıq")
                        .font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.fill").font(.footnote.weight(.semibold))
                    .foregroundStyle(hard == 0 ? Theme.textCaption : Theme.accent)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(hard == 0)
        .appRow()
        .accessibilityLabel("Çətinləri öyrən, \(hard) sual")
    }
}

/// "Köhnə imtahan sualları  127 sual ▶" — past-exam questions that match no unit question.
private struct OldExamRow: View {
    let count: Int
    let topics: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s12) {
                IconTile(symbol: "clock.arrow.circlepath", color: .gray, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Köhnə imtahan sualları").font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                    Text(topics > 1 ? "\(count) sual · \(topics) mövzu · ünitələrdə yoxdur" : "\(count) sual · ünitələrdə yoxdur · qarışıq")
                        .font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: topics > 1 ? "chevron.right" : "play.fill").font(.footnote.weight(.semibold))
                    .foregroundStyle(topics > 1 ? Theme.textMuted : Theme.accent)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appRow()
        .accessibilityLabel("Köhnə imtahan sualları, \(count) sual")
    }
}

/// "Öyrənilməmişlər  44 sual qalıb" + a learned bar (92 / 136 öyrənilib).
private struct UnlearnedRow: View {
    let learned: Int
    let total: Int
    let action: () -> Void

    var body: some View {
        let left = max(0, total - learned)
        Button(action: action) {
            HStack(spacing: Theme.Space.s12) {
                IconTile(symbol: left == 0 ? "checkmark.seal.fill" : "graduationcap.fill",
                         color: left == 0 ? Theme.success : .orange, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Öyrənilməmişlər").font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                        Spacer(minLength: 4)
                        Text(left == 0 ? "Hamısı öyrənilib ✓" : "\(left) sual qalıb")
                            .font(.subheadline).monospacedDigit()
                            .foregroundStyle(left == 0 ? Theme.success : Theme.textMuted)
                    }
                    ProgressLine(fraction: total > 0 ? Double(learned) / Double(total) : 0, height: 4)
                    Text("\(learned) / \(total) öyrənilib").font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(left == 0)
        .appRow()
        .accessibilityLabel("Öyrənilməmişlər, \(left) sual qalıb, \(learned) / \(total) öyrənilib")
    }
}

/// Fənn → Köhnə imtahan sualları: the past-exam questions found in no unit, by topic.
/// "Hamısı" runs all of them; a topic row runs that topic. Each row shows how many are learned.
struct OldExamTopicsView: View {
    let subject: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let topics = store.oldExamTopics(subject)
        let total = topics.reduce(0) { $0 + $1.questions.count }
        List {
            Section {
                row(title: "Hamısı", symbol: "square.stack.3d.down.right.fill", color: Theme.accent,
                    questions: topics.flatMap(\.questions)) { router.start(.oldExamQuestions(subject, topic: nil)) }
            } footer: {
                Text("Keçmiş imtahanlarda çıxan, amma indiki ünitələrin heç birində olmayan suallar. Çoxu köhnə kitabdandır.")
            }
            Section {
                ForEach(Array(topics.enumerated()), id: \.element.name) { i, t in
                    row(title: t.name, number: i + 1, questions: t.questions) {
                        router.start(.oldExamQuestions(subject, topic: t.name))
                    }
                }
            } header: {
                Text("Mövzular")
            }
        }
        .appListStyle()
        .pageTitle("Köhnə imtahan sualları", subtitle: "\(subject) · \(total) sual")
    }

    @ViewBuilder
    private func row(title: String, symbol: String? = nil, color: Color = Theme.accent, number: Int? = nil,
                     questions: [Question], action: @escaping () -> Void) -> some View {
        let m = MasteryStore.shared
        let learned = questions.filter { m.isLearned($0) }.count
        Button(action: action) {
            HStack(spacing: Theme.Space.s12) {
                if let symbol {
                    IconTile(symbol: symbol, color: color, size: 36)
                } else if let number {
                    Text(String(format: "%02d", number))
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 36, height: 36)
                        .background(Theme.textMuted.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressLine(fraction: questions.isEmpty ? 0 : Double(learned) / Double(questions.count), height: 4)
                    Text("\(questions.count) sual · \(learned) öyrənilib").font(.caption).monospacedDigit()
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.fill").font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appRow()
        .accessibilityLabel("\(title), \(questions.count) sual, \(learned) öyrənilib")
    }
}
