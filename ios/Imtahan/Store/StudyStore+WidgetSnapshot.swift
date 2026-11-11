import Foundation
import WidgetKit

// Home / Lock Screen widgets: after study data changes (finishChange / applyRemote / exam mode) the store
// writes a StudySnapshot to the app group (debounced) and reloads the widget timelines when it changed.
// The same pass refreshes the daily study reminder with today's count.

extension StudyStore {
    /// Debounced snapshot write; cheap to call on every mutation (timer ticks included).
    func widgetDataDidChange() { WidgetSnapshotWriter.shared.schedule(self) }

    /// Immediate write (launch, going to background).
    func writeWidgetSnapshotNow() { WidgetSnapshotWriter.shared.writeNow(self) }

    func makeWidgetSnapshot(now: Date = Date()) -> StudySnapshot {
        let todayKey = Self.dayKey(now)
        let today = data.history[todayKey]
        let correct = today?.courses.values.reduce(0) { $0 + $1.correct } ?? 0
        let wrong = today?.courses.values.reduce(0) { $0 + $1.wrong } ?? 0
        let level = DailyLevel.forCount(correct + wrong)
        let start = DailyLevel.forCount(0)
        let (streak, includesToday) = studyStreak(now: now)
        return StudySnapshot(
            dayKey: todayKey, answered: correct + wrong, correct: correct, wrong: wrong,
            levelName: level.level, target: level.target, startLevelName: start.level, startTarget: start.target,
            streak: streak, streakIncludesToday: includesToday, modeTitle: examMode.title, updatedAt: now)
    }

    /// Consecutive days with ≥ 1 answer from data.history, ending today — or yesterday while today has none yet.
    func studyStreak(now: Date = Date()) -> (days: Int, includesToday: Bool) {
        func answered(_ d: Date) -> Bool {
            guard let day = data.history[Self.dayKey(d)] else { return false }
            return day.courses.values.contains { $0.correct + $0.wrong > 0 }
        }
        let cal = Calendar.current
        var day = cal.startOfDay(for: now)
        let includesToday = answered(day)
        if !includesToday { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while answered(day), count < 3650 {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return (count, includesToday)
    }
}

@MainActor
final class WidgetSnapshotWriter {
    static let shared = WidgetSnapshotWriter()

    private var pending: Task<Void, Never>?
    private var lastWritten: StudySnapshot?

    func schedule(_ store: StudyStore) {
        guard pending == nil else { return }
        pending = Task { [weak self, weak store] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, let store else { return }
            self.pending = nil
            self.writeNow(store)
        }
    }

    func writeNow(_ store: StudyStore) {
        pending?.cancel()
        pending = nil
        let snap = store.makeWidgetSnapshot()
        StudyReminder.shared.refresh(answered: snap.answered)
        // Skip identical content (timer ticks change nothing the widgets show).
        if var prev = lastWritten {
            prev.updatedAt = snap.updatedAt
            if prev == snap { return }
        }
        lastWritten = snap
        StudySnapshotStorage.save(snap)
        WidgetCenter.shared.reloadTimelines(ofKind: StudySnapshotStorage.widgetKind)
    }
}
