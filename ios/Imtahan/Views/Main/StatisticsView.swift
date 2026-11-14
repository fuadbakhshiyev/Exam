import SwiftUI
import Charts

/// "Statistika" tab, Apple Health style: one summary card per metric (big number + mini chart),
/// each opening its detail page; subjects below. Everything follows the current exam mode (Vize / Final).
struct StatisticsView: View {
    @Environment(StudyStore.self) private var store

    var body: some View {
        let t = store.homeTotals()
        let days = store.recentStatsDays(7)
        let level = store.dailyLevel
        let ach = AchievementStore.shared
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s12) {
                ScopeChip()

                StatsSectionTitle(text: "İmtahanlar")
                ExamCountdownCard()
                ExamReadinessCard()

                StatsSectionTitle(text: "Bu gün")
                NavigationLink(value: Route.statsMetric(.today)) {
                    MetricCard(title: "Gündəlik hədəf", symbol: "target", tint: Theme.accent, caption: level.level,
                               value: "\(level.count)", unit: "/ \(level.target) sual",
                               note: t.todayCorrect + t.todayWrong > 0 ? "\(t.todayCorrect) düz · \(t.todayWrong) səhv" : "Hələ sual işlənməyib") {
                        todayRing(t, level)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: Theme.Space.s12) {
                    streakCard
                    NavigationLink(value: Route.statsMetric(.learning)) { learningCard }
                        .buttonStyle(.plain)
                }

                StatsSectionTitle(text: "Göstəricilər")
                NavigationLink(value: Route.statsMetric(.accuracy)) {
                    MetricCard(title: "Dəqiqlik", symbol: "checkmark.seal.fill", tint: Theme.success, caption: "Son 7 gün",
                               value: t.globalAnswered > 0 ? "\(t.accuracy)" : "—", unit: t.globalAnswered > 0 ? "%" : "",
                               note: "\(t.globalCorrect) düz · \(t.globalWrong) səhv") {
                        MiniLine(values: days.map(\.accuracy), tint: Theme.success)
                    }
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.statsMetric(.questions)) {
                    MetricCard(title: "İşlənən suallar", symbol: "square.stack.3d.up.fill", tint: .indigo, caption: "Son 7 gün",
                               value: "\(t.globalAnswered)", unit: "/ \(t.totalQuestions)",
                               note: "Bu həftə \(days.reduce(0) { $0 + $1.answered }) sual") {
                        MiniBars(values: days.map { Double($0.answered) }, tint: .indigo)
                    }
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.statsMetric(.time)) {
                    let v = Self.timeParts(t.globalTime)
                    MetricCard(title: "Vaxt", symbol: "clock.fill", tint: Theme.warning, caption: "Son 7 gün",
                               value: v.value, unit: v.unit,
                               note: "Bu gün testlərdə \(StatsFormat.duration(t.todayTestTime))") {
                        MiniBars(values: days.map { Double($0.seconds) / 60 }, tint: Theme.warning)
                    }
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.statsMetric(.wrong)) {
                    MetricCard(title: "Səhv suallar", symbol: "xmark.octagon.fill", tint: Theme.danger,
                               value: "\(store.wrongTotal)", unit: "sual",
                               note: store.wrongTotal > 0 ? "\(store.hardCount) çətin · \(store.veryHardCount) çox çətin" : "Səhv sual yoxdur") {
                        MiniBars(values: days.map { Double($0.wrong) }, tint: Theme.danger)
                    }
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.achievements) {
                    MetricCard(title: "Nailiyyətlər", symbol: "trophy.fill", tint: .yellow,
                               value: "\(ach.unlockedCount)", unit: "/ \(Achievement.all.count)",
                               note: ach.latest.map { "Son: \($0.title)" }) { recentBadges }
                }
                .buttonStyle(.plain)

                StatsSectionTitle(text: "Fənlər")
                subjects

                Text("Statistikanı sıfırlamaq: Tənzimləmələr səhifəsinin sonunda.")
                    .font(.footnote).foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Space.s12)
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Space.s16)
            .padding(.bottom, Theme.Space.s24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Statistika")
        .navigationBarTitleDisplayMode(.large)
        .task { store.evaluateAchievements(announce: true) }
    }

