import Foundation

// Small read-only series for the Statistika summary cards (Health-style mini charts).
// Daily history is kept per course, not per unit, so the exam mode can only drop the Final booklet
// keys ("_final_") in Vize mode; everything else already goes through scopedStat.

struct StatsDay: Hashable, Sendable, Identifiable {
    var id: String { day }
    let day: String
    let correct: Int
    let wrong: Int
    let seconds: Int
    var answered: Int { correct + wrong }
    /// 0…100, nil when nothing was answered that day.
    var accuracy: Double? { answered > 0 ? Double(correct) * 100 / Double(answered) : nil }
}

extension StudyStore {
    /// Does a daily-history course key count in the current mode?
    func historyKeyInScope(_ key: String) -> Bool {
        examMode == .final || !QuestionBank.isFinalKey(key)
    }

    /// The last `count` days ending today (oldest first), in-scope courses only.
    func recentStatsDays(_ count: Int = 7, now: Date = Date()) -> [StatsDay] {
        (0..<count).reversed().map { back in
            let date = Calendar.current.date(byAdding: .day, value: -back, to: now) ?? now
            let key = Self.dayKey(date)
            var c = 0, w = 0, t = 0
            for (k, v) in data.history[key]?.courses ?? [:] where historyKeyInScope(k) {
                c += v.correct; w += v.wrong; t += v.time
            }
            return StatsDay(day: key, correct: c, wrong: w, seconds: t)
        }
    }
}
