import SwiftUI

/// Past final-type booklets (Final, Bütünləmə, Yaz Okulu / Üç Ders). subject == nil → the subjects,
/// otherwise the booklets of one subject (newest first). Only meaningful in Final mode.
struct FinalExamsView: View {
    let subject: String?
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            if store.examMode != .final {
                EmptyRow(title: "Final rejimində görünür", systemImage: "lock")
            } else if let subject {
                bookletSection(subject)
            } else {
                subjectSection
            }
        }
        .appListStyle()
        .pageTitle(subject ?? "Final imtahanları", subtitle: subtitle)
        .toolbar {
            if let subject {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Statistika", systemImage: "chart.bar.xaxis") { router.openStats(subject) }
                }
            }
        }
    }

    private var subtitle: String {
        if let subject { return "\(store.bank.finals(subject: subject).count) final imtahanı" }
        return "\(store.bank.pdfFinals.count) fənn · \(store.bank.finalExamCount) imtahan"
    }

    private var subjectSection: some View {
        let rows = store.finalSubjectRows()
        return Section("Fənlər") {
            if rows.isEmpty {
                EmptyRow(title: "İmtahan tapılmadı", systemImage: "doc.text.magnifyingglass")
            } else {
                ForEach(rows) { r in
                    NavigationLink(value: Route.finalExams(r.name)) {
                        StudyRowContent(row: r, glyph: .subject(r.name))
                    }
                    .appRow()
                }
            }
        }
    }

    private func bookletSection(_ subject: String) -> some View {
        let rows = store.finalExamRows(subject)
        let wrong = store.finalWrongCount(subject)
        return Section("Final · Bütünləmə · Yaz Okulu") {
            if rows.isEmpty {
                EmptyRow(title: "İmtahan tapılmadı", systemImage: "doc.text.magnifyingglass")
            } else {
                if wrong > 0 {
                    MultiLeadRow(wrongCount: wrong, subtitle: "Bütün final imtahanlarındakı səhvlər") {
                        router.start(.finalSubjectAllWrong(subject))
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    Button { router.start(.finalExam(subject: subject, id: r.examId)) } label: {
                        StudyRowContent(row: r.row, glyph: .number(i + 1))
                    }
                    .tint(Theme.text)
                    .appRow()
                    .accessibilityHint(r.fullName)
                    .modifier(FinalWrongActions(subject: subject, row: r))
                }
            }
        }
    }
}

/// Swipe action + context menu repeating one booklet's wrong answers.
private struct FinalWrongActions: ViewModifier {
    let subject: String
    let row: FinalExamRow
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        let wrong = row.row.bad
        content
            .swipeActions(edge: .trailing) {
                if wrong > 0 {
                    Button("Səhvlər", systemImage: "arrow.counterclockwise") {
                        router.start(.finalExamWrong(subject: subject, id: row.examId))
                    }
                    .tint(Theme.danger)
                }
            }
            .contextMenu {
                Text(row.fullName)
                if wrong > 0 {
                    Button("Səhvləri təkrarla", systemImage: "arrow.counterclockwise") {
                        router.start(.finalExamWrong(subject: subject, id: row.examId))
                    }
                }
            }
    }
}