    private func todayRing(_ t: HomeTotals, _ level: DailyLevel) -> some View {
        let target = Double(max(level.target, 1))
        let ok = min(1, Double(t.todayCorrect) / target)
        let bad = min(1 - ok, Double(t.todayWrong) / target)
        return RingDial(accent: ok, danger: bad, lineWidth: 7) {
            Text("\(Int((level.progress * 100).rounded()))%")
                .font(.caption2.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.text)
        }
        .frame(width: 52, height: 52)
    }

    /// Subjects in one card, each row opening its statistics page.
    private var subjects: some View {
        let order = SubjectOrder.apply(UserDefaults.standard.string(forKey: "subjects_order") ?? "")
        let rows = store.subjectStatsRows().sorted { (order.firstIndex(of: $0.key) ?? 99) < (order.firstIndex(of: $1.key) ?? 99) }
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                NavigationLink(value: Route.subjectStats(r.key)) {
                    HStack(spacing: Theme.Space.s8) {
                        SubjectStatsRowView(row: r)
                        Chevron()
                    }
                    .padding(.vertical, Theme.Space.s10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < rows.count - 1 { Divider().padding(.leading, 48) }
            }
        }
        .padding(.horizontal, Theme.Space.s16)
        .padding(.vertical, Theme.Space.s4)
        .card()
    }

    // MARK: Small cards

