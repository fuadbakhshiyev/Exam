import SwiftUI

/// Səhvlərim (showWrong): one row per wrong-answer source.
struct WrongListView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let sources = store.wrongSources()
        let total = sources.reduce(0) { $0 + $1.count }
        List {
            if !sources.isEmpty {
                Section {
                    ForEach(sources) { s in
                        Button { router.start(.wrongFor(s.key)) } label: {
                            HStack(spacing: Theme.Space.s12) {
                                SubjectIcon(course: s.key, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.label).font(.body.weight(.medium)).foregroundStyle(Theme.text).lineLimit(1)
                                    if let caption = difficulty(s.hard, s.veryHard) {
                                        Text(caption)
                                            .font(.caption).foregroundStyle(s.veryHard > 0 ? Theme.warning : Theme.textMuted)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(s.count)").font(.body.weight(.medium)).foregroundStyle(Theme.text).monospacedDigit()
                                    Text("səhv sual").font(.caption).foregroundStyle(Theme.danger)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .tint(Theme.text)
                        .appRow()
                    }
                }
            }
        }
        .appListStyle()
        .overlay {
            if sources.isEmpty {
                ContentUnavailableView("Əla! Səhv yoxdur.", systemImage: "checkmark.seal")
            }
        }
        .pageTitle("Səhvlərim", subtitle: "\(total) səhv sual · \(sources.count) mənbə")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Qarışıq 20 sual") { router.start(.hard) }
                    .disabled(total == 0)
            }
        }
    }

    /// "3 çətin (2+) · 1 çox çətin (3+)", zero parts left out; nil when both are zero.
    private func difficulty(_ hard: Int, _ veryHard: Int) -> String? {
        let parts = [hard > 0 ? "\(hard) çətin (2+)" : nil, veryHard > 0 ? "\(veryHard) çox çətin (3+)" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
