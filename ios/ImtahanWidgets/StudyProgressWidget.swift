import SwiftUI
import WidgetKit

// Daily progress widget (Home Screen small/medium, Lock Screen circular/rectangular).
// Data: StudySnapshot written by the app to the app group (Shared/StudySnapshot.swift).

struct StudyEntry: TimelineEntry {
    let date: Date
    let snapshot: StudySnapshot
}

struct StudyProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyEntry { StudyEntry(date: Date(), snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (StudyEntry) -> Void) {
        let s = context.isPreview ? (StudySnapshotStorage.load() ?? .placeholder) : (StudySnapshotStorage.load() ?? .empty)
        completion(StudyEntry(date: Date(), snapshot: s.resolved()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyEntry>) -> Void) {
        let now = Date()
        let stored = StudySnapshotStorage.load() ?? .empty
        var entries = [StudyEntry(date: now, snapshot: stored.resolved(at: now))]
        // Roll over at midnight (today's counts → 0) without the app having to run.
        let cal = Calendar.current
        if let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) {
            entries.append(StudyEntry(date: midnight, snapshot: stored.resolved(at: midnight)))
            if let next = cal.date(byAdding: .day, value: 1, to: midnight) {
                entries.append(StudyEntry(date: next, snapshot: stored.resolved(at: next)))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct StudyProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: StudySnapshotStorage.widgetKind, provider: StudyProvider()) { entry in
            StudyWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "imtahan://home"))
        }
        .configurationDisplayName("Gündəlik hədəf")
        .description("Bu günün sual sayı, hədəf və ardıcıl günlər.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private enum WPalette {
    static let accent = StopwatchPalette.accent
    static let bg = StopwatchPalette.background
    static let track = Color(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2C / 255)
    static let muted = StopwatchPalette.muted
    static let success = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    static let danger = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)
    static let flame = Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x0A / 255)
}

struct StudyWidgetView: View {
    let snapshot: StudySnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: CircularView(s: snapshot)
        case .accessoryRectangular: RectangularView(s: snapshot)
        case .systemMedium: MediumView(s: snapshot).containerBackground(WPalette.bg, for: .widget)
        default: SmallView(s: snapshot).containerBackground(WPalette.bg, for: .widget)
        }
    }
}

// MARK: Home Screen

private struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().stroke(WPalette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(progress >= 1 ? WPalette.success : WPalette.accent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct RingWithCount: View {
    let s: StudySnapshot
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            ProgressRing(progress: s.progress, lineWidth: lineWidth)
            VStack(spacing: 0) {
                Text("\(s.answered)")
                    .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("/ \(s.target)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(WPalette.muted)
            }
            .padding(lineWidth + 4)
        }
    }
}

private struct SmallView: View {
    let s: StudySnapshot

    var body: some View {
        VStack(spacing: 8) {
            RingWithCount(s: s)
            Text(s.levelName.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(WPalette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct MediumView: View {
    let s: StudySnapshot

    var body: some View {
        HStack(spacing: 18) {
            RingWithCount(s: s, lineWidth: 11)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Hədəf: \(s.levelName)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Text(s.modeTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WPalette.accent)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(WPalette.accent.opacity(0.18), in: Capsule())
                }
                Text(s.remaining > 0 ? "\(s.remaining) sual qalıb" : "Hədəfə çatdın ✓")
                    .font(.system(size: 12))
                    .foregroundStyle(s.remaining > 0 ? WPalette.muted : WPalette.success)
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    stat("checkmark.circle.fill", "\(s.correct)", WPalette.success)
                    stat("xmark.circle.fill", "\(s.wrong)", WPalette.danger)
                    stat("flame.fill", "\(s.streak) gün", WPalette.flame)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func stat(_ icon: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: Lock Screen

private struct CircularView: View {
    let s: StudySnapshot

    var body: some View {
        Gauge(value: s.progress) {
            Image(systemName: "book.fill")
        } currentValueLabel: {
            Text("\(s.answered)").monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(.clear, for: .widget)
    }
}

private struct RectangularView: View {
    let s: StudySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(s.answered)/\(s.target)")
                    .font(.headline.monospacedDigit())
                    .widgetAccentable()
                Text(s.levelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Gauge(value: s.progress) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
            Text(s.streak > 0 ? "🔥 \(s.streak) gün ardıcıl" : "Bu gün başla 💪")
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }
}
