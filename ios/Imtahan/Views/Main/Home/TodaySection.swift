import SwiftUI

/// "Bu gün" on Ana səhifə, as Health-style cards: the spaced-repetition review, the per-subject daily
/// plan and the weakest units. The title line carries the exam countdown.
struct TodaySection: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    /// Mirrors StudyStore.examDate so a change in Settings refreshes the countdown and plan.
    @AppStorage(StudyStore.examDateKey) private var examDateRaw: Double = 0
    let openWeakTopics: () -> Void

    var body: some View {
        let due = store.reviewDueCount
        let plan = store.dailyPlan()
        let weak = store.weakUnits(limit: 1)
        header
        reviewCard(due)
        if !plan.isEmpty { planCard(plan) }
        if let w = weak.first { weakCard(w) }
    }

    // MARK: Header (countdown)

    private var header: some View {
        _ = examDateRaw
        // Nearest subject exam (Ayarlar → İmtahan tarixləri).
        let next = ExamDates.shared.next
        let days = next?.days ?? -1
        let text = ExamDates.shared.nextSummary ?? "İmtahanlar bitib"
        return HStack(alignment: .firstTextBaseline) {
            Text("Bu gün")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Label(text, systemImage: "calendar")
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(days <= 3 ? Theme.warning : Theme.textMuted)
                .labelStyle(.titleAndIcon)
        }
        .padding(.top, Theme.Space.s12)
        .padding(.horizontal, Theme.Space.s4)
    }

    // MARK: Review

    private func reviewCard(_ due: Int) -> some View {
        Button { router.push(.reviewHub) } label: {
            MetricCard(title: "Ağıllı təkrar", symbol: "arrow.trianglehead.2.clockwise", tint: .teal,
                       value: "\(due)", unit: "sual",
                       note: due == 0 ? "Bu gün təkrar yoxdur ✓" : (due > 50 ? "Ən gecikmişlərdən 50-si" : "Vaxtı çatmış səhvlər")) {
                if due > 0 {
                    Image(systemName: "play.circle.fill").font(.system(size: 34)).foregroundStyle(.teal)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Fənlər üzrə təkrarı açır")
    }

    // MARK: Plan card

    private func planCard(_ plan: [DailyPlanRow]) -> some View {
        CardShell(title: "Günün planı", symbol: "list.bullet.clipboard.fill", tint: .indigo,
                  caption: "\(plan.filter(\.isComplete).count)/\(plan.count) tamam", chevron: false) {
            VStack(spacing: 0) {
                ForEach(Array(plan.enumerated()), id: \.element.id) { i, row in
                    planRow(row).padding(.vertical, Theme.Space.s8)
                    if i < plan.count - 1 { Divider().padding(.leading, 40) }
                }
                Text("Cavablanmamış suallar imtahana qalan günlərə bölünür.")
                    .font(.caption).foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Space.s8)
            }
        }
    }

    // MARK: Plan

    private func planRow(_ r: DailyPlanRow) -> some View {
        Button { router.start(.unit(course: r.subject, index: r.nextUnit)) } label: {
            HStack(spacing: 12) {
                SubjectIcon(course: r.subject, size: 28)
                Text(StudyStore.shortSubject(r.subject))
                    .font(.body).foregroundStyle(Theme.text).lineLimit(1)
                Spacer(minLength: 8)
                trailing(r)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(StudyStore.shortSubject(r.subject))
        .accessibilityValue(planAccessibility(r))
        .accessibilityHint("Növbəti ünitəni başladır")
    }

    @ViewBuilder
    private func trailing(_ r: DailyPlanRow) -> some View {
        if r.remaining == 0 && r.planned == 0 {
            Text("Hamısı cavablanıb ✓")
                .font(.subheadline).foregroundStyle(Theme.success).lineLimit(1)
        } else if r.isComplete {
            Text("Bu gün plan tamamlandı ✓")
                .font(.subheadline).foregroundStyle(Theme.success).lineLimit(1).minimumScaleFactor(0.85)
        } else {
            Text(r.doneToday > 0 ? "\(r.doneToday)/\(r.planned) sual" : "\(r.planned) sual")
                .font(.subheadline).monospacedDigit().foregroundStyle(Theme.textMuted).lineLimit(1)
        }
    }

    private func planAccessibility(_ r: DailyPlanRow) -> String {
        if r.remaining == 0 && r.planned == 0 { return "Bütün suallar cavablanıb" }
        if r.isComplete { return "Bu gün plan tamamlandı" }
        return "Bu gün \(r.planned) sual, \(r.doneToday) cavablanıb"
    }

    // MARK: Weak units

    private func weakCard(_ w: WeakUnit) -> some View {
        Button(action: openWeakTopics) {
            MetricCard(title: "Zəif mövzular", symbol: "chart.line.downtrend.xyaxis", tint: Theme.warning,
                       value: "\(w.accuracy)", unit: "%", note: w.title) { EmptyView() }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Zəif mövzular")
        .accessibilityValue("\(w.title), \(w.accuracy) faiz")
    }
}

/// Pushed from "Bu gün": the weakest in-scope units and a mixed practice of them.
struct WeakTopicsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let units = store.weakUnits()
        List {
            Section {
                Button { router.start(.weakTopics) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.onInverse)
                            .frame(width: 40, height: 40)
                            .background(Theme.accent, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zəif mövzuları məşq et").font(.headline).foregroundStyle(Theme.text)
                            Text("Bu ünitələrdən 30 sual, qarışıq")
                                .font(.subheadline).foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(units.isEmpty)
                .appRow()
            }

            Section {
                if units.isEmpty {
                    Text("Hələ kifayət qədər cavab yoxdur: ünitədən ən azı 5 sual cavablandırın.")
                        .font(.subheadline).foregroundStyle(Theme.textMuted)
                        .appRow()
                }
                ForEach(units) { u in
                    Button { router.start(.unit(course: u.subject, index: u.unit - 1)) } label: {
                        HStack(spacing: 12) {
                            SubjectIcon(course: u.subject, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.title).font(.body).foregroundStyle(Theme.text).lineLimit(1)
                                Text("\(u.correct)/\(u.answered) düz")
                                    .font(.footnote).monospacedDigit().foregroundStyle(Theme.textMuted)
                            }
                            Spacer(minLength: 8)
                            Text("\(u.accuracy)%")
                                .font(.subheadline.weight(.medium)).monospacedDigit()
                                .foregroundStyle(u.accuracy < 60 ? Theme.danger : (u.accuracy < 80 ? Theme.warning : Theme.textCaption))
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Ünitəni başladır")
                    .appRow()
                }
            } header: {
                Text("Ən zəif ünitələr")
            } footer: {
                Text("\(store.examMode.title) rejimindəki, ən azı 5 cavabı olan ünitələr — düzgün cavab faizinə görə.")
            }
        }
        .appListStyle()
        .pageTitle("Zəif mövzular")
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

/// "Ağıllı təkrar": what is due today per subject, each startable, plus everything at once.
struct ReviewHubView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let rows = store.reviewDueBySubject()
        let total = store.reviewDueCount
        HealthPage {
            VStack(alignment: .leading, spacing: Theme.Space.s12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(total)").font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Theme.text)
                    Text("sual bu gün").font(.headline).foregroundStyle(Theme.textMuted)
                }
                Text(total == 0 ? "Bu gün təkrar yoxdur ✓" : "Səhv etdiyiniz suallar artan aralıqlarla yenidən soruşulur: düz cavab verdikcə gec, səhv etdikcə tez qayıdır.")
                    .font(.subheadline).foregroundStyle(Theme.textMuted)
                if total > 0 {
                    Button { router.start(.review) } label: {
                        Label(total > 50 ? "Hamısını başlat (ən gecikmiş 50)" : "Hamısını başlat", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.teal)
                    .largeControl()
                }
            }
            .padding(Theme.Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            HealthSectionTitle(text: "Fənlər üzrə")
            HealthGroup {
                ForEach(rows.sorted { $0.count > $1.count }, id: \.subject) { r in
                    Button { router.start(.reviewSubject(r.subject)) } label: {
                        HStack(spacing: Theme.Space.s12) {
                            SubjectIcon(course: r.subject, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.subject).foregroundStyle(Theme.text).lineLimit(2)
                                Text(r.count == 0 ? "Təkrar yoxdur ✓" : "\(r.count) sual" + (r.count > 50 ? " · ən gecikmiş 50-si" : ""))
                                    .font(.footnote).monospacedDigit()
                                    .foregroundStyle(r.count == 0 ? Theme.success : Theme.textMuted)
                            }
                            Spacer(minLength: 8)
                            if r.count > 0 {
                                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.teal)
                            }
                        }
                        .padding(.vertical, Theme.Space.s10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(r.count == 0)
                    .accessibilityHint(r.count > 0 ? "Bu fənnin təkrarını başladır" : "")
                }
            }
            Text("Ən çox təkrarı olan fənn yuxarıdadır. Bir dəfədə ən çox 50 sual verilir.")
                .font(.footnote).foregroundStyle(Theme.textMuted).padding(.horizontal, Theme.Space.s4)
        }
        .navigationTitle("Ağıllı təkrar")
        .navigationBarTitleDisplayMode(.large)
        .task { store.seedReviewIfNeeded() }
    }
}
