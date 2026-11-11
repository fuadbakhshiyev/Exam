import SwiftUI

/// Unified search (Axtarış): finds a word in question texts and answer options of every in-scope question,
/// with native search scopes Hamısı / Sual / Doğru cavab and highlighted matches.
struct AnswerSearchView: View {
    let initialQuery: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var text = ""
    @State private var scope: SearchScope = .all
    /// The query of the shown results (nil → nothing searched yet).
    @State private var searched: String?
    @State private var results: [SearchHit] = []
    @FocusState private var focused: Bool

    init(initialQuery: String) {
        self.initialQuery = initialQuery
        _text = State(initialValue: initialQuery)
    }

    var body: some View {
        List {
            if let q = searched, !results.isEmpty {
                Section {
                    LabeledContent("Tapılan sual", value: "\(results.count)").appRow()
                }
                let terms = StudyStore.searchTerms(q)
                ForEach(results.prefix(300)) { hit in
                    SearchResultSection(hit: hit, terms: terms)
                }
                if results.count > 300 {
                    Section { Text("İlk 300 nəticə göstərilir. Axtarışı dəqiqləşdirin.").font(.footnote).foregroundStyle(Theme.textMuted).appRow() }
                }
            }
        }
        .appListStyle()
        .overlay {
            if let q = searched, results.isEmpty {
                ContentUnavailableView {
                    Label("Uyğunluq tapılmadı", systemImage: "magnifyingglass")
                } description: {
                    Text(verbatim: "\"\(q)\" — \(scope.title.lowercased()) üzrə heç nə tapılmadı.")
                }
            } else if searched == nil {
                ContentUnavailableView("Sual və ya cavab axtarın",
                                       systemImage: "text.magnifyingglass",
                                       description: Text("Söz bütün sualların mətnində və variantlarında axtarılır. Bir neçə söz yazsanız, hamısı olan suallar tapılır."))
            }
        }
        .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Sual və ya cavab axtar…")
        .searchScopes($scope, activation: .onSearchPresentation) {
            ForEach(SearchScope.allCases) { Text($0.title).tag($0) }
        }
        .searchFocused($focused)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onSubmit(of: .search, search)
        .onChange(of: scope) { _, _ in if searched != nil { search() } }
        .pageTitle("Axtarış", subtitle: "\(store.examMode.title) · sual və cavablar")
        .toolbar {
            if let q = searched, !results.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Test kimi işlə", systemImage: "play.fill") { router.start(.search(q, scope)) }
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .onAppear {
            if !initialQuery.trimmingCharacters(in: .whitespaces).isEmpty, searched == nil { search() }
            else if searched == nil { focused = true }
        }
    }

    private func search() {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        focused = false
        results = store.search(q, scope: scope)
        searched = q
    }
}

/// One result: source header, question and options; matched words highlighted, correct option marked.
private struct SearchResultSection: View {
    let hit: SearchHit
    let terms: [[Character]]

    var body: some View {
        let q = hit.question
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(hit.id + 1).").font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                field(q.q, matched: hit.inQuestion, font: .body.weight(.semibold), color: Theme.text)
            }
            .padding(.vertical, Theme.Space.s4)
            .appRow()
            ForEach(Array(q.o.enumerated()), id: \.offset) { i, opt in
                let ok = i == q.a
                Label {
                    field(opt, matched: hit.matchedOptions.contains(i), font: .subheadline.weight(ok ? .semibold : .regular),
                          color: ok ? Theme.success : Theme.textCaption)
                } icon: {
                    Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ok ? Theme.success : Theme.textMuted.opacity(0.5))
                }
                .listRowBackground(ok ? Theme.success.opacity(0.12) : Theme.surface)
            }
        } header: {
            Text(hit.source)
        }
    }

    /// Highlighted plain text when this field matched, otherwise the rich (HTML) rendering.
    @ViewBuilder
    private func field(_ html: String, matched: Bool, font: Font, color: Color) -> some View {
        let plain = RichText.plain(html)
        if matched, !plain.isEmpty {
            Text(Self.highlight(plain, terms: terms)).font(font).foregroundStyle(color)
        } else {
            RichTextView(html.isEmpty ? "(Sual mətni yoxdur)" : html, font: font).foregroundStyle(color)
        }
    }

    static func highlight(_ text: String, terms: [[Character]]) -> AttributedString {
        var a = AttributedString(text)
        let chars = Array(text)
        for r in StudyStore.matchRanges(text, terms: terms) {
            let start = a.index(a.startIndex, offsetByCharacters: r.lowerBound)
            let end = a.index(a.startIndex, offsetByCharacters: min(r.upperBound, chars.count))
            a[start..<end].backgroundColor = Theme.accent.opacity(0.35)
            a[start..<end].inlinePresentationIntent = .stronglyEmphasized
        }
        return a
    }
}