    /// Ardıcıl günlər with the last 7 days as dots.
    private var streakCard: some View {
        let s = store.studyStreak()
        let best = store.achievementMetrics().bestStreak
        let days = store.recentStatsDays(7)
        return VStack(alignment: .leading, spacing: Theme.Space.s8) {
            Label("Ardıcıllıq", systemImage: "flame.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(s.days)").font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Theme.text)
                Text("gün").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textMuted)
            }
            HStack(spacing: 5) {
                ForEach(days) { d in
                    Circle()
                        .fill(d.answered > 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(Theme.border))
                        .frame(width: 10, height: 10)
                }
            }
            Text("Ən uzun: \(best) gün").font(.footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
        }
        .padding(Theme.Space.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
        .accessibilityElement(children: .combine)
    }

    /// Öyrənilmiş suallar (2 düz ardıcıl) over every subject.
    private var learningCard: some View {
        let p = Catalog.subjects.map { store.masteryProgress($0) }
        let learned = p.reduce(0) { $0 + $1.learned }, total = p.reduce(0) { $0 + $1.total }
        return VStack(alignment: .leading, spacing: Theme.Space.s8) {
            HStack(spacing: 4) {
                Label("Öyrənilib", systemImage: "brain.head.profile.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.purple).lineLimit(1)
                Spacer(minLength: 0)
                Chevron()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(learned)").font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Theme.text)
                Text("/ \(total)").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textMuted)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            ProgressView(value: Double(learned), total: Double(max(total, 1))).tint(.purple)
                .frame(height: 10)
            Text("\(StudyStore.pct(learned, max(total, 1)))% hazır").font(.footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
        }
        .padding(Theme.Space.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// The three latest earned awards as small badges.
    private var recentBadges: some View {
        let recent = store.achievementStatuses().filter { $0.lastEarned != nil }
            .sorted { $0.lastEarned! > $1.lastEarned! }.prefix(3)
        return HStack(spacing: -6) {
            ForEach(Array(recent)) { st in
                IconTile(symbol: st.achievement.symbol, color: .yellow, size: 30)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.surface, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }

    /// 13 500 s → ("3", "saat 45 dəq"); under an hour → ("45", "dəq").
    static func timeParts(_ s: Int) -> (value: String, unit: String) {
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? ("\(h)", m > 0 ? "saat \(m) dəq" : "saat") : ("\(m)", "dəq")
    }
}

// MARK: - Countdown

/// Big live countdown to the nearest exam: days · hours · minutes.
private struct ExamCountdownCard: View {
    var body: some View {
        let dates = ExamDates.shared
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            if let n = dates.next {
                let target = dates.date(for: n.subject)
                let group = dates.nextGroup
                let left = max(0, Int(target.timeIntervalSince(ctx.date)))
                let d = left / 86_400, h = (left % 86_400) / 3600, m = (left % 3600) / 60
                CardShell(title: "Geri sayım", symbol: "hourglass", tint: d <= 2 ? Theme.warning : Theme.accent, chevron: false) {
                    VStack(alignment: .leading, spacing: Theme.Space.s12) {
                        Text(target.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()
                            .locale(Locale(identifier: "az"))))
                            .font(.subheadline.weight(.medium)).foregroundStyle(Theme.textMuted)
                        // Every subject examined in this session.
                        VStack(alignment: .leading, spacing: Theme.Space.s8) {
                            ForEach(group, id: \.self) { s in
                                HStack(spacing: Theme.Space.s10) {
                                    SubjectIcon(course: s, size: 28)
                                    Text(s).font(.headline).foregroundStyle(Theme.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        HStack(spacing: Theme.Space.s8) {
                            unit(d, "gün")
                            unit(h, "saat")
                            unit(m, "dəqiqə")
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(group.joined(separator: ", ")) imtahanına \(d) gün \(h) saat \(m) dəqiqə qalıb")
            } else {
                CardShell(title: "Geri sayım", symbol: "hourglass", tint: Theme.success, chevron: false) {
                    Text("Bütün imtahanlar bitib 🎉").font(.headline).foregroundStyle(Theme.text)
                }
            }
        }
    }

    private func unit(_ v: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(v)")
                .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText(countsDown: true))
            Text(label).font(.caption).foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.s10)
        .background(Theme.surfaceInner, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

// MARK: - Exam readiness

/// "İmtahan hazırlığı": per subject the days / time left to its exam, how much of its question set is
/// learned (2 correct in a row) and the answer accuracy. A row opens the subject's statistics.
private struct ExamReadinessCard: View {
    @Environment(StudyStore.self) private var store

    var body: some View {
        let dates = ExamDates.shared
        CardShell(title: "İmtahan hazırlığı", symbol: "calendar.badge.clock", tint: .red,
                  caption: dates.nextSummary ?? "İmtahanlar bitib", chevron: false) {
            VStack(spacing: 0) {
                // Nearest exam first; finished ones at the end.
                let order = Catalog.subjects.sorted { a, b in
                    let oa = dates.isOver(a), ob = dates.isOver(b)
                    return oa != ob ? !oa : dates.date(for: a) < dates.date(for: b)
                }
                ForEach(Array(order.enumerated()), id: \.element) { i, s in
                    NavigationLink(value: Route.subjectStats(s)) { row(s, dates) }
                        .buttonStyle(.plain)
                    if i < order.count - 1 { Divider().padding(.leading, 44) }
                }
                Text("Hazırlıq: öyrənilmiş suallar (2 dəfə ardıcıl düz). Dəqiqlik: bütün cavabların düz faizi.")
                    .font(.caption).foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Space.s8)
            }
        }
    }

    private func row(_ s: String, _ dates: ExamDates) -> some View {
        let m = store.masteryProgress(s)
        let ready = m.total > 0 ? Int((Double(m.learned) / Double(m.total) * 100).rounded()) : 0
        let acc = store.subjectStatsRow(s).accuracy
        let over = dates.isOver(s)
        let d = dates.daysLeft(s)
        let when = over ? "Keçib" : (d == 0 ? "Bu gün \(dates.timeText(s))" : (d == 1 ? "Sabah \(dates.timeText(s))" : "\(d) gün"))
        let dateText = dates.date(for: s).formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "az")))
        return HStack(spacing: Theme.Space.s12) {
            SubjectIcon(course: s, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(StudyStore.shortSubject(s)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(when).font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(over ? Theme.textMuted : (d <= 2 ? Theme.warning : Theme.text))
                }
                ProgressLine(fraction: Double(ready) / 100, height: 4)
                HStack(alignment: .firstTextBaseline) {
                    Text("Hazırlıq \(ready)% · \(m.learned)/\(m.total)")
                    if let acc { Text("· Dəqiqlik \(acc)%").foregroundStyle(StatsFormat.tone(acc)) }
                    Spacer(minLength: 4)
                    Text(dateText)
                }
                .font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted).lineLimit(1).minimumScaleFactor(0.8)
            }
            Chevron()
        }
        .padding(.vertical, Theme.Space.s10)
        .contentShape(Rectangle())
        .opacity(over ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Summary pieces

/// "Vize · 1–7-ci ünitələr" — which mode every number on the page follows; opens Ayarlar.
private struct ScopeChip: View {
    @Environment(StudyStore.self) private var store
    var body: some View {
        NavigationLink(value: Route.settings) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                Text(store.examModeLabel)
                Image(systemName: "chevron.right").font(.caption2.weight(.bold))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.accent.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Rejimi Ayarlarda dəyiş")
    }
}

private struct StatsSectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.title3.weight(.bold)).foregroundStyle(Theme.text)
            .padding(.top, Theme.Space.s12)
            .padding(.leading, Theme.Space.s4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Health summary card: tinted title · caption ›, then a big value + unit and a mini chart.
struct MetricCard<Mini: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    var caption: String? = nil
    let value: String
    var unit: String = ""
    var note: String? = nil
    @ViewBuilder var mini: () -> Mini

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s12) {
            HStack(spacing: 6) {
                Image(systemName: symbol).symbolVariant(.fill).foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let caption {
                    Text(caption).font(.footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
                }
                Chevron()
            }
            HStack(alignment: .bottom, spacing: Theme.Space.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                        if !unit.isEmpty {
                            Text(unit).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textMuted)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    if let note {
                        Text(note).font(.footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                mini()
            }
        }
        .padding(Theme.Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Seven thin bars, today highlighted.
struct MiniBars: View {
    let values: [Double]
    let tint: Color
    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { item in
            BarMark(x: .value("Gün", String(item.offset)), y: .value("Say", item.element), width: .ratio(0.55))
                .foregroundStyle(item.offset == values.count - 1 ? tint : tint.opacity(0.35))
                .clipShape(Capsule())
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(values.max() ?? 0, 1))
        .frame(width: 84, height: 40)
        .accessibilityHidden(true)
    }
}

/// Accuracy line over the last days (gaps where nothing was answered), last point marked.
struct MiniLine: View {
    let values: [Double?]
    let tint: Color
    var body: some View {
        let pts = values.enumerated().compactMap { i, v in v.map { (i, $0) } }
        Chart(pts, id: \.0) { i, v in
            LineMark(x: .value("Gün", i), y: .value("%", v))
                .foregroundStyle(tint)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            if i == pts.last?.0 {
                PointMark(x: .value("Gün", i), y: .value("%", v)).foregroundStyle(tint).symbolSize(36)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: 0...max(values.count - 1, 1))
        .chartYScale(domain: 0...100)
        .frame(width: 84, height: 40)
        .accessibilityHidden(true)
    }
}

// MARK: - Detail pages

enum StatsMetric: String, Hashable, Sendable {
    case today, accuracy, questions, time, wrong, learning

    var title: String {
        switch self {
        case .today: "Bu gün"
        case .accuracy: "Dəqiqlik"
        case .questions: "İşlənən suallar"
        case .time: "Vaxt"
        case .wrong: "Səhv suallar"
        case .learning: "Öyrənilmiş suallar"
        }
    }

    /// "Ətraflı sıralama" rows shown on this page.
    var rankings: [StatDetailType] {
        switch self {
        case .accuracy: [.accuracy, .correct, .wrong]
        case .questions: [.total]
        case .time: [.time]
        case .today, .wrong, .learning: []
        }
    }
}

/// A Statistika card's own page, Apple Health style: chart with range picker, highlights, details.
struct StatsMetricView: View {
    let metric: StatsMetric
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var detail: StatDetailType?

    var body: some View {
        let t = store.homeTotals()
        HealthPage {
            switch metric {
            case .today: today(t)
            case .accuracy: accuracy(t)
            case .questions: questions(t)
            case .time: time(t)
            case .wrong: wrong()
            case .learning: learning()
            }

            if !metric.rankings.isEmpty {
                HealthSectionTitle(text: "Sıralama")
                HealthGroup {
                    ForEach(metric.rankings) { type in
                        HealthRow(title: type.rowTitle, symbol: type.symbol, tint: type.tint) { detail = type }
                    }
                }
                Text("Bütün fənn, sınaq və imtahanlar bu göstəriciyə görə.")
                    .font(.footnote).foregroundStyle(Theme.textMuted).padding(.horizontal, Theme.Space.s4)
            }
        }
        .navigationTitle(metric.title)
        .navigationSubtitle(store.examModeLabel)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $detail) { type in
            StatDetailSheet(type: type)
                .appEnvironment()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder private func highlights(_ series: StatsSeries) -> some View {
        let items = store.statsHighlights(series)
        if !items.isEmpty {
            HealthSectionTitle(text: "Əsas məqamlar")
            ForEach(items) { HighlightCard(item: $0) }
        }
    }

    // MARK: Bu gün

    @ViewBuilder private func today(_ t: HomeTotals) -> some View {
        let level = store.dailyLevel
        let target = Double(max(level.target, 1))
        let okFrac = min(1, Double(t.todayCorrect) / target)
        let badFrac = min(1 - okFrac, Double(t.todayWrong) / target)
        VStack(spacing: Theme.Space.s16) {
            RingDial(accent: okFrac, danger: badFrac, lineWidth: 16) {
                VStack(spacing: 0) {
                    Text("\(level.count)").font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Theme.text)
                    Text("/ \(level.target) sual").font(.subheadline).foregroundStyle(Theme.textMuted)
                }
            }
            .frame(width: 180, height: 180)
            Text(level.level).font(.headline).foregroundStyle(Theme.text)
            HStack(spacing: Theme.Space.s8) {
                StatTile(label: "Düz", value: "\(t.todayCorrect)", tone: Theme.success)
                StatTile(label: "Səhv", value: "\(t.todayWrong)", tone: Theme.danger)
                StatTile(label: "Hədəf", value: "\(Int((level.progress * 100).rounded()))%")
            }
        }
        .padding(Theme.Space.s16)
        .frame(maxWidth: .infinity)
        .card()
        .accessibilityElement(children: .combine)

        HealthGroup {
            HealthRow(title: "Platformada", symbol: "iphone", tint: Theme.warning, value: StatsFormat.duration(t.todayPlatformTime))
            HealthRow(title: "Testlərdə", symbol: "timer", tint: Theme.warning, value: StatsFormat.duration(t.todayTestTime))
        }

        HealthSectionTitle(text: "Günlər")
        HealthChartCard(series: .answers, tint: Theme.accent)
        highlights(.answers)
    }

    // MARK: Dəqiqlik

    @ViewBuilder private func accuracy(_ t: HomeTotals) -> some View {
        HealthChartCard(series: .accuracy, tint: Theme.success)
        highlights(.accuracy)

        HealthSectionTitle(text: "Ümumi")
        AccuracySummaryRow(answered: t.globalAnswered, total: t.totalQuestions, correct: t.globalCorrect, wrong: t.globalWrong)
            .padding(Theme.Space.s16).frame(maxWidth: .infinity, alignment: .leading).card()
        if t.globalAnswered > 0 {
            let ok = store.allCorrectQuestions().count, bad = store.allWrongQuestions().count
            HealthGroup {
                HealthRow(title: "Düz cavablanan suallar", symbol: "checkmark.circle.fill", tint: Theme.success, value: "\(ok)") {
                    router.start(.reviewAll(correct: true))
                }
                .disabled(ok == 0)
                HealthRow(title: "Hazırda səhv olan suallar", symbol: "xmark.circle.fill", tint: Theme.danger, value: "\(bad)") {
                    router.start(.reviewAll(correct: false))
                }
                .disabled(bad == 0)
            }
            Text("Toxunun və həmin sualları yenidən işləyin. Sonradan düz cavabladığınız səhv suallar səhv siyahısından çıxır.")
                .font(.footnote).foregroundStyle(Theme.textMuted).padding(.horizontal, Theme.Space.s4)
        }
    }

    // MARK: İşlənən suallar

    @ViewBuilder private func questions(_ t: HomeTotals) -> some View {
        HealthChartCard(series: .answers, tint: .indigo)
        highlights(.answers)

        HealthSectionTitle(text: "Ümumi")
        AccuracySummaryRow(answered: t.globalAnswered, total: t.totalQuestions, correct: t.globalCorrect, wrong: t.globalWrong)
            .padding(Theme.Space.s16).frame(maxWidth: .infinity, alignment: .leading).card()
        HealthSectionTitle(text: "Fənlər")
        subjectsCard
    }

    /// Every subject's answered share, opening its page.
    private var subjectsCard: some View {
        let rows = store.subjectStatsRows()
        return HealthGroup {
            ForEach(rows) { r in
                NavigationLink(value: Route.subjectStats(r.key)) {
                    HStack(spacing: Theme.Space.s8) {
                        SubjectStatsRowView(row: r)
                        Chevron()
                    }
                    .padding(.vertical, Theme.Space.s10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Vaxt

    @ViewBuilder private func time(_ t: HomeTotals) -> some View {
        HealthChartCard(series: .minutes, tint: Theme.warning)
        highlights(.minutes)

        HealthSectionTitle(text: "Ümumi")
        HealthGroup {
            HealthRow(title: "Ümumi sərf edilən vaxt", symbol: "clock.fill", tint: Theme.warning, value: StatsFormat.duration(t.globalTime))
            HealthRow(title: "Bu gün platformada", symbol: "iphone", tint: Theme.warning, value: StatsFormat.duration(t.todayPlatformTime))
            HealthRow(title: "Bu gün testlərdə", symbol: "timer", tint: Theme.warning, value: StatsFormat.duration(t.todayTestTime))
        }
    }

    // MARK: Öyrənmə

    @ViewBuilder private func learning() -> some View {
        let rows = Catalog.subjects.map { ($0, store.masteryProgress($0)) }
            .sorted { Double($0.1.learned) / Double(max($0.1.total, 1)) < Double($1.1.learned) / Double(max($1.1.total, 1)) }
        let learned = rows.reduce(0) { $0 + $1.1.learned }, total = rows.reduce(0) { $0 + $1.1.total }
        VStack(spacing: Theme.Space.s12) {
            RingDial(accent: Double(learned) / Double(max(total, 1)), danger: 0, lineWidth: 16) {
                VStack(spacing: 0) {
                    Text("\(StudyStore.pct(learned, max(total, 1)))%").font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit().foregroundStyle(Theme.text)
                    Text("\(learned) / \(total)").font(.subheadline).monospacedDigit().foregroundStyle(Theme.textMuted)
                }
            }
            .frame(width: 170, height: 170)
            Text("Bir sual ardıcıl 2 dəfə düz cavablananda öyrənilmiş sayılır.")
                .font(.footnote).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
        }
        .padding(Theme.Space.s20)
        .frame(maxWidth: .infinity)
        .card()

        HealthSectionTitle(text: "Fənlər")
        HealthGroup {
            ForEach(rows, id: \.0) { subject, p in
                Button { router.start(.unlearned(subject)) } label: {
                    HStack(spacing: Theme.Space.s12) {
                        SubjectIcon(course: subject, size: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subject).foregroundStyle(Theme.text).lineLimit(2)
                            ProgressView(value: Double(p.learned), total: Double(max(p.total, 1))).tint(.purple)
                            Text("\(p.learned)/\(p.total) · \(p.total - p.learned) qalıb")
                                .font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted)
                        }
                        Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.purple)
                    }
                    .padding(.vertical, Theme.Space.s10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(p.learned >= p.total)
            }
        }
        Text("Toxunun: o fənnin öyrənilməmiş sualları başlayır. Ən az hazır olan fənn yuxarıdadır.")
            .font(.footnote).foregroundStyle(Theme.textMuted).padding(.horizontal, Theme.Space.s4)
    }

    // MARK: Səhvlər

    @ViewBuilder private func wrong() -> some View {
        let total = store.wrongTotal
        HealthChartCard(series: .wrong, tint: Theme.danger)
        highlights(.wrong)

        HealthSectionTitle(text: "Səhv suallar")
        HealthGroup {
            NavigationLink(value: Route.wrong) {
                HealthRow(title: "Bütün səhv suallar", symbol: "xmark.octagon.fill", tint: Theme.danger, value: "\(total)", chevron: true)
            }
            .buttonStyle(.plain)
            HealthRow(title: "Çətin (2+ səhv)", symbol: "flame", tint: Theme.warning, value: "\(store.hardCount)")
            HealthRow(title: "Çox çətin (3+ səhv)", symbol: "flame.fill", tint: Theme.warning, value: "\(store.veryHardCount)")
        }
        if store.hardCount > 0 {
            Button { router.start(.hard) } label: {
                Label("Ən çətinləri işlə", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .largeControl()
            .padding(.top, Theme.Space.s8)
        }
        HealthAbout(text: "Səhv etdiyiniz hər sual burada toplanır. Bir sualı neçə dəfə səhv etsəniz, o qədər çətin sayılır; Ağıllı təkrar onları vaxtı çatdıqca yenidən göstərir.")
            .padding(.top, Theme.Space.s8)
    }
}
