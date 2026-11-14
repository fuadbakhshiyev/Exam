import Foundation
import Observation

// "Nailiyyətlər": a fixed catalogue of achievements. Most are derived from the synced data (history,
// stats, correct/wrong lists); the few that need a moment in time (a 20-question run, clearing today's
// review, a simulation score, the hour of an answer) are counted by the answer hook. Unlock dates and
// those counters are device-local (Application Support/Imtahan/achievements.json) and never synced, so
// the sync wire format is unchanged. Unlocks are permanent ("Statistikanı sıfırla" keeps them).

enum AchievementGroup: String, CaseIterable, Sendable, Identifiable {
    case answers, streak, accuracy, subjects, habits
    var id: String { rawValue }
    var title: String {
        switch self {
        case .answers: "Suallar"
        case .streak: "Ardıcıllıq"
        case .accuracy: "Dəqiqlik"
        case .subjects: "Fənlər"
        case .habits: "Vərdişlər"
        }
    }
}

struct Achievement: Identifiable, Hashable, Sendable {
    let id: String
    let group: AchievementGroup
    let symbol: String
    let title: String
    /// Short condition, also used for "son: …" in the Statistika row.
    let detail: String

    static let all: [Achievement] = [
        .init(id: "answers-100", group: .answers, symbol: "checkmark.circle.fill", title: "İlk addımlar", detail: "100 sual"),
        .init(id: "answers-500", group: .answers, symbol: "checklist", title: "Yarım min", detail: "500 sual"),
        .init(id: "answers-1000", group: .answers, symbol: "square.stack.3d.up.fill", title: "Min sual", detail: "1000 sual"),
        .init(id: "answers-2500", group: .answers, symbol: "books.vertical.fill", title: "Sual ustası", detail: "2500 sual"),
        .init(id: "answers-5000", group: .answers, symbol: "building.columns.fill", title: "Beş min", detail: "5000 sual"),
        .init(id: "marathon-100", group: .answers, symbol: "bolt", title: "Məhsuldar gün", detail: "Bir gündə 100 sual"),
        .init(id: "marathon-300", group: .answers, symbol: "bolt.fill", title: "Maraton günü", detail: "Bir gündə 300 sual"),
        .init(id: "streak-3", group: .streak, symbol: "flame", title: "Başlanğıc", detail: "3 gün ardıcıl"),
        .init(id: "streak-7", group: .streak, symbol: "flame.fill", title: "Bir həftə", detail: "7 gün ardıcıl"),
        .init(id: "streak-14", group: .streak, symbol: "calendar.badge.checkmark", title: "İki həftə", detail: "14 gün ardıcıl"),
        .init(id: "streak-21", group: .streak, symbol: "calendar", title: "Üç həftə", detail: "21 gün ardıcıl"),
        .init(id: "streak-30", group: .streak, symbol: "crown.fill", title: "Bir ay", detail: "30 gün ardıcıl"),
        .init(id: "sharp-20", group: .accuracy, symbol: "scope", title: "Dəqiq atıcı", detail: "Testdə 20 sualdan ≥90%"),
        .init(id: "perfect-20", group: .accuracy, symbol: "star.fill", title: "Mükəmməl 20", detail: "Testdə 20/20 düz"),
        .init(id: "combo-10", group: .accuracy, symbol: "bolt.heart.fill", title: "Seriya", detail: "10 sual ardıcıl düz"),
        .init(id: "combo-25", group: .accuracy, symbol: "flame.circle.fill", title: "Alovlu seriya", detail: "25 sual ardıcıl düz"),
        .init(id: "combo-50", group: .accuracy, symbol: "sparkle", title: "Səhvsiz", detail: "50 sual ardıcıl düz"),
        .init(id: "sim-70", group: .accuracy, symbol: "graduationcap.fill", title: "İmtahana hazır", detail: "Simulyasiyada ≥70 bal"),
        .init(id: "sim-90", group: .accuracy, symbol: "trophy.fill", title: "Əla simulyasiya", detail: "Simulyasiyada ≥90 bal"),
        .init(id: "exam-80", group: .accuracy, symbol: "doc.text.fill", title: "Yüksək bal", detail: "Keçmiş imtahanda ≥80 bal"),
        .init(id: "exam-100", group: .accuracy, symbol: "checkmark.seal.fill", title: "Tam bal", detail: "Keçmiş imtahanda 100 bal"),
        .init(id: "subject-complete", group: .subjects, symbol: "rosette", title: "Fənn ustası", detail: "Bir fənnin bütün sualları"),
        .init(id: "subject-80", group: .subjects, symbol: "medal.fill", title: "Fənn bilicisi", detail: "Fəndə ≥80% (100+ cavab)"),
        .init(id: "all-subjects", group: .subjects, symbol: "square.grid.2x2.fill", title: "Hamısına toxun", detail: "Hər fəndən 50+ sual"),
        .init(id: "learned-100", group: .subjects, symbol: "brain.head.profile.fill", title: "Yaddaşda", detail: "100 sual öyrənildi"),
        .init(id: "learned-500", group: .subjects, symbol: "brain.fill", title: "Bilik xəzinəsi", detail: "500 sual öyrənildi"),
        .init(id: "subject-learned", group: .subjects, symbol: "graduationcap.circle.fill", title: "Fənni bitirdim", detail: "Bir fənnin bütün sualları öyrənildi"),
        .init(id: "final-units", group: .subjects, symbol: "flag.checkered", title: "Final hazırlığı", detail: "8–14-cü ünitələr tam"),
        .init(id: "review-1", group: .habits, symbol: "arrow.triangle.2.circlepath", title: "Təkrar günü", detail: "Günün təkrarını bitir"),
        .init(id: "review-10", group: .habits, symbol: "repeat.circle.fill", title: "Təkrar ustası", detail: "Təkrarı 10 dəfə bitir"),
        .init(id: "pool-done", group: .habits, symbol: "square.stack.fill", title: "Hamısını keçdim", detail: "Bütün suallar testini sona çatdır"),
        .init(id: "surprise-10", group: .habits, symbol: "sparkles", title: "Sürprizə hazır", detail: "10 sürpriz sual düz"),
        .init(id: "surprise-50", group: .habits, symbol: "wand.and.stars", title: "Sürpriz ustası", detail: "50 sürpriz sual düz"),
        .init(id: "early-bird", group: .habits, symbol: "sunrise.fill", title: "Erkən quş", detail: "07:00-dan əvvəl sual"),
        .init(id: "night-owl", group: .habits, symbol: "moon.stars.fill", title: "Gecə bayquşu", detail: "23:00-dan sonra sual"),
    ]

