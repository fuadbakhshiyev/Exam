import SwiftUI
import Charts

/// "Fənlərin inkişaf dinamikası": per-day stacked correct/wrong bars or minutes over the study period.
struct DynamicsChartCard: View {
    @Environment(StudyStore.self) private var store
    @State private var mode = 0
    @State private var course = "all"
    @State private var selected: Date?

    var body: some View {
        let pts = store.dynamicsSeries(course: course)
        let isTime = mode == 1
        let total = pts.reduce(0) { $0 + (isTime ? $1.minutes : $1.correct + $1.wrong) }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("İnkişaf dinamikası").font(.headline).foregroundStyle(Theme.text)
                Spacer()
                Picker("Fənn", selection: $course) {
                    ForEach(StudyStore.dynamicsFilters, id: \.value) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 180, alignment: .trailing)
            }
            Picker("Rejim", selection: $mode) {
                Text("Suallar").tag(0)
                Text("Sərf edilən vaxt").tag(1)
            }
            .pickerStyle(.segmented)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let p = DynamicsChart.point(at: selected, in: pts) {
                    Text(isTime ? "\(p.minutes)" : "\(p.correct + p.wrong)").font(.heroNumber).foregroundStyle(Theme.text)
                    Text(isTime ? "dəq · \(p.label)" : "sual · \(p.label) · \(p.correct) düz, \(p.wrong) səhv").font(.footnote).foregroundStyle(Theme.textMuted)
                } else {
                    Text("\(total)").font(.heroNumber).foregroundStyle(Theme.text)
                    Text(isTime ? "dəqiqə" : "sual").font(.subheadline).foregroundStyle(Theme.textMuted)
                }
            }
            .contentTransition(.numericText())
            DynamicsChart(points: pts, isTime: isTime, today: StudyStore.dayKey(), selected: $selected)
                .animation(.snappy, value: mode)
                .animation(.snappy, value: course)
        }
        .padding(16)
        .card()
    }
}

/// The bar chart itself. X is a real `Date` (one `.day` unit per bar), so Charts owns the axis geometry;
/// we only decide *which* days get a label, from the measured width, so labels can never collide.
struct DynamicsChart: View {
    let points: [DynamicsPoint]
    let isTime: Bool
    let today: String
    @Binding var selected: Date?

    /// Room one "22 noy" label needs (caption2 text + breathing space), scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .caption2) private var labelSlot: CGFloat = 48
    /// Leading y-axis label column ("200" in caption2 + gap) — subtracted to estimate the plot width.
    @ScaledMetric(relativeTo: .caption2) private var yAxisWidth: CGFloat = 28

    var body: some View {
        // GeometryReader (not onGeometryChange) so the very first pass already knows the width.
        GeometryReader { geo in chart(width: geo.size.width) }
            .frame(height: 170)
    }

    private func chart(width: CGFloat) -> some View {
        let rows = points.compactMap { p in Self.date(p.day).map { (p, $0) } }
        let selectedDay = Self.point(at: selected, in: points)?.day
        return Chart(rows, id: \.0.day) { p, date in
            let tint = p.day == today ? Theme.inverse : Theme.accent
            if isTime {
                BarMark(x: .value("Gün", date, unit: .day), y: .value("Dəq", p.minutes), width: .ratio(0.62))
                    .foregroundStyle(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                BarMark(x: .value("Gün", date, unit: .day), y: .value("Say", p.correct), width: .ratio(0.62))
                    .foregroundStyle(p.day == today ? Theme.inverse : Theme.success)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                BarMark(x: .value("Gün", date, unit: .day), y: .value("Say", p.wrong), width: .ratio(0.62))
                    .foregroundStyle(Theme.danger)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            if p.day == selectedDay {
                RuleMark(x: .value("Gün", date, unit: .day)).foregroundStyle(Theme.textMuted.opacity(0.4))
            }
        }
        .chartXSelection(value: $selected)
        .chartXAxis {
            // `.aligned` keeps the first/last label inside the plot; greedy collision resolution is a
            // safety net (e.g. huge Dynamic Type) — it drops a label rather than overlapping it.
            AxisMarks(preset: .aligned, values: labelDates(rows.map(\.1), width: width)) { v in
                AxisValueLabel(collisionResolution: .greedy) {
                    if let d = v.as(Date.self) {
                        Text(Self.shortLabel(d)).font(.caption2).foregroundStyle(Theme.textMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Theme.border)
                AxisValueLabel().font(.caption2).foregroundStyle(Theme.textMuted)
            }
        }
    }

    /// Every `step`-th day starting from the first, where `step` is the smallest "nice" stride whose
    /// spacing fits a label. Dates are noon, so each label sits centred under its bar.
    private func labelDates(_ dates: [Date], width: CGFloat) -> [Date] {
        guard !dates.isEmpty else { return [] }
        let plot = max(width - yAxisWidth, 1)
        let perDay = plot / CGFloat(dates.count)
        let step = [1, 2, 3, 4, 5, 7, 10, 14, 21, 28].first { CGFloat($0) * perDay >= labelSlot }
            ?? Int((labelSlot / perDay).rounded(.up))
        return stride(from: 0, to: dates.count, by: step).map { dates[$0] }
    }

    // MARK: - Helpers

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    private static let months = ["yan", "fev", "mar", "apr", "may", "iyn", "iyl", "avq", "sen", "okt", "noy", "dek"]

    /// "2026-11-03" → 3 Nov 2026, 12:00 local (same calendar as `StudyStore.dayKey`).
    static func date(_ key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12))
    }

    /// "3 noy" — Azerbaijani short month, matching `DynamicsPoint.label`.
    static func shortLabel(_ d: Date) -> String {
        let c = calendar.dateComponents([.day, .month], from: d)
        return "\(c.day ?? 0) \(months[(c.month ?? 1) - 1])"
    }

    /// The point whose day contains the selected x value.
    static func point(at date: Date?, in points: [DynamicsPoint]) -> DynamicsPoint? {
        guard let date else { return nil }
        let key = StudyStore.dayKey(date)
        return points.first { $0.day == key }
    }
}
