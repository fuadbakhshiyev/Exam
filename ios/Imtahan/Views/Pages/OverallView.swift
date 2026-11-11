import SwiftUI

/// Ümumi Toplam (showOverallDashboard): every subject + Böyük sınaq.
struct OverallView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    enum Tab: Hashable { case subjects, mock }
    @State private var tab: Tab = .subjects

    var body: some View {
        let page = store.overallPage()
        List {
            SegmentedSection(items: [(Tab.subjects, "Fənlər"), (.mock, "Böyük sınaq")], selection: $tab)
            switch tab {
            case .subjects:
                Section("Fənlər") {
                    if page.multi.wrongCount > 0 {
                        MultiLeadRow(multi: page.multi) { router.start(.multi(course: nil)) }
                    }
                    ForEach(page.rows) { r in
                        StudyRow(row: r, glyph: .subject(r.name))
                    }
                }
            case .mock:
                MixSection(title: "Böyük sınaq",
                           description: "Bütün fənlərdən qarışıq real sınaq imtahanı: hər fəndən 20 sual. Başlamaq üçün düyməyə basın.",
                           info: page.mixTab, countLabel: "Hər fəndən") { router.start(.mock) }
            }
        }
        .appListStyle()
        .pageTitle(Catalog.overallKey, subtitle: "Bütün fənlər")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Statistika", systemImage: "chart.bar.xaxis") { router.statsPath = []; router.tab = .stats }
            }
            if page.wrongCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Səhvlərim \(page.wrongCount)") { router.start(.hard) }
                }
            }
        }
    }
}