    static func byID(_ id: String) -> Achievement? { all.first { $0.id == id } }
}

/// One achievement with its progress, for the grid.
struct AchievementStatus: Identifiable, Hashable, Sendable {
    let achievement: Achievement
    let value: Int
    let goal: Int
    let unlockedAt: Date?
    var id: String { achievement.id }
    var isUnlocked: Bool { unlockedAt != nil }
    var fraction: Double { goal > 0 ? min(1, Double(value) / Double(goal)) : 0 }
    /// "340/500"; nil for one-shot achievements.
    var progressText: String? { goal > 1 ? "\(min(value, goal))/\(goal)" : nil }
}

/// Device-local unlock dates + the event counters the data can't give back.
@MainActor
@Observable
final class AchievementStore {
    static let shared = AchievementStore()

    struct FileShape: Codable {
        var unlocked: [String: Date] = [:]
        /// Times "Bu günün təkrarı" was emptied (at most once a day).
        var reviewClears = 0
        var lastReviewClearDay: String?
        /// Best simulation average (Bal, 0…100).
        var bestSimulation: Double = 0
        /// Current run of answers inside one test (category|sub), for the 20-question achievements.
        var runKey = ""
        var run: [Bool] = []
        var runLast: Date?
        /// False until the first evaluation (which unlocks existing progress without toasts).
        var initialized = false
        /// Correct answers in a row (any test) and the best such run.
        var combo = 0
        var bestCombo = 0
        /// Best graded past-exam score (Bal, 0…100).
        var bestExam: Double = 0
        /// "Bütün suallar" / "Öyrənilməmişlər" tests answered to the end.
        var poolFinishes = 0

