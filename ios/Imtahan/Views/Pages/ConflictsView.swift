import SwiftUI

/// Ziddiyyətli suallar (showConflictingQuestions): same question, different answers across sources.
struct ConflictsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var query = ""

    var body: some View {
        let all = store.scopedConflictingQuestions()
        let shown = store.filterConflicts(query)
        List {
            ForEach(shown) { group in
                Section {
                    RichTextView(group.questionRaw, font: .body.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.vertical, Theme.Space.s4)
                        .appRow()
                    ForEach(group.variants, id: \.answerNorm) { v in
                        VStack(alignment: .leading, spacing: Theme.Space.s8) {
                            Text("Cavab: \(RichText.plain(v.answerText))")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                                .fixedSize(horizontal: false, vertical: true)
                            FlowLayout(spacing: 6, lineSpacing: 6) {
                                ForEach(Array(v.occurrences.enumerated()), id: \.offset) { _, occ in
                                    SourcePill(text: occ.source, course: occ.course)
                                }
                            }
                        }
                        .padding(.vertical, Theme.Space.s4)
                        .appRow()
                    }
                }
            }
        }
        .appListStyle()
        .overlay {
            if all.isEmpty {
                ContentUnavailableView("Heç bir ziddiyyət tapılmadı.", systemImage: "checkmark.seal")
            } else if shown.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Suallarda axtarış...")
        .pageTitle("Ziddiyyətli suallar",
                   subtitle: "Eyni suala fərqli imtahanlarda fərqli cavab verilmiş \(all.count) ziddiyyət")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sınağa başla \(all.count)") { router.start(.conflicts) }
                    .disabled(all.isEmpty)
            }
        }
    }
}

/// Source badge tinted with the subject's accent colour.
private struct SourcePill: View {
    let text: String
    let course: String
    var body: some View {
        let tint = Theme.hex(Catalog.styles[course]?.accent ?? "#8b5cf6")
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, Theme.Space.s8).padding(.vertical, Theme.Space.s4)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.3), lineWidth: 1))
    }
}
