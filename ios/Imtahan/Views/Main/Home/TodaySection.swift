import SwiftUI

/// "Bu gün" on Ana səhifə: the spaced-repetition review, the per-subject daily plan and the weakest
/// units, in one list section. The header carries the exam countdown.
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
        Section {
            reviewRow(due).appRow()
            ForEach(plan) { row in
                planRow(row).appRow()
            }
            if let w = weak.first {
                weakRow(w).appRow()
            }
        } header: {
            header
        } footer: {
            Text("Plan: hər fənnin hələ cavablanmamış sualları imtahana qalan günlərə bölünür.")
        }
    }

    // MARK: Header (countdown)

    private var header: some View {
        _ = examDateRaw
        let days = StudyStore.daysUntil(store.examDate)
        let text = days > 0 ? "İmtahana \(days) gün" : (days == 0 ? "İmtahan bu gündür" : "İmtahan tarixi keçib")
        return HStack(alignment: .firstTextBaseline) {
            Text("Bu gün")
                .font(.headline)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Label(text, systemImage: "calendar")
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(days <= 3 ? Theme.warning : Theme.textMuted)
                .labelStyle(.titleAndIcon)
        }
        .textCase(nil)
    }

    // MARK: Review

    @ViewBuilder
    private func reviewRow(_ due: Int) -> some View {
        if due > 0 {
            Button { router.start(.review) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 40, height: 40)
                        .background(Theme.accent.opacity(0.15), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bu gün təkrar: \(due) sual")
                            .font(.headline).foregroundStyle(Theme.text).monospacedDigit().lineLimit(1)
                        Text(due > 50 ? "Ən gecikmişlərdən 50-si" : "Vaxtı çatmış səhvlər")
                            .font(.subheadline).foregroundStyle(Theme.textMuted).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "play.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bu gün təkrar: \(due) sual")
            .accessibilityHint("Təkrarı başladır")
        } else {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.success)
                    .frame(width: 40, height: 40)
                    .background(Theme.success.opacity(0.15), in: .circle)
                Text("Təkrar yoxdur ✓")
                    .font(.body).foregroundStyle(Theme.textMuted)
                Spacer()
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Plan

    private func planRow(_ r: DailyPlanRow) -> some View {
        Button { router.start(.unit(course: r.subject, index: r.nextUnit)) } label: {
            HStack(spacing: 12) {
                SubjectIcon(course: r.subject, size: 28)
                    .padding(.horizontal, 6)
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

    private func weakRow(_ w: WeakUnit) -> some View {
        Button(action: openWeakTopics) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.warning)
                    .frame(width: 28, height: 28)
                    .background(Theme.warning.opacity(0.15), in: .circle)
                    .padding(.horizontal, 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Zəif mövzular").font(.body).foregroundStyle(Theme.text)
                    Text("\(w.title) · \(w.accuracy)%")
                        .font(.footnote).monospacedDigit().foregroundStyle(Theme.textMuted).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .contentShape(Rectangle())
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