        init() {}

        /// Missing keys keep their defaults, so adding a counter never drops the saved unlocks.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            unlocked = try c.decodeIfPresent([String: Date].self, forKey: .unlocked) ?? [:]
            reviewClears = try c.decodeIfPresent(Int.self, forKey: .reviewClears) ?? 0
            lastReviewClearDay = try c.decodeIfPresent(String.self, forKey: .lastReviewClearDay)
            bestSimulation = try c.decodeIfPresent(Double.self, forKey: .bestSimulation) ?? 0
            runKey = try c.decodeIfPresent(String.self, forKey: .runKey) ?? ""
            run = try c.decodeIfPresent([Bool].self, forKey: .run) ?? []
            runLast = try c.decodeIfPresent(Date.self, forKey: .runLast)
            initialized = try c.decodeIfPresent(Bool.self, forKey: .initialized) ?? false
            combo = try c.decodeIfPresent(Int.self, forKey: .combo) ?? 0
            bestCombo = try c.decodeIfPresent(Int.self, forKey: .bestCombo) ?? 0
            bestExam = try c.decodeIfPresent(Double.self, forKey: .bestExam) ?? 0
            poolFinishes = try c.decodeIfPresent(Int.self, forKey: .poolFinishes) ?? 0
        }
    }

    private(set) var file = FileShape()
    /// Unlocked achievements waiting for their toast.
    var toastQueue: [Achievement] = []

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored var checkTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        let url = fileURL ?? StudyStore.defaultFileURL().deletingLastPathComponent().appendingPathComponent("achievements.json")
        self.fileURL = url
        if let raw = try? Data(contentsOf: url), let f = try? JSONDecoder().decode(FileShape.self, from: raw) {
            file = f
        }
    }

    var unlockedCount: Int { file.unlocked.keys.filter { Achievement.byID($0) != nil }.count }

    /// Most recently unlocked achievement.
    var latest: Achievement? {
        file.unlocked.filter { Achievement.byID($0.key) != nil }.max { $0.value < $1.value }.flatMap { Achievement.byID($0.key) }
    }

    func mutate(_ body: (inout FileShape) -> Void) {
        body(&file)
        scheduleSave()
    }

    /// Records the unlock; `announce` queues the toast.
    func unlock(_ a: Achievement, at date: Date = Date(), announce: Bool) {
        guard file.unlocked[a.id] == nil else { return }
        mutate { $0.unlocked[a.id] = date }
        guard announce else { return }
        toastQueue.append(a)
        AchievementToastPresenter.shared.kick()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            self.flush()
        }
    }

    func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard let raw = try? JSONEncoder().encode(file) else { return }
        let url = fileURL
        Task.detached(priority: .utility) { try? raw.write(to: url, options: .atomic) }
    }
}

/// Everything the derived achievements need, computed in one pass.
struct AchievementMetrics: Sendable {
    var totalAnswered = 0
    /// Day each answer threshold was crossed.
    var answerDates: [Int: Date] = [:]
    var bestDay = 0
    var bestDayDate: Date?
    var bestDay100Date: Date?
    var bestStreak = 0
    /// Day each streak length was first reached.
    var streakDates: [Int: Date] = [:]
    var currentStreak = 0
    /// Best subject: answered / total in-scope questions.
    var subjectDone = 0
    var subjectTotal = 0
    /// Best subject toward "≥80% with ≥100 answers" (0…100).
    var masteryValue = 0
    var subjectsWith50 = 0
    var surpriseCorrect = 0
    /// Learned questions (MasteryStore) over all subjects, and the best subject's learned/total.
    var learnedTotal = 0
    var subjectLearned = 0
    var subjectLearnedTotal = 0
    var finalUnitsDone = 0
    var finalUnitsTotal = 0
}

