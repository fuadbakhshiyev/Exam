import SwiftUI

/// Mixed page, level 1 (renderMixedPage): subjects + Qarışıq sınaq.
struct MixedView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    enum Tab: Hashable { case subjects, mixed }
    @State private var tab: Tab = .subjects

    var body: some View {
        let c = Catalog.mixedKey
        let page = store.mixedPage()
        List {
            SegmentedSection(items: [(Tab.subjects, "Fənlər"), (.mixed, "Qarışıq sınaq")], selection: $tab)
            switch tab {
            case .subjects:
                Section("Fənlər") {
                    if page.multi.wrongCount > 0 {
                        MultiLeadRow(multi: page.multi) { router.start(.multi(course: c)) }
                    }
                    ForEach(page.subjects) { r in
                        StudyRow(row: r, glyph: .subject(r.name))
                    }
                }
            case .mixed:
                MixSection(title: "Qarışıq sınaq",
                           description: "Bütün fənlərin Mixed suallarından qarışıq 20 suallıq sürətli sınaq. Başlamaq üçün düyməyə basın.",
                           info: page.mixTab) { router.start(.courseMixed(c)) }
            }
        }
        .appListStyle()
        .pageTitle(c, subtitle: page.subtitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Statistika", systemImage: "chart.bar.xaxis") { router.openStats(c) }
            }
        }
    }
}

/// Mixed page, level 2: the 20-question parts of one subject.
struct MixedSubjectView: View {
    let subject: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let page = store.mixedSubjectPage(subject)
        List {
            Section("Hissələr") {
                ForEach(Array(page.parts.enumerated()), id: \.element.id) { i, r in
                    StudyRow(row: r, glyph: .number(i + 1))
                }
            }
        }
        .appListStyle()
        .pageTitle(subject, subtitle: page.subtitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Statistika", systemImage: "chart.bar.xaxis") { router.openStats(Catalog.mixedKey) }
            }
        }
    }
}
