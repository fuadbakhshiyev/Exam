import SwiftUI

/// One question opened from iPhone search (Spotlight): question, options with the correct one marked,
/// source, "işlə" (its unit / part / exam) and bookmark.
struct QuestionDetailView: View {
    let id: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var entry: QuestionSpotlight.Entry?
    @State private var loaded = false

    var body: some View {
        List {
            if let e = entry {
                content(e)
            }
        }
        .appListStyle()
        .overlay {
            if loaded && entry == nil {
                ContentUnavailableView("Sual tapılmadı", systemImage: "questionmark.circle",
                                       description: Text("Bu sual artıq tətbiqdə yoxdur."))
            }
        }
        .pageTitle("Sual", subtitle: entry.map { "\($0.subject) · \($0.source)" })
        .task(id: id) {
            let id = id
            entry = await Task.detached(priority: .userInitiated) { QuestionSpotlight.entry(id: id) }.value
            loaded = true
        }
    }

    @ViewBuilder
    private func content(_ e: QuestionSpotlight.Entry) -> some View {
        let q = e.question
        Section {
            RichTextView(q.q.isEmpty ? "(Sual mətni yoxdur)" : q.q, font: .body.weight(.semibold))
                .foregroundStyle(Theme.text)
                .padding(.vertical, Theme.Space.s4)
                .appRow()
            ForEach(Array(q.o.enumerated()), id: \.offset) { i, opt in
                let ok = i == q.a
                Label {
                    RichTextView(opt, font: .subheadline.weight(ok ? .semibold : .regular))
                        .foregroundStyle(ok ? Theme.success : Theme.textCaption)
                } icon: {
                    Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ok ? Theme.success : Theme.textMuted.opacity(0.5))
                }
                .listRowBackground(ok ? Theme.success.opacity(0.12) : Theme.surface)
                .accessibilityLabel(Text(ok ? "Doğru cavab: \(RichText.plain(opt))" : RichText.plain(opt)))
            }
        } header: {
            Text("\(e.subject) · \(e.source)")
        }

        Section {
            if let t = store.studyTarget(for: q) {
                Button(t.title, systemImage: "play.fill") { router.start(t.kind) }
                    .appRow()
            }
            let on = store.isBookmarked(q)
            Button(on ? "Seçilmişlərdən çıxar" : "Seçilmişlərə əlavə et",
                   systemImage: on ? "bookmark.fill" : "bookmark") { store.toggleBookmark(q) }
                .appRow()
        }
    }
}