extension StudyStore {
    var achievements: AchievementStore { AchievementStore.shared }

    static let achievementAnswerGoals = [100, 500, 1000, 2500, 5000]
    static let achievementStreakGoals = [3, 7, 14, 21, 30]
    static let achievementRunLength = 20
    static let reviewSub = "Bu günün təkrarı"

    // MARK: Hooks

    /// Called once per recorded answer (recordQuizAnswer). Cheap: counts the event-based achievements,
    /// then schedules one evaluation of the derived ones shortly after (the answer feedback is already on
    /// screen by then; a simulation hand-in coalesces into one pass).
    func noteAchievementAnswer(_ q: Question, isCorrect: Bool, stat: (course: String, cat: String, sub: String)?) {
        let ach = achievements
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 7, let a = Achievement.byID("early-bird") { ach.unlock(a, announce: ach.file.initialized) }
        if hour >= 23, let a = Achievement.byID("night-owl") { ach.unlock(a, announce: ach.file.initialized) }

        // A test = consecutive answers of one category/sub with < 30 min between them.
        let key = stat.map { "\($0.cat)|\($0.sub)" } ?? "plain|\(q.c)"
        var hit90 = false, hit100 = false
        ach.mutate { f in
            if f.runKey != key || (f.runLast.map { now.timeIntervalSince($0) > 1800 } ?? true) {
                f.runKey = key
                f.run = []
            }
            f.runLast = now
            f.combo = isCorrect ? f.combo + 1 : 0
            f.bestCombo = max(f.bestCombo, f.combo)
            f.run.append(isCorrect)
            if f.run.count > Self.achievementRunLength { f.run.removeFirst(f.run.count - Self.achievementRunLength) }
            if f.run.count == Self.achievementRunLength {
                let ok = f.run.filter { $0 }.count
                hit90 = Double(ok) >= Double(Self.achievementRunLength) * 0.9
                hit100 = ok == Self.achievementRunLength
            }
        }
        if hit90, let a = Achievement.byID("sharp-20") { ach.unlock(a, announce: true) }
        if hit100, let a = Achievement.byID("perfect-20") { ach.unlock(a, announce: true) }

        // "Bu günün təkrarı" emptied (counted once a day).
        if stat?.sub == Self.reviewSub {
            let today = Self.dayKey(now)
            if ach.file.lastReviewClearDay != today && reviewDueCount == 0 {
                ach.mutate { $0.reviewClears += 1; $0.lastReviewClearDay = today }
            }
        }
        scheduleAchievementCheck()
    }

    /// Simulation handed in (ExamSimulation.submit).
    func noteSimulationFinished(average: Double) {
        if average > achievements.file.bestSimulation { achievements.mutate { $0.bestSimulation = average } }
        scheduleAchievementCheck()
    }

    /// A finished test (QuizSession.finish): graded past-exam score, whole-pool tests.
    func noteTestFinished(gradedScore: Double?, finishedPool: Bool) {
        achievements.mutate { f in
            if let g = gradedScore, g > f.bestExam { f.bestExam = g }
            if finishedPool { f.poolFinishes += 1 }
        }
        scheduleAchievementCheck()
    }

