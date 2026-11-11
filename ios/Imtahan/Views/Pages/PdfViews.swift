import SwiftUI

/// İmtahan dashboard (showPdfExamsDashboard). Also the root of the "İmtahan" tab (isRoot).
struct PdfDashboardView: View {
    var isRoot: Bool = false
    @Environment(StudyStore.self) private var store

    init(isRoot: Bool = false) { self.isRoot = isRoot }

    var body: some View {
        let page = store.pdfDashboard()
        List {
            Section {
                if page.rows.isEmpty {
                    EmptyRow(title: "İmtahan tapılmadı", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(page.rows) { r in
                        StudyRow(row: r, glyph: .subject(r.name))
                    }
                }
            } header: {
                Text("Vize imtahanları")
            }
            Section {
                if store.examMode == .final {
                    NavigationLink(value: Route.finalExams(nil)) {
                        Label("Final imtahanları", systemImage: "graduationcap.fill")
                            .foregroundStyle(Theme.text)
                    }
                    .appRow()
                } else {
                    Label("Final imtahanları Final rejimində görünür", systemImage: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                        .appRow()
                }
            } header: {
                Text("Final, Bütünləmə, Yaz Okulu")
            } footer: {
                Text(store.examMode == .final ? "Keçmiş Final, Bütünləmə və Üç Ders imtahanları — bütün ünitələr." : "Rejimi Ayarlarda dəyişə bilərsiniz.")
            }
        }
        .appListStyle()
        .pageTitle("İmtahan", subtitle: page.subtitle, displayMode: isRoot ? .large : .inline)
    }
}

/// Exams of one subject (showPdfExamsList).
struct PdfSubjectView: View {
    let subject: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let page = store.pdfExamListPage(subject)
        List {
            PdfExamsSection(subject: subject)
        }
        .appListStyle()
        .pageTitle(subject, subtitle: page.subtitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Statistika", systemImage: "chart.bar.xaxis") { router.openStats(subject) }
            }
        }
    }
}
