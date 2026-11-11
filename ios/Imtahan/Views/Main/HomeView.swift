import SwiftUI

/// "Ana səhifə": where to study next. A slim daily-goal line (taps to Statistika), one primary action
/// (continue where you left off), a few shortcuts and the subjects. All numbers live in the Statistika tab.
struct HomeView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showWeakTopics = false

    var body: some View {
        List {
            Section {
                dailyGoalRow(store.dailyLevel)
                    .appRow()
                continueRow(continueTarget())
                    .appRow()
            }

            TodaySection { showWeakTopics = true }

            Section {
                quickActions
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                HomeSectionHeader(title: "Məşq")
            }

            Section {
                ForEach(Catalog.subjects, id: \.self) { c in
                    NavigationLink(value: Route.course(c)) { subjectRow(c) }
                        .appRow()
                }
            } header: {
                HomeSectionHeader(title: "Fənlər", actionTitle: "Hamısı") { router.tab = .subjects }
            }
        }
        .appListStyle()
        .listSectionSpacing(.compact)
        .navigationTitle("Ana səhifə")
        .navigationSubtitle("\(Self.todayTitle()) · \(store.examMode.title)")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $showWeakTopics) { WeakTopicsView() }
        .task { store.seedReviewIfNeeded() }
        .onChange(of: store.wrongTotal) { store.seedReviewIfNeeded() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                LevelBadge(level: store.dailyLevel)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.search("")) { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel("Cavab axtar")
            }
        }
    }

    // MARK: Today

    /// "Bu günkü hədəf · 12/50" with a thin bar; opens the Statistika tab.
    private func dailyGoalRow(_ level: DailyLevel) -> some View {
        Button { router.tab = .stats } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Bu günkü hədəf", systemImage: "target")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text)
                    Spacer(minLength: 8)
                    Text("\(level.count)/\(level.target)")
                        .font(.subheadline).monospacedDigit().lineLimit(1).fixedSize()
                        .foregroundStyle(Theme.textMuted)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                ProgressLine(fraction: level.progress)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bu günkü hədəf: \(level.count) / \(level.target) sual")
        .accessibilityHint("Statistikanı açır")
    }

    // MARK: Continue

    private struct ContinueTarget {
        let course: String
        let index: Int
        let unitTitle: String
        let done: Int
        let total: Int
        let isNew: Bool
    }

    /// The most recently tested in-scope unit (or the next one if it is finished); first unit of the first subject otherwise.
    private func continueTarget() -> ContinueTarget {
        var best: (course: String, index: Int, stat: SubStat)?
        let mixedIndex = Dictionary(store.scopedMixedParts.enumerated().map { ($1.statKey, $0) }, uniquingKeysWith: { a, _ in a })
        /// Stat key of unit/part i in the current mode.
        func statKey(_ c: String, _ i: Int) -> String {
            c == Catalog.mixedKey ? (store.scopedMixedParts[studySafe: i]?.statKey ?? "") : "Unit \(i + 1)"
        }
        for c in Catalog.configKeys {
            for (key, st) in store.data.stats[c]?.bd["units"] ?? [:] where st.last > 0 {
                let idx: Int
                if c == Catalog.mixedKey {
                    guard let i = mixedIndex[key] else { continue }
                    idx = i
                } else {
                    guard key.hasPrefix("Unit "), let n = Int(key.dropFirst(5)), n >= 1, store.inScope(unit: n) else { continue }
                    idx = n - 1
                }
                if best == nil || st.last > best!.stat.last { best = (c, idx, st) }
            }
        }
        func total(_ c: String, _ i: Int) -> Int { store.unitQuestionCount(c, index: i) }
        func make(_ c: String, _ i: Int, done: Int, isNew: Bool) -> ContinueTarget {
            let titles = store.unitTitles(c)
            return ContinueTarget(course: c, index: i, unitTitle: titles.indices.contains(i) ? titles[i] : "Unit \(i + 1)",
                                  done: done, total: total(c, i), isNew: isNew)
        }
        guard let best else { return make(Catalog.subjects[0], 0, done: 0, isNew: true) }
        let done = best.stat.c + best.stat.w
        let tot = total(best.course, best.index)
        if tot > 0 && done >= tot && best.index + 1 < store.unitTitles(best.course).count {
            let next = best.index + 1
            let ns = store.data.stats[best.course]?.bd["units"]?[statKey(best.course, next)] ?? SubStat()
            return make(best.course, next, done: ns.c + ns.w, isNew: false)
        }
        return make(best.course, best.index, done: done, isNew: false)
    }

    private func continueRow(_ t: ContinueTarget) -> some View {
        Button { router.start(.unit(course: t.course, index: t.index)) } label: {
            HStack(spacing: 12) {
                SubjectIcon(course: t.course, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.isNew ? "Başla" : "Davam et").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                        .textCase(.uppercase)
                    Text(t.course).font(.headline).foregroundStyle(Theme.text).lineLimit(1)
                    Text(t.total > 0 ? "\(t.unitTitle) · \(min(t.done, t.total))/\(t.total)" : t.unitTitle)
                        .font(.subheadline).foregroundStyle(Theme.textMuted).monospacedDigit().lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.onInverse)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent, in: .circle)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(t.isNew ? "Başla" : "Davam et"): \(t.course), \(t.unitTitle)")
    }

    // MARK: Shortcuts

    private var quickActions: some View {
        let wrong = store.wrongTotal
        let marks = store.scopedMarks.count
        return HStack(spacing: 10) {
            ShortcutTile(title: "Səhvlər", detail: wrong > 0 ? "\(wrong) sual" : "Hələ yoxdur",
                         symbol: "arrow.uturn.backward", tint: Theme.danger, enabled: wrong > 0) {
                router.start(.multi(course: nil))
            }
            ShortcutTile(title: "Böyük sınaq", detail: "Hər fəndən 20",
                         symbol: "die.face.5", tint: Theme.warning, enabled: true) {
                router.start(.mock)
            }
            ShortcutTile(title: "Seçilmişlər", detail: marks > 0 ? "\(marks) sual" : "Hələ yoxdur",
                         symbol: "star", tint: Theme.accent, enabled: marks > 0) {
                router.start(.bookmarks)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Subjects

    /// Logo · name + "answered / total sual" · percent. Same anatomy for every subject; untouched
    /// subjects say so instead of showing an empty bar.
    private func subjectRow(_ c: String) -> some View {
        let total = store.courseTotalQuestions(c)
        let answered = min(store.courseAggregate(c).t, total)
        let pct = store.navProgress(c)
        return HStack(spacing: 12) {
            SubjectIcon(course: c, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(c).font(.body).foregroundStyle(Theme.text).lineLimit(1)
                Text(answered > 0 ? "\(answered) / \(total) sual" : "Başlanmayıb · \(total) sual")
                    .font(.footnote).monospacedDigit().foregroundStyle(Theme.textMuted).lineLimit(1)
            }
            Spacer(minLength: 8)
            if answered > 0 {
                Text("\(pct)%")
                    .font(.subheadline.weight(.medium)).monospacedDigit()
                    .foregroundStyle(pct >= 100 ? Theme.success : Theme.textCaption)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    // MARK: Helpers

    /// "Çərşənbə, 11 noyabr"
    static func todayTitle(_ d: Date = Date()) -> String {
        let s = d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "az")))
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}
