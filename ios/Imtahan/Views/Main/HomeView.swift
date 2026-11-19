import SwiftUI

/// "Ana səhifə": where to study next. A slim daily-goal line (taps to Statistika), one primary action
/// (continue where you left off), a few shortcuts and the subjects. All numbers live in the Statistika tab.
struct HomeView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(SidebarStopwatch.self) private var stopwatch
    @State private var showWeakTopics = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s12) {
                dailyGoalCard(store.dailyLevel)
                // Ağıllı təkrar has its own card below (which offers its half-done test itself).
                let open = QuizProgressStore.shared.openTests(mode: store.examMode).filter {
                    switch $0.kind { case .review, .reviewSubject: false; default: true }
                }
                if let first = open.first {
                    openTestCard(first, others: Array(open.dropFirst().prefix(3)))
                } else {
                    continueCard(continueTarget())
                }

                TodaySection { showWeakTopics = true }

                HomeSectionHeader(title: "Məşq")
                quickActions

                HomeSectionHeader(title: "Fənlər", actionTitle: "Hamısı") { router.tab = .subjects }
                subjectsCard
            }
            .padding(.horizontal, Theme.Space.s16)
            .padding(.bottom, Theme.Space.s24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg.ignoresSafeArea())
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: Route.timer) {
                    Image(systemName: timerRunning ? "stopwatch.fill" : "stopwatch")
                        .symbolEffect(.pulse, isActive: timerRunning)
                }
                .accessibilityLabel(timerRunning ? "Xronometr işləyir" : "Xronometr")
                NavigationLink(value: Route.search("")) { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel("Cavab axtar")
            }
        }
    }

    /// Stopwatch or a focus / break phase is counting.
    private var timerRunning: Bool { stopwatch.isRunning || stopwatch.pomodoro.isRunning }

    // MARK: Today

    /// "Gündəlik hədəf  12 / 50 sual" with a ring; opens the Statistika tab.
    private func dailyGoalCard(_ level: DailyLevel) -> some View {
        Button { router.tab = .stats } label: {
            MetricCard(title: "Gündəlik hədəf", symbol: "target", tint: Theme.accent, caption: level.level,
                       value: "\(level.count)", unit: "/ \(level.target) sual",
                       note: level.count >= level.target ? "Hədəf tamamlandı ✓" : "Qalıb: \(level.target - level.count) sual") {
                RingDial(accent: level.progress, lineWidth: 7) {
                    Text("\(Int((level.progress * 100).rounded()))%")
                        .font(.caption2.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.text)
                }
                .frame(width: 52, height: 52)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Statistikanı açır")
    }

    // MARK: Continue

    /// Subject (for the icon) and the two lines of a half-done test.
    private func describe(_ o: QuizProgressStore.OpenTest) -> (subject: String?, title: String, detail: String) {
        let p = o.progress
        let subject = (Self.subject(of: o.kind) ?? p.course).map(QuestionBank.baseCourse)
        let known = subject.flatMap { Catalog.configKeys.contains($0) ? $0 : nil }
        // Subject first, then the test ("Öyrənilməmişlər", "Unit 6", "İmtahan 2", …).
        let lines = [known, p.title, p.label].compactMap { $0 }.filter { !$0.isEmpty }
        var seen = Set<String>()
        let uniq = lines.filter { seen.insert($0).inserted }
        return (known, uniq.first ?? "Test", uniq.dropFirst().first ?? (p.revealAtEnd == true ? "Cavablar sonda" : "Yarımçıq test"))
    }

    private static func subject(of k: QuizSession.Kind) -> String? {
        switch k {
        case .unit(let c, _), .courseWrong(let c), .courseMixed(let c), .pdfExam(let c, _), .pdfExamWrong(let c, _),
             .pdfSubjectAllWrong(let c), .pdfFrequent(let c), .finalExam(let c, _), .finalExamWrong(let c, _),
             .finalSubjectAllWrong(let c), .mixedOnly(let c), .reviewSubject(let c), .allQuestions(let c), .unlearned(let c), .oldExamQuestions(let c, _), .hardQuestions(let c),
             .wrongFor(let c), .reviewCourse(let c, _):
            c
        default: nil
        }
    }

    private func openTestCard(_ o: QuizProgressStore.OpenTest, others: [QuizProgressStore.OpenTest]) -> some View {
        let p = o.progress
        let d = describe(o)
        let subject = d.subject
        let known = subject != nil
        let subtitle = [d.title, d.detail]
        return VStack(spacing: Theme.Space.s8) {
        Button {
            router.resume(.init(kind: o.kind, key: o.key, progress: p))
        } label: {
            CardShell(title: "Davam et", symbol: "play.circle.fill", tint: Theme.accent,
                      caption: "\(min(p.answeredCount, p.total))/\(p.total)", chevron: false) {
                HStack(spacing: 12) {
                    if known, let subject { SubjectIcon(course: subject, size: 44) }
                    else { IconTile(symbol: "list.bullet.rectangle.fill", color: Theme.accent, size: 44) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subtitle[0]).font(.headline).foregroundStyle(Theme.text).lineLimit(1)
                        Text(subtitle[1])
                            .font(.subheadline).foregroundStyle(Theme.textMuted).lineLimit(1)
                        ProgressLine(fraction: p.total > 0 ? min(1, Double(p.answeredCount) / Double(p.total)) : 0, height: 4)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "play.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent, in: .circle)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Davam et: \(subtitle.joined(separator: ", ")), \(p.answeredCount)/\(p.total)")
        .accessibilityAddTraits(.isButton)

        // Other half-done tests: one line each.
        if !others.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(others.enumerated()), id: \.element.id) { i, t in
                    let od = describe(t)
                    Button { router.resume(.init(kind: t.kind, key: t.key, progress: t.progress)) } label: {
                        HStack(spacing: 12) {
                            if let s = od.subject { SubjectIcon(course: s, size: 30) }
                            else { IconTile(symbol: "list.bullet.rectangle.fill", color: Theme.accent, size: 30) }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(od.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                                Text(od.detail).font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text("\(min(t.progress.answeredCount, t.progress.total))/\(t.progress.total)")
                                .font(.footnote.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.textMuted)
                            Image(systemName: "play.fill").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                        }
                        .padding(.horizontal, Theme.Space.s16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < others.count - 1 { Divider().padding(.leading, 58) }
                }
            }
            .card()
        }
        }
    }

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
        func doneOf(_ c: String, _ i: Int) -> Int {
            let st = store.data.stats[c]?.bd["units"]?[statKey(c, i)] ?? SubStat()
            return st.c + st.w
        }
        if tot > 0 && done >= tot {
            // Finished: the next unfinished in-scope unit, this subject first (after it, then before it),
            // then the other subjects in order.
            let order = [best.course] + Catalog.configKeys.filter { $0 != best.course }
            for c in order {
                let n = store.unitTitles(c).count
                let idxs = c == best.course ? Array((best.index + 1)..<max(best.index + 1, n)) + Array(0..<best.index) : Array(0..<n)
                for i in idxs {
                    let t = total(c, i)
                    let d = doneOf(c, i)
                    if t > 0 && d < t { return make(c, i, done: d, isNew: d == 0) }
                }
            }
        }
        return make(best.course, best.index, done: done, isNew: false)
    }

    private func continueCard(_ t: ContinueTarget) -> some View {
        Button { router.start(.unit(course: t.course, index: t.index)) } label: {
            CardShell(title: t.isNew ? "Başla" : "Davam et", symbol: "play.circle.fill", tint: Theme.accent,
                      caption: t.total > 0 ? "\(min(t.done, t.total))/\(t.total)" : nil, chevron: false) {
                HStack(spacing: 12) {
                    SubjectIcon(course: t.course, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.course).font(.headline).foregroundStyle(Theme.text).lineLimit(1)
                        Text(t.unitTitle).font(.subheadline).foregroundStyle(Theme.textMuted).lineLimit(1)
                        if t.total > 0 {
                            ProgressLine(fraction: min(1, Double(t.done) / Double(t.total)), height: 4).padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "play.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent, in: .circle)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(t.isNew ? "Başla" : "Davam et"): \(t.course), \(t.unitTitle)")
        .accessibilityAddTraits(.isButton)
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

    /// All subjects in one card; a row opens the subject's study page.
    private var subjectsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(Catalog.subjects.enumerated()), id: \.element) { i, c in
                NavigationLink(value: Route.course(c)) {
                    HStack(spacing: Theme.Space.s8) {
                        subjectRow(c)
                        Chevron()
                    }
                    .padding(.vertical, Theme.Space.s10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < Catalog.subjects.count - 1 { Divider().padding(.leading, 48) }
            }
        }
        .padding(.horizontal, Theme.Space.s16)
        .padding(.vertical, Theme.Space.s4)
        .card()
    }

    /// Logo · name + "answered / total sual" · percent. Untouched subjects say so instead of an empty bar.
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
        .accessibilityElement(children: .combine)
    }

    // MARK: Helpers

    /// "Çərşənbə, 11 noyabr"
    static func todayTitle(_ d: Date = Date()) -> String {
        let s = d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "az")))
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}
