import SwiftUI

/// "Statistika" tab. Three calm views behind a segmented control instead of one long list:
/// - Ümumi:  today + overall summary, activity chart, reset.
/// - Fənlər: every subject (tap for its detail page) and the per-metric rankings.
/// - Səhvlər: wrong questions, how hard they are, and practising the hardest.
/// Everything follows the current exam mode (Vize / Final).
struct StatisticsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var segment: StatsSegment = .overview
    @State private var detail: StatDetailType?

    var body: some View {
        List {
            Section {
                Picker("Bölmə", selection: $segment.animation(.snappy)) {
                    ForEach(StatsSegment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .listSectionSpacing(Theme.Space.s8)

            switch segment {
            case .overview: StatsOverviewSections()
            case .subjects: StatsSubjectsSections(detail: $detail)
            case .wrong: StatsWrongSections()
            }
        }
        .appListStyle()
        .navigationTitle("Statistika")
        .navigationSubtitle("\(store.examMode.title) rejimi")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $detail) { type in
            StatDetailSheet(type: type)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

enum StatsSegment: String, CaseIterable, Identifiable {
    case overview, subjects, wrong
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: "Ümumi"
        case .subjects: "Fənlər"
        case .wrong: "Səhvlər"
        }
    }
}

// MARK: - Ümumi

private struct StatsOverviewSections: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let t = store.homeTotals()
        today(t)
        overall(t)

        Section {
            DynamicsChartCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text("Fəallıq")
        }

        Section {
            ResetStatsButton()
        }
    }

    // Bu gün: daily goal ring + today's answers, then where today's time went.
    private func today(_ t: HomeTotals) -> some View {
        let level = store.dailyLevel
        let target = Double(max(level.target, 1))
        let okFrac = min(1, Double(t.todayCorrect) / target)
        let badFrac = min(1 - okFrac, Double(t.todayWrong) / target)
        return Section("Bu gün") {
            HStack(spacing: Theme.Space.s16) {
                RingDial(accent: okFrac, danger: badFrac, lineWidth: 8) {
                    VStack(spacing: 0) {
                        Text("\(Int((level.progress * 100).rounded()))%")
                            .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.text)
                        Text("hədəf").font(.system(size: 9)).foregroundStyle(Theme.textMuted)
                    }
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(level.count)").font(.title2.weight(.bold)).foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                        Text("/ \(level.target) sual").font(.subheadline).foregroundStyle(Theme.textMuted)
                    }
                    .monospacedDigit()
                    Text("Hədəf: \(level.level)").font(.footnote).foregroundStyle(Theme.textMuted)
                    if t.todayCorrect + t.todayWrong > 0 {
                        HStack(spacing: Theme.Space.s12) {
                            CountDot(text: "\(t.todayCorrect) düz", color: Theme.success)
                            CountDot(text: "\(t.todayWrong) səhv", color: Theme.danger)
                        }
                        .font(.footnote)
                    } else {
                        Text("Hələ sual işlənməyib").font(.footnote).foregroundStyle(Theme.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Space.s4)
            .accessibilityElement(children: .combine)
            .appRow()

            ValueRow(title: "Platformada", symbol: "iphone", value: StatsFormat.duration(t.todayPlatformTime))
                .appRow()
            ValueRow(title: "Testlərdə", symbol: "timer", value: StatsFormat.duration(t.todayTestTime))
                .appRow()
        }
    }

    // Ümumi: accuracy over the whole bank, the answers to review, total time.
    private func overall(_ t: HomeTotals) -> some View {
        Section {
            AccuracySummaryRow(answered: t.globalAnswered, total: t.totalQuestions, correct: t.globalCorrect, wrong: t.globalWrong)
                .appRow()
            ValueRow(title: "Sərf edilən vaxt", symbol: "clock", value: StatsFormat.duration(t.globalTime))
                .appRow()
            if t.globalAnswered > 0 {
                ReviewCountRow(title: "Düz cavablar", count: t.globalCorrect, symbol: "checkmark.circle.fill", tint: Theme.success) {
                    router.start(.reviewAll(correct: true))
                }
                ReviewCountRow(title: "Səhv cavablar", count: t.globalWrong, symbol: "xmark.circle.fill", tint: Theme.danger) {
                    router.start(.reviewAll(correct: false))
                }
            }
        } header: {
            Text("Ümumi")
        } footer: {
            if t.globalAnswered > 0 { Text("Düz və ya səhv cavablarınızı yenidən işləmək üçün toxunun.") }
        }
    }
}

// MARK: - Fənlər

private struct StatsSubjectsSections: View {
    @Binding var detail: StatDetailType?
    @Environment(StudyStore.self) private var store

    var body: some View {
        Section {
            ForEach(store.subjectStatsRows()) { r in
                NavigationLink(value: Route.subjectStats(r.key)) { SubjectStatsRowView(row: r) }
                    .appRow()
            }
        } header: {
            Text("Fənlər üzrə")
        } footer: {
            Text("Bölmələr, imtahanlar və vaxt üçün fənnə toxunun.")
        }

        Section {
            ForEach(StatDetailType.allCases) { type in
                Button { detail = type } label: {
                    HStack {
                        StatLabel(title: type.rowTitle, symbol: type.symbol, tint: type.tint)
                        Spacer()
                        Chevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .appRow()
            }
        } header: {
            Text("Ətraflı sıralama")
        } footer: {
            Text("Hər göstərici üzrə bütün fənn, sınaq və imtahanların sıralaması.")
        }
    }
}

// MARK: - Səhvlər

private struct StatsWrongSections: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let total = store.wrongTotal
        if total == 0 {
            Section {
                ContentUnavailableView("Səhv sual yoxdur", systemImage: "checkmark.seal",
                                       description: Text("Testlərdə səhv etdiyiniz suallar burada toplanacaq."))
                    .listRowBackground(Color.clear)
            }
        }

        Section {
            NavigationLink(value: Route.wrong) {
                HStack {
                    StatLabel(title: "Səhv suallar", symbol: "xmark.octagon.fill", tint: Theme.danger)
                    Spacer(minLength: 8)
                    if total > 0 { Text("\(total)").monospacedDigit().foregroundStyle(Theme.textMuted) }
                }
            }
            .appRow()
        } footer: {
            Text("Səhv etdiyiniz bütün suallar, mənbələrə görə.")
        }

        if total > 0 {
            Section {
                ValueRow(title: "Çətin (2+ səhv)", symbol: "flame", value: "\(store.hardCount)", tint: Theme.warning)
                    .appRow()
                ValueRow(title: "Çox çətin (3+ səhv)", symbol: "flame.fill", value: "\(store.veryHardCount)", tint: Theme.warning)
                    .appRow()
            } header: {
                Text("Çətinlik")
            } footer: {
                Text("Bir neçə dəfə səhv etdiyiniz suallar.")
            }

            Section {
                Button { router.start(.hard) } label: {
                    Label("Ən çətinləri işlə", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
    }
}
