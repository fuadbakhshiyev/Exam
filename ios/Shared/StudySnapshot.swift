import Foundation

// Compiled into both the app and the ImtahanWidgets extension.
// The app writes a StudySnapshot (JSON) to the app-group UserDefaults whenever study data changes
// (Store/StudyStore+WidgetSnapshot.swift); the Home / Lock Screen widgets only read it.

/// Daily progress copied out of StudyStore for the widgets.
struct StudySnapshot: Codable, Sendable, Equatable {
    /// Local "YYYY-MM-DD" the counts belong to.
    var dayKey: String
    var answered: Int
    var correct: Int
    var wrong: Int
    /// DailyLevel for `answered` (name, next target).
    var levelName: String
    var target: Int
    /// DailyLevel for 0 answers — what a fresh day starts with.
    var startLevelName: String
    var startTarget: Int
    /// Consecutive days with ≥ 1 answer, ending today (or yesterday when today has none yet).
    var streak: Int
    /// True when today is part of `streak`.
    var streakIncludesToday: Bool
    /// "Vize" / "Final".
    var modeTitle: String
    var updatedAt: Date

    var progress: Double { target > 0 ? min(Double(answered) / Double(target), 1) : 0 }
    var remaining: Int { max(0, target - answered) }

    /// The snapshot as it reads on `date`: once the day it was written for is over, today's counts are 0
    /// and the streak survives only if the snapshot's day had answers and was yesterday.
    func resolved(at date: Date = Date()) -> StudySnapshot {
        let today = Self.dayKey(date)
        guard dayKey != today else { return self }
        var s = self
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date).map { Self.dayKey($0) }
        s.streak = (dayKey == yesterday && streakIncludesToday) ? streak : 0
        s.streakIncludesToday = false
        s.dayKey = today
        s.answered = 0; s.correct = 0; s.wrong = 0
        s.levelName = startLevelName
        s.target = startTarget
        return s
    }

    /// Local "YYYY-MM-DD" (same format as StudyStore.dayKey).
    static func dayKey(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static let placeholder = StudySnapshot(
        dayKey: dayKey(Date()), answered: 142, correct: 121, wrong: 21, levelName: "Novice", target: 200,
        startLevelName: "Amateur", startTarget: 50, streak: 6, streakIncludesToday: true, modeTitle: "Final",
        updatedAt: Date())

    static let empty = StudySnapshot(
        dayKey: dayKey(Date()), answered: 0, correct: 0, wrong: 0, levelName: "Amateur", target: 50,
        startLevelName: "Amateur", startTarget: 50, streak: 0, streakIncludesToday: false, modeTitle: "Vize",
        updatedAt: Date())
}

enum StudySnapshotStorage {
    static let key = "widget_study_snapshot"
    /// WidgetKit kind of the daily-progress widget.
    static let widgetKind = "ImtahanDailyProgress"

    static func load(from d: UserDefaults = StopwatchStorage.defaults) -> StudySnapshot? {
        guard let raw = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StudySnapshot.self, from: raw)
    }

    static func save(_ s: StudySnapshot, to d: UserDefaults = StopwatchStorage.defaults) {
        guard let raw = try? JSONEncoder().encode(s) else { return }
        d.set(raw, forKey: key)
    }
}
