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
            if page.wrongCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Səhvlərim \(page.wrongCount)") { router.start(.courseWrong(course)) }
                        .accessibilityLabel("Səhvlərim, \(page.wrongCount) sual")
                }
            }
        }
    }

    /// Review rows (Səhvlərin təkrarı, Mixed-only) on top, then the numbered units.
    @ViewBuilder private func units(_ page: CoursePage) -> some View {
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
