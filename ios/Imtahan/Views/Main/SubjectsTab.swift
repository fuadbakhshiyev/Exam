import SwiftUI

/// "Fənlər" tab: subjects, practice exams and tools as a native inset-grouped list.
/// Every row has the same anatomy: leading glyph, title (+ caption), optional trailing value.
struct SubjectsTab: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            Section {
                ForEach(Catalog.subjects, id: \.self) { c in
                    NavigationLink(value: Route.course(c)) { subjectRow(c) }.appRow()
                }
                NavigationLink(value: Route.overall) { overallRow }.appRow()
            } header: {
                Text("Fənlər")
            } footer: {
                Text("İmtahan rejimi: \(store.examModeLabel). Ayarlardan dəyişə bilərsiniz.")
            }

            Section("Sınaq") {
                NavigationLink(value: Route.pdfDashboard) {
                    tool("Vize imtahanları", "doc.text", detail: count(QuestionBank.shared.pdfExamCount, "imtahan"))
                }
                .appRow()
                NavigationLink(value: Route.mixed) {
                    tool("Mixed", "shuffle", detail: count(store.scopedMixedParts.count, "hissə"))
                }
                .appRow()
                Button { router.start(.mock) } label: {
                    tool("Böyük sınaq", "die.face.5", detail: "hər fəndən 20")
                }
                .appRow()
            }

            Section("Alətlər") {
                NavigationLink(value: Route.wrong) {
                    tool("Səhvlərim", "xmark.circle", detail: count(store.wrongTotal))
                }
                .appRow()
                Button { router.start(.hard) } label: { tool("Ən çətinlər", "flame") }
                    .appRow()
                Button { router.start(.bookmarks) } label: {
                    tool("Seçilmişlər", "star", detail: count(store.scopedMarks.count))
                }
                .appRow()
                NavigationLink(value: Route.conflicts) { tool("Ziddiyyətli suallar", "arrow.triangle.branch") }.appRow()
                NavigationLink(value: Route.search("")) { tool("Axtarış", "magnifyingglass") }.appRow()
            }
        }
        .appListStyle()
        .navigationTitle("Fənlər")
        .navigationBarTitleDisplayMode(.large)
    }

    /// "12 imtahan" / "12" when > 0, nil otherwise (no zero counts on the page).
    private func count(_ n: Int, _ noun: String? = nil) -> String? {
        guard n > 0 else { return nil }
        return noun.map { "\(n) \($0)" } ?? "\(n)"
    }

    // MARK: Subject rows

    /// Subject glyph (single place to swap in a dedicated subject icon).
    private func subjectGlyph(_ c: String) -> some View {
        SubjectIcon(course: c, size: 36).accessibilityHidden(true)
    }

    private func subjectRow(_ c: String) -> some View {
        let units = store.scopedUnitCount(c)
        let questions = store.courseTotalQuestions(c)
        return HStack(spacing: Theme.Space.s12) {
            subjectGlyph(c)
            titleStack(c, caption: [count(units, "bölmə"), count(questions, "sual")].compactMap { $0 }.joined(separator: " · "))
            Spacer(minLength: 4)
            ProgressBadge(percent: store.navProgress(c))
        }
        .padding(.vertical, 2)
    }

    private var overallRow: some View {
        HStack(spacing: Theme.Space.s12) {
            subjectGlyph(Catalog.overallKey)
            titleStack(Catalog.overallKey, caption: "Bütün fənlər · \(store.scopedQuestionsTotal) sual")
            Spacer(minLength: 4)
        }
        .padding(.vertical, 2)
    }

    private func titleStack(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.body).foregroundStyle(Theme.text).lineLimit(1)
            if !caption.isEmpty {
                Text(caption).font(.caption).foregroundStyle(Theme.textMuted).monospacedDigit().lineLimit(1)
            }
        }
    }

    // MARK: Sınaq / Alətlər rows

    /// Settings-style row: accent glyph, title, optional trailing detail.
    private func tool(_ title: String, _ symbol: String, detail: String? = nil) -> some View {
        LabeledContent {
            if let detail {
                Text(detail).monospacedDigit().foregroundStyle(Theme.textMuted)
            }
        } label: {
            Label {
                Text(title).foregroundStyle(Theme.text)
            } icon: {
                Image(systemName: symbol).foregroundStyle(Theme.accent)
            }
        }
    }
}

/// Small trailing progress indicator of a subject row: "42%" next to a mini ring. Hidden at 0%.
private struct ProgressBadge: View {
    let percent: Int
    @ScaledMetric(relativeTo: .caption) private var ring: CGFloat = 18

    var body: some View {
        if percent > 0 {
            HStack(spacing: 6) {
                Text("\(percent)%").font(.subheadline).monospacedDigit().foregroundStyle(Theme.textMuted)
                ZStack {
                    Circle().stroke(Theme.track, lineWidth: 2.5)
                    Circle().trim(from: 0, to: min(1, Double(percent) / 100))
                        .stroke(percent >= 100 ? Theme.success : Theme.accent,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: ring, height: ring)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(percent) faiz işlənib")
        }
    }
}
