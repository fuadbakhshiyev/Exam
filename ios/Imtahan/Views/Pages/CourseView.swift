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
                           description: "Fənnin bütün bölmələrindən qarışıq 20 suallıq sürətli sınaq. Başlamaq üçün düyməyə basın.",
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
        Section {
            AllQuestionsRow(count: store.allSubjectQuestions(course).count, mode: store.examMode) {
                router.start(.allQuestions(course))
            }
        } footer: {
            Text(store.examMode == .vize
                 ? "1–7-ci ünitələrin, Mixed-in və keçmiş vize imtahanlarının bütün sualları, təkrarsız və qarışıq."
                 : "Bütün ünitələrin, Mixed-in və keçmiş imtahanların bütün sualları, təkrarsız və qarışıq.")
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
                ForEach(Array(page.units.enumerated()), id: \.element.id) { i, r in
                    StudyRow(row: r, glyph: .number(unitNumber(r, fallback: i)))
                }
            }
        } header: {
            Text("Bölmələr")
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
