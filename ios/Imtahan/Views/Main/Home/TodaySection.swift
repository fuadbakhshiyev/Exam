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
        let text: String = {
            guard let n = next else { return "İmtahanlar bitib" }
            let name = StudyStore.shortSubject(n.subject)
            let time = ExamDates.shared.timeText(n.subject)
            return n.days == 0 ? "\(name): bu gün \(time)" : (n.days == 1 ? "\(name): sabah \(time)" : "\(name): \(n.days) gün")
        }()
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
        Button { router.start(.review) } label: {
            MetricCard(title: "Ağıllı təkrar", symbol: "arrow.trianglehead.2.clockwise", tint: .teal,
                       value: "\(due)", unit: "sual",
                       note: due == 0 ? "Bu gün təkrar yoxdur ✓" : (due > 50 ? "Ən gecikmişlərdən 50-si" : "Vaxtı çatmış səhvlər")) {
                if due > 0 {
                    Image(systemName: "play.circle.fill").font(.system(size: 34)).foregroundStyle(.teal)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(due == 0)
        .accessibilityHint(due > 0 ? "Təkrarı başladır" : "")
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