    /// Coalesced evaluateAchievements(announce: true) after a short delay.
    func scheduleAchievementCheck() {
        let ach = achievements
        guard ach.checkTask == nil else { return }
        ach.checkTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            ach.checkTask = nil
            self?.evaluateAchievements(announce: true)
        }
    }

    // MARK: Evaluation

    /// Unlocks every achievement whose goal is reached. The very first pass is silent (existing progress).
    func evaluateAchievements(announce: Bool) {
        let ach = achievements
        let first = !ach.file.initialized
        let m = achievementMetrics()
        for s in achievementStatuses(m) where !s.isUnlocked && s.value >= s.goal && s.goal > 0 {
            ach.unlock(s.achievement, at: derivedUnlockDate(s.achievement.id, m) ?? Date(), announce: announce && !first)
        }
        if first { ach.mutate { $0.initialized = true } }
    }

    /// Statuses in catalogue order.
    func achievementStatuses(_ metrics: AchievementMetrics? = nil) -> [AchievementStatus] {
        let m = metrics ?? achievementMetrics()
        let f = achievements.file
        return Achievement.all.map { a in
            let (value, goal) = progress(a.id, m, f)
            return AchievementStatus(achievement: a, value: value, goal: goal, unlockedAt: f.unlocked[a.id])
        }
    }

    private func progress(_ id: String, _ m: AchievementMetrics, _ f: AchievementStore.FileShape) -> (Int, Int) {
        let unlocked = f.unlocked[id] != nil
        switch id {
        case "answers-100": return (m.totalAnswered, 100)
        case "answers-500": return (m.totalAnswered, 500)
        case "answers-1000": return (m.totalAnswered, 1000)
        case "answers-2500": return (m.totalAnswered, 2500)
        case "answers-5000": return (m.totalAnswered, 5000)
        case "marathon-100": return (m.bestDay, 100)
        case "marathon-300": return (m.bestDay, 300)
        case "streak-3": return (m.bestStreak, 3)
        case "streak-7": return (m.bestStreak, 7)
        case "streak-14": return (m.bestStreak, 14)
        case "streak-21": return (m.bestStreak, 21)
        case "streak-30": return (m.bestStreak, 30)
        case "combo-10": return (f.bestCombo, 10)
        case "combo-25": return (f.bestCombo, 25)
        case "combo-50": return (f.bestCombo, 50)
        case "sim-70": return (Int(f.bestSimulation.rounded(.down)), 70)
        case "sim-90": return (Int(f.bestSimulation.rounded(.down)), 90)
        case "exam-80": return (Int(f.bestExam.rounded(.down)), 80)
        case "exam-100": return (Int(f.bestExam.rounded(.down)), 100)
        case "learned-100": return (m.learnedTotal, 100)
        case "learned-500": return (m.learnedTotal, 500)
        case "subject-learned": return (m.subjectLearned, max(m.subjectLearnedTotal, 1))
        case "pool-done": return (f.poolFinishes, 1)
        case "subject-complete": return (m.subjectDone, max(m.subjectTotal, 1))
        case "subject-80": return (m.masteryValue, 100)
        case "all-subjects": return (m.subjectsWith50, Catalog.subjects.count)
        case "final-units": return (m.finalUnitsDone, max(m.finalUnitsTotal, 1))
        case "review-1": return (f.reviewClears, 1)
        case "review-10": return (f.reviewClears, 10)
        case "surprise-10": return (m.surpriseCorrect, 10)
        case "surprise-50": return (m.surpriseCorrect, 50)
        default: return (unlocked ? 1 : 0, 1)   // event-based one-shots (sharp/perfect/early/night)
        }
    }

    /// When a derived achievement was really earned (answer counts, best day, streaks); nil = now.
    private func derivedUnlockDate(_ id: String, _ m: AchievementMetrics) -> Date? {
        let parts = id.split(separator: "-")
        guard parts.count == 2, let n = Int(parts[1]) else { return nil }
        let date: Date?
        switch parts[0] {
        case "answers": date = m.answerDates[n]
        case "streak": date = m.streakDates[n]
        case "marathon": date = n == 100 ? m.bestDay100Date : m.bestDayDate
        default: date = nil
        }
        // Earned today → the actual moment.
        guard let date, Self.dayKey(date) != Self.dayKey() else { return nil }
        return date
    }

    func achievementMetrics(now: Date = Date()) -> AchievementMetrics {
        var m = AchievementMetrics()

        // History: totals, best day, streaks (and when each goal was reached).
        var cumulative = 0
        var run = 0
        var prevKey: String?
        for key in data.history.keys.sorted() {
            let n = data.history[key]?.courses.values.reduce(0) { $0 + $1.correct + $1.wrong } ?? 0
            guard n > 0 else { continue }
            let date = Self.date(fromDayKey: key)
            let before = cumulative
            cumulative += n
            for g in Self.achievementAnswerGoals where before < g && cumulative >= g { m.answerDates[g] = date }
            if n > m.bestDay {
                if m.bestDay < 300 && n >= 300 { m.bestDayDate = date }
                if m.bestDay < 100 && n >= 100 { m.bestDay100Date = date }
                m.bestDay = n
            }
            if let prevKey, let d = date, let p = Self.date(fromDayKey: prevKey),
               Self.dayKey(Calendar.current.date(byAdding: .day, value: 1, to: p) ?? p) == Self.dayKey(d) {
                run += 1
            } else {
                run = 1
            }
            prevKey = key
            if run > m.bestStreak {
                m.bestStreak = run
                if Self.achievementStreakGoals.contains(run) { m.streakDates[run] = date }
            }
        }
        m.totalAnswered = cumulative
        m.currentStreak = studyStreak(now: now).days

        // Subjects (current exam mode).
        for subject in Catalog.subjects {
            let qs = scopedQuestions(course: subject)
            if !qs.isEmpty {
                let seen = Set((data.correct[subject] ?? []).map(\.q)).union((data.wrong[subject] ?? []).map(\.q))
                let done = qs.filter { seen.contains($0.q) }.count
                if m.subjectTotal == 0 || Double(done) / Double(qs.count) > Double(m.subjectDone) / Double(m.subjectTotal) {
                    m.subjectDone = done
                    m.subjectTotal = qs.count
                }
            }
            let mp = masteryProgress(subject)
            m.learnedTotal += mp.learned
            if mp.total > 0, m.subjectLearnedTotal == 0
                || Double(mp.learned) / Double(mp.total) > Double(m.subjectLearned) / Double(m.subjectLearnedTotal) {
                m.subjectLearned = mp.learned
                m.subjectLearnedTotal = mp.total
            }

            let agg = courseAggregate(subject)
            if agg.t >= 50 { m.subjectsWith50 += 1 }
            let acc = agg.t > 0 ? Double(agg.c) / Double(agg.t) : 0
            m.masteryValue = max(m.masteryValue, acc >= 0.8 ? min(agg.t, 100) : min(agg.t, 99))

            // Final units (8+), each fully worked through once (unit stats ≥ its question count).
            let units = data.stats[subject]?.bd["units"] ?? [:]
            for u in stride(from: 8, through: Catalog.unitCounts[subject] ?? 0, by: 1) {
                let total = bank.unitQuestions(course: subject, unit: u).count
                guard total > 0 else { continue }
                m.finalUnitsTotal += 1
                if let st = units["Unit \(u)"], st.c + st.w >= total { m.finalUnitsDone += 1 }
            }
        }

        m.surpriseCorrect = data.stats.values.reduce(0) { $0 + ($1.bd["surprise"]?["Sürpriz Sual"]?.c ?? 0) }
        return m
    }

    /// Noon of a local "YYYY-MM-DD".
    nonisolated static func date(fromDayKey key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12))
    }

    // MARK: Weekly report

    /// Answers and accuracy from `weekStart` (a day start) through today, plus the current streak.
    func weeklySummary(from weekStart: Date, now: Date = Date()) -> (answered: Int, accuracy: Int, streak: Int) {
        let cal = Calendar.current
        var day = cal.startOfDay(for: weekStart)
        var correct = 0, total = 0
        while day <= now {
            for c in data.history[Self.dayKey(day)]?.courses.values.map({ $0 }) ?? [] {
                correct += c.correct
                total += c.correct + c.wrong
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return (total, Self.pct(correct, total), studyStreak(now: now).days)
    }
}
