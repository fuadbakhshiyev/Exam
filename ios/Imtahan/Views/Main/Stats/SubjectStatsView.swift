import SwiftUI

/// One subject (its pdf exams included), Mixed or the mock exam in detail:
/// summary → answers to review → breakdown per unit / part / exam → open the subject.
struct SubjectStatsView: View {
    let key: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    private var isMock: Bool { key == Catalog.mockKey }

    var body: some View {
        let r = store.subjectStatsRow(key)
        let sections = store.statsLineSections(key)
        let pdfRows = isMock ? [] : store.pdfExamRows(key).filter { if case .pdfFrequent = $0.target { false } else { true } }
        List {
            // Summary
            Section {
                AccuracySummaryRow(answered: r.answered, total: r.total, correct: r.correct, wrong: r.wrong)
                    .appRow()
                ValueRow(title: "Sərf edilən vaxt", symbol: "clock", value: StatsFormat.duration(r.time))
                    .appRow()
                ValueRow(title: "Son test", symbol: "calendar",
                         value: StudyStore.formatLastTested(r.lastTested, hasData: r.answered > 0))
                    .appRow()
            }

            // Answers (tap to review; the mock exam has no review list)
            if r.answered > 0 {
                Section {
                    if isMock {
                        ValueRow(title: "Düz cavablar", symbol: "checkmark.circle.fill", value: "\(r.correct)", tint: Theme.success)
                            .appRow()
                        ValueRow(title: "Səhv cavablar", symbol: "xmark.circle.fill", value: "\(r.wrong)", tint: Theme.danger)
                            .appRow()
                    } else {
                        ReviewCountRow(title: "Düz cavablar", count: r.correct, symbol: "checkmark.circle.fill", tint: Theme.success) {
                            router.start(.reviewCourse(course: key, correct: true))
                        }
                        ReviewCountRow(title: "Səhv cavablar", count: r.wrong, symbol: "xmark.circle.fill", tint: Theme.danger) {
                            router.start(.reviewCourse(course: key, correct: false))
                        }
                    }
                } header: {
                    Text("Cavablar")
                } footer: {
                    if !isMock { Text("Cavabları yenidən işləmək üçün toxunun.") }
                }
            }

            // Breakdown
            ForEach(sections) { s in
                Section(s.title) {
                    ForEach(s.lines) { l in
                        StatsLineRow(title: l.title, correct: l.correct, wrong: l.wrong,
                                     total: l.answered, detail: StudyStore.formatLastTested(l.last, hasData: l.answered > 0))
                            .appRow()
                    }
                }
            }

            if !pdfRows.isEmpty {
                Section("Vize imtahanları") {
                    ForEach(pdfRows) { p in
                        StatsLineRow(title: p.name, correct: p.ok, wrong: p.bad, total: max(p.total, p.done),
                                     detail: p.done > 0 ? "\(min(p.done, p.total))/\(p.total) · \(p.lastStr)" : "\(p.total) sual · işlənməyib")
                            .appRow()
                    }
                }
            }

            Section {
                Button {
                    if isMock { router.start(.mock) } else { router.openSubjectPage(key) }
                } label: {
                    Label(isMock ? "Böyük sınağa başla" : "Fənnə keç", systemImage: isMock ? "play.fill" : "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .largeControl()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .appListStyle()
        .pageTitle(StatsFormat.title(key), subtitle: "\(store.examMode.title) rejimi")
    }
}
