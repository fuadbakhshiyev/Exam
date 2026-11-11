import SwiftUI

/// One metric ranked over every stats key (subjects, Mixed, pdf exams, mock) — "Ətraflı sıralama".
struct StatDetailSheet: View {
    let type: StatDetailType
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let rows = store.statDetails(type)
        NavigationStack {
            List {
                if rows.isEmpty {
                    EmptyRow(title: "Hələ heç bir sual cavablandırılmayıb", systemImage: "chart.bar")
                } else {
                    Section {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                            HStack(spacing: Theme.Space.s12) {
                                Text("\(i + 1)").font(.footnote.weight(.semibold)).monospacedDigit()
                                    .foregroundStyle(Theme.textMuted).frame(minWidth: 20, alignment: .leading)
                                Text(StatsFormat.title(StudyStore.wrongKeyLabel(r.name))).foregroundStyle(Theme.text).lineLimit(2)
                                Spacer(minLength: 8)
                                Text(type == .time ? StatsFormat.duration(CompactFormat.seconds(fromHM: r.display)) : r.display)
                                    .monospacedDigit().foregroundStyle(type.valueTint)
                            }
                            .appRow()
                        }
                    }
                }
            }
            .appListStyle()
            .navigationTitle(type.rowTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }
}
