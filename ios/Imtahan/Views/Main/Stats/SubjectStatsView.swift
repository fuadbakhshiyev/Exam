import SwiftUI

/// One subject (its pdf exams included), Mixed or the mock exam, Apple Health style:
/// summary → daily chart → highlights → answers to review → breakdown cards → open the subject.
struct SubjectStatsView: View {
    let key: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    private var isMock: Bool { key == Catalog.mockKey }
    private var isSubject: Bool { Catalog.subjects.contains(key) }

    var body: some View {
        let r = store.subjectStatsRow(key)
        let sections = store.statsLineSections(key)
        let pdfRows = isMock ? [] : store.pdfExamRows(key).filter { if case .pdfFrequent = $0.target { false } else { true } }
        HealthPage {
            AccuracySummaryRow(answered: r.answered, total: r.total, correct: r.correct, wrong: r.wrong)
                .padding(Theme.Space.s16).frame(maxWidth: .infinity, alignment: .leading).card()

            HealthGroup {
                if isSubject {
                    let dates = ExamDates.shared
                    let m = store.masteryProgress(key)
                    HealthRow(title: "İmtahan", symbol: "calendar", tint: .pink,
                              value: dates.isOver(key) ? "Bitib" : "\(dates.timeText(key)) · \(dates.daysLeft(key)) gün")
                    HealthRow(title: "Öyrənilib", symbol: "brain.head.profile.fill", tint: .purple,
                              value: "\(m.learned)/\(m.total)")
                }
                HealthRow(title: "Sərf edilən vaxt", symbol: "clock.fill", tint: Theme.warning, value: StatsFormat.duration(r.time))
                HealthRow(title: "Son test", symbol: "clock.arrow.circlepath", tint: .teal,
                          value: StudyStore.formatLastTested(r.lastTested, hasData: r.answered > 0))
            }

            if !isMock {
                HealthSectionTitle(text: "Günlər")
                HealthChartCard(series: .answers, tint: Theme.accent, course: key)
                let items = store.statsHighlights(.answers, course: key)
                if !items.isEmpty {
                    HealthSectionTitle(text: "Əsas məqamlar")
                    ForEach(items) { HighlightCard(item: $0) }
                }
            }

            if r.answered > 0 {
                HealthSectionTitle(text: "Cavablar")
                HealthGroup {
                    if isMock {
                        HealthRow(title: "Düz cavablar", symbol: "checkmark.circle.fill", tint: Theme.success, value: "\(r.correct)")
                        HealthRow(title: "Səhv cavablar", symbol: "xmark.circle.fill", tint: Theme.danger, value: "\(r.wrong)")
                    } else {
                        HealthRow(title: "Düz cavablar", symbol: "checkmark.circle.fill", tint: Theme.success, value: "\(r.correct)") {
                            router.start(.reviewCourse(course: key, correct: true))
                        }
                        HealthRow(title: "Səhv cavablar", symbol: "xmark.circle.fill", tint: Theme.danger, value: "\(r.wrong)") {
                            router.start(.reviewCourse(course: key, correct: false))
                        }
                    }
                }
            }

            ForEach(sections) { s in
                HealthSectionTitle(text: s.title)
                HealthGroup {
                    ForEach(s.lines) { l in
                        StatsLineRow(title: l.title, correct: l.correct, wrong: l.wrong, total: l.answered,
                                     detail: StudyStore.formatLastTested(l.last, hasData: l.answered > 0))
                            .padding(.vertical, Theme.Space.s8)
                    }
                }
            }

            if !pdfRows.isEmpty {
                HealthSectionTitle(text: "Vize imtahanları")
                HealthGroup {
                    ForEach(pdfRows) { p in
                        StatsLineRow(title: p.name, correct: p.ok, wrong: p.bad, total: max(p.total, p.done),
                                     detail: p.done > 0 ? "\(min(p.done, p.total))/\(p.total) · \(p.lastStr)" : "\(p.total) sual · işlənməyib")
                            .padding(.vertical, Theme.Space.s8)
                    }
                }
            }

            Button {
                if isMock { router.start(.mock) } else { router.openSubjectPage(key) }
            } label: {
                Label(isMock ? "Böyük sınağa başla" : "Fənnə keç", systemImage: isMock ? "play.fill" : "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .largeControl()
            .padding(.top, Theme.Space.s12)
        }
        .navigationTitle(StatsFormat.title(key))
        .navigationSubtitle("\(store.examMode.title) rejimi")
        .navigationBarTitleDisplayMode(.large)
    }
}
