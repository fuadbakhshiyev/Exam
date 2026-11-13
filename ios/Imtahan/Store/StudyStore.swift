import Foundation
import Observation
import os

// Port of the QuizApp data layer (quiz.js): stats, wrong/correct lists, bookmarks, daily history,
// daily goal + level ladder, settings, quiz/platform timers, backup import/export and sync hooks.
// Read-only page models live in StudyStore+Dashboards.swift, question-set builders in
// StudyStore+QuestionSets.swift, timers in StudyStore+Timers.swift.

enum ThemeMode: String, CaseIterable, Sendable {
    case dark, light, system
}

enum DashboardLayout: String, CaseIterable, Sendable {
    case grid, table
}

/// The celebration shown when today's answered count hits a milestone (fireMotivationalCelebration).
struct Celebration: Hashable, Sendable, Identifiable {
    let milestone: Int
    let level: String
    let quote: String
    var id: Int { milestone }
    /// 3000 uses the special "LİMİTSİZ ZİRVƏ" card.
    var isUltimate: Bool { milestone == 3000 }
    var badge: String { isUltimate ? "🌌👑🏆👑🌌" : "🏆" }
    var title: String { isUltimate ? "🏆 LİMİTSİZ ZİRVƏ 🏆" : "YENİ SƏVİYYƏ" }
    var milestoneText: String { "Bugünkü Hədəf: \(milestone) Sual Cavablandırıldı!" }

    static let milestones = [50, 100, 200, 300, 500, 750, 1000, 1250, 1500, 1750, 2000, 2250, 2500, 2750, 3000]

    static func forMilestone(_ m: Int) -> Celebration {
        let table: [Int: (String, String)] = [
            50: ("Beginner", "İlk addım ən çətinidir. Sən başladın və irəliləyirsən! 🚀"),
            100: ("Novice", "Mükəmməllik vərdişdir. Hər gün daha da güclənirsən! 💪"),
            200: ("Intermediate", "Dayanmaq yoxdur! Limitlər yalnız zehindədir. 🧠"),
            300: ("Advanced", "Artıq digərlərindən bir addım öndəsən. Möhtəşəm nəticədir! ⭐"),
            500: ("Expert", "Fokuslanma və nizam-intizam. Əsl peşəkar kimi davam edirsən! 🔥"),
            750: ("Master", "Zirvəyə çox az qaldı. Sənin iradən sarsılmazdır! 👑"),
            1000: ("Grandmaster", "Möhtəşəm! Sən artıq bir Grandmaster-sən. Hədəfləri fəth etməyə davam et! 🏆"),
            1250: ("Conqueror", "Fatih! Sən çətinlikləri üstələyərək hər şeyi fəth edirsən! 🗡️"),
            1500: ("Champion", "Çempion! Qələbə sənin qanındadır. İlham verməyə davam et! 🏅"),
            1750: ("Legend", "Əfsanə! Adını bu günün tarixinə yazdın. İnanılmaz iradə! 🌟"),
            2000: ("Immortal", "Ölümsüz! Sən artıq bu sistemin ən uca zirvəsindəsən. Sərhədsiz güc! 🌌"),
            2250: ("Mythic", "Mifik! Sənin bu nailiyyətin dildən-dilə gəzəcək bir dastan yazır! 📖✨"),
            2500: ("Demi-God", "Yarı-Tanrı! Gücün və intizamın qarşısında heç bir sual dayana bilməz! ⚡"),
            2750: ("Godlike", "Tanrısal! Sənin iradən artıq bu aləmin fizika qanunlarını aşmışdır! 🌌☄️"),
            3000: ("Titan", "TİTAN! Sən sistemin ən uca zirvəsini fəth etdin, mükəmməlliyin canlı sübutusan! 👑🪐🏆"),
        ]
        let d = table[m] ?? ("Legend", "Hər gün bir addım irəli! Sərhədləri aşmağa davam et! 🌟")
        return Celebration(milestone: m, level: d.0, quote: d.1)
    }
}

/// Sidebar daily box (updateDaily): "c/target", bar width and "HƏDƏF: LEVEL".
struct DailyLevel: Hashable, Sendable {
    let count: Int
    let level: String
    let target: Int
    var text: String { "\(count)/\(target)" }
    var label: String { "HƏDƏF: \(level.uppercased())" }
    var progress: Double { target > 0 ? min(Double(count) / Double(target), 1) : 0 }

    static func forCount(_ c: Int) -> DailyLevel {
        let ladder: [(Int, String)] = [
            (50, "Amateur"), (100, "Beginner"), (200, "Novice"), (300, "Intermediate"), (500, "Advanced"),
            (750, "Expert"), (1000, "Master"), (1250, "Grandmaster"), (1500, "Conqueror"), (1750, "Champion"),
            (2000, "Legend"), (2250, "Immortal"), (2500, "Mythic"), (2750, "Demi-God"), (3000, "Godlike"),
        ]
        for (limit, name) in ladder where c < limit { return DailyLevel(count: c, level: name, target: limit) }
        return DailyLevel(count: c, level: "Titan", target: 3000)
    }
}

enum BackupImportError: LocalizedError, Equatable {
    case empty
    case invalid(String)
    case noKeys

    var errorDescription: String? {
        switch self {
        case .empty: return "Zəhmət olmasa, ehtiyat nüsxə JSON-unu daxil edin."
        case .invalid(let m): return "İdxal xətası: \(m)"
        case .noKeys: return "İdxal üçün uyğun açarlar (qa_v32_) tapılmadı."
        }
    }
}

@MainActor
@Observable
final class StudyStore {
    static let shared = StudyStore()

    // MARK: State

    /// Everything persisted for the semester. Mutate only through the store's methods so that
    /// updatedAt, persistence and onLocalChange stay correct.
    var data: StudyData

    /// Called after every local mutation. quick == true when wrong/correct/marks/wrongCounts/dailyGoal/settings
    /// changed, false for stats/history-only changes (timer ticks).
    @ObservationIgnored var onLocalChange: ((_ quick: Bool) -> Void)?

    /// Set when today's answered count reaches a milestone; the UI shows the card and sets it back to nil.
    var celebration: Celebration?

    /// web localStorage 'theme' (default 'dark').
    var theme: ThemeMode {
        didSet { defaults.set(theme.rawValue, forKey: Self.themeKey) }
    }

    /// Vize (units 1–7) or Final (all units). Device-local, changed only from Settings; every list, count and
    /// question pool reads it through inScope(_:) (StudyStore+Scope.swift).
    var examMode: ExamMode {
        didSet {
            guard examMode != oldValue else { return }
            defaults.set(examMode.rawValue, forKey: Self.examModeKey)
            widgetDataDidChange()
        }
    }

    /// web localStorage 'quiz_dashboard_layout' (Kart / Cədvəl).
    var dashboardLayout: DashboardLayout {
        didSet { defaults.set(dashboardLayout.rawValue, forKey: Self.layoutKey) }
    }

    // Timer state (see StudyStore+Timers.swift)
    /// Course whose time the quiz timer is accounting (QuizApp.activeCourse).
    var activeCourse: String?
    /// Seconds shown by the quiz timer (quizSecondsAccumulated + secondsElapsedInSession).
    var quizElapsedSeconds: Int = 0
    var isIdle = false
    /// True while the surprise question is open and unanswered (QuizApp.state.isSurpriseActive).
    var isSurpriseActive = false

    /// Identity of the QuizSession that started the running quiz timer.
    @ObservationIgnored var quizTimerOwner: UUID?
    @ObservationIgnored var quizTickTask: Task<Void, Never>?
    @ObservationIgnored var quizSessionStart: Int64 = 0
    @ObservationIgnored var quizSecondsInSession = 0
    @ObservationIgnored var quizSecondsAccumulated = 0
    @ObservationIgnored var platformTickTask: Task<Void, Never>?
    @ObservationIgnored var platformSessionStart: Int64 = 0
    @ObservationIgnored var platformSecondsInSession = 0
    @ObservationIgnored var lastActivityTime: Int64 = StudyStore.nowMs()
    @ObservationIgnored weak var surpriseEngine: SurpriseEngine?

    @ObservationIgnored let bank: QuestionBank
    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored let fileURL: URL
    @ObservationIgnored private let writer = StudyFileWriter()
    @ObservationIgnored private var saveGeneration: Int64 = 0
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var batchDepth = 0
    @ObservationIgnored private var batchChanged = false
    @ObservationIgnored private var batchQuick = false
    @ObservationIgnored var cachedConflicts: [ConflictGroup]?
    @ObservationIgnored var cachedScopedConflicts: [ExamMode: [ConflictGroup]] = [:]

    static let themeKey = "theme"
    static let layoutKey = "quiz_dashboard_layout"
    static let examModeKey = "exam_mode"
    static let fileName = "study-data.json"

    init(bank: QuestionBank = .shared, defaults: UserDefaults = .standard, fileURL: URL? = nil, startTimers: Bool = true) {
        self.bank = bank
        self.defaults = defaults
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        if let raw = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(StudyData.self, from: raw) {
            data = decoded
        } else {
            data = StudyData()
        }
        theme = ThemeMode(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .dark
        dashboardLayout = defaults.string(forKey: Self.layoutKey) == "table" ? .table : .grid
        examMode = ExamMode(rawValue: defaults.string(forKey: Self.examModeKey) ?? "") ?? .vize
        // loadData → updateDaily(false): refresh the daily goal without bumping updatedAt.
        refreshDailyGoal(notify: false)
        if startTimers { startPlatformTimer() }
    }

    static func defaultFileURL() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Imtahan", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    // MARK: Change tracking / persistence

    static func nowMs() -> Int64 { Int64((Date().timeIntervalSince1970 * 1000).rounded()) }

    /// Groups several mutations into one onLocalChange call.
    func batch(_ body: () -> Void) {
        batchDepth += 1
        body()
        batchDepth -= 1
        if batchDepth == 0 && batchChanged {
            let q = batchQuick
            batchChanged = false; batchQuick = false
            finishChange(quick: q)
        }
    }

    func markChanged(quick: Bool) {
        data.updatedAt = Self.nowMs()
        if batchDepth > 0 {
            batchChanged = true
            batchQuick = batchQuick || quick
            return
        }
        finishChange(quick: quick)
    }

    private func finishChange(quick: Bool) {
        scheduleSave(delay: quick ? 1 : 5)
        onLocalChange?(quick)
        widgetDataDidChange()
    }

    private func scheduleSave(delay: Double) {
        guard saveTask == nil else { return }
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.saveTask = nil
            self.saveGeneration += 1
            let gen = self.saveGeneration
            let snapshot = self.data
            let url = self.fileURL
            let writer = self.writer
            Task.detached(priority: .utility) { writer.write(snapshot, to: url, generation: gen) }
        }
    }

    /// Writes the current data synchronously (call when going to background).
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        saveGeneration += 1
        writer.write(data, to: fileURL, generation: saveGeneration)
    }

    /// Replaces data with the cloud copy. Does not call onLocalChange and keeps newData.updatedAt.
    func applyRemote(_ newData: StudyData) {
        data = newData
        scheduleSave(delay: 1)
        widgetDataDidChange()
    }

    // MARK: Date helpers

    /// Local "YYYY-MM-DD" (todayStr in quiz.js).
    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// JS Date.prototype.toDateString(), e.g. "Wed Nov 11 2026".
    static func jsDateString(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "EEE MMM dd yyyy"
        return f.string(from: date)
    }

    // MARK: Recording (recordStat / recordDailyHistory / recordPlatformTime)

    func recordStat(course c: String, cat: String, sub: String, isCorrect: Bool) {
        var s = data.stats[c] ?? CourseStat()
        var item = s.bd[cat]?[sub] ?? SubStat()
        item.t += 1
        if isCorrect { item.c += 1 } else { item.w += 1 }
        item.last = Self.nowMs()
        s.bd[cat, default: [:]][sub] = item
        var cc = 0, ww = 0, tt = 0
        for (_, subs) in s.bd { for (_, it) in subs { cc += it.c; ww += it.w; tt += it.t } }
        s.c = cc; s.w = ww; s.t = tt
        data.stats[c] = s
        recordDailyHistory(course: c, isCorrect: isCorrect, timeIncrement: 0, notify: false)
        markChanged(quick: false)
    }

    /// pdf keys ("<subj>_pdf_<i>") and final booklet keys ("<subj>_final_<id>") are folded into the subject. timeIncrement > 0 adds time, otherwise counts the answer.
    func recordDailyHistory(course: String, isCorrect: Bool?, timeIncrement: Int = 0) {
        recordDailyHistory(course: course, isCorrect: isCorrect, timeIncrement: timeIncrement, notify: true)
    }

    private func recordDailyHistory(course: String, isCorrect: Bool?, timeIncrement: Int, notify: Bool) {
        let today = Self.dayKey()
        let target = Self.foldPdfKey(course)
        var day = data.history[today] ?? DayRecord()
        var dc = day.courses[target] ?? DayCourse()
        if timeIncrement > 0 {
            dc.time += timeIncrement
        } else if isCorrect == true {
            dc.correct += 1
        } else {
            dc.wrong += 1
        }
        day.courses[target] = dc
        data.history[today] = day
        if notify { markChanged(quick: false) }
    }

    static func foldPdfKey(_ course: String) -> String { QuestionBank.baseCourse(course) }

    func recordPlatformTime(_ delta: Int) {
        let today = Self.dayKey()
        var day = data.history[today] ?? DayRecord()
        day.platformTime += delta
        data.history[today] = day
        var p = data.stats[Catalog.platformKey] ?? CourseStat()
        p.time += delta
        data.stats[Catalog.platformKey] = p
        markChanged(quick: false)
    }

    /// Quiz timer tick for a stat-tracked course: stats[c].time += delta plus today's history.
    func recordCourseTime(_ course: String, delta: Int) {
        var s = data.stats[course] ?? CourseStat()
        s.time += delta
        data.stats[course] = s
        recordDailyHistory(course: course, isCorrect: nil, timeIncrement: delta, notify: false)
        markChanged(quick: false)
    }

    // MARK: Wrong / correct lists, wrong counts, bookmarks

    func saveWrong(course c: String, _ q: Question) {
        var arr = data.wrong[c] ?? []
        guard !arr.contains(where: { $0.q == q.q }) else { return }
        arr.append(q)
        data.wrong[c] = arr
        markChanged(quick: true)
    }

    func removeWrong(course c: String, questionText qt: String) {
        guard var arr = data.wrong[c] else { return }
        arr.removeAll { $0.q == qt }
        data.wrong[c] = arr.isEmpty ? nil : arr
        markChanged(quick: true)
    }

    func saveCorrect(course c: String, _ q: Question) {
        var arr = data.correct[c] ?? []
        guard !arr.contains(where: { $0.q == q.q }) else { return }
        arr.append(q)
        data.correct[c] = arr
        markChanged(quick: true)
    }

    func removeCorrect(course c: String, questionText qt: String) {
        guard var arr = data.correct[c] else { return }
        arr.removeAll { $0.q == qt }
        data.correct[c] = arr.isEmpty ? nil : arr
        markChanged(quick: true)
    }

    func incrementWrongCount(_ questionText: String) {
        data.wrongCounts[questionText, default: 0] += 1
        markChanged(quick: true)
    }

    func wrongCount(_ questionText: String) -> Int { data.wrongCounts[questionText] ?? 0 }

    func isBookmarked(_ q: Question) -> Bool { data.marks.contains { $0.q == q.q } }

    /// Adds or removes the bookmark (matched by question text). Returns the new state.
    @discardableResult
    func toggleBookmark(_ q: Question) -> Bool {
        let on: Bool
        if let i = data.marks.firstIndex(where: { $0.q == q.q }) {
            data.marks.remove(at: i); on = false
        } else {
            data.marks.append(q); on = true
        }
        markChanged(quick: true)
        return on
    }

    /// checkAnswer's bookkeeping in one batch: lists, wrong count, stat, daily goal.
    /// `stat` nil = no stat (search mode / no course). Returns a milestone celebration if one was reached.
    @discardableResult
    func recordQuizAnswer(_ q: Question, isCorrect: Bool, removeFromWrongWhenCorrect: Bool,
                          stat: (course: String, cat: String, sub: String)?) -> Celebration? {
        var hit: Celebration?
        batch {
            if isCorrect {
                saveCorrect(course: q.c, q)
                if removeFromWrongWhenCorrect { removeWrong(course: q.c, questionText: q.q) }
            } else {
                saveWrong(course: q.c, q)
                removeCorrect(course: q.c, questionText: q.q)
                incrementWrongCount(q.q)
            }
            if let stat { recordStat(course: stat.course, cat: stat.cat, sub: stat.sub, isCorrect: isCorrect) }
            hit = updateDaily(increment: true)
            recordReview(q, isCorrect: isCorrect)
            noteAchievementAnswer(q, isCorrect: isCorrect, stat: stat)   // Nailiyyətlər (StudyStore+Achievements)
        }
        return hit
    }

    /// Surprise question bookkeeping (revealAnswer in triggerSurpriseQuestion).
    func recordSurpriseAnswer(_ q: Question, isCorrect: Bool) {
        batch {
            recordStat(course: q.c, cat: "surprise", sub: "Sürpriz Sual", isCorrect: isCorrect)
            recordReview(q, isCorrect: isCorrect)
            if isCorrect {
                saveCorrect(course: q.c, q)
            } else {
                saveWrong(course: q.c, q)
                incrementWrongCount(q.q)
            }
            updateDaily(increment: false)
            scheduleAchievementCheck()   // Nailiyyətlər
        }
    }

    // MARK: Daily goal (updateDaily)

    /// Today's answered count from the history (same sum as updateDaily / the home page).
    var todayAnsweredCount: Int {
        guard let day = data.history[Self.dayKey()] else { return 0 }
        return day.courses.values.reduce(0) { $0 + $1.correct + $1.wrong }
    }

    /// Current level for the sidebar box.
    var dailyLevel: DailyLevel { DailyLevel.forCount(todayAnsweredCount) }

    /// Port of updateDaily(inc): rewrites dailyGoal {d: toDateString, c: today's count}; with increment,
    /// a milestone count returns (and publishes in `celebration`) a Celebration.
    @discardableResult
    func updateDaily(increment: Bool) -> Celebration? {
        refreshDailyGoal(notify: true)
        let c = data.dailyGoal?.c ?? 0
        if increment && Celebration.milestones.contains(c) {
            let cel = Celebration.forMilestone(c)
            celebration = cel
            return cel
        }
        return nil
    }

    private func refreshDailyGoal(notify: Bool) {
        let todayStr = Self.jsDateString()
        var d = data.dailyGoal ?? DailyGoal()
        if d.d != todayStr { d = DailyGoal(d: todayStr, c: 0) }
        d.c = todayAnsweredCount
        guard d != data.dailyGoal else { return }
        data.dailyGoal = d
        if notify { markChanged(quick: true) }
    }

    // MARK: Settings

    /// qa_v32_conf.scale: 0.9 (Kiçik) / 1 (Orta) / 1.15 (Böyük).
    var fontScale: Double {
        get { data.settings?.scale ?? 1 }
        set {
            var s = data.settings ?? AppSettings()
            s.scale = newValue
            data.settings = s
            markChanged(quick: true)
        }
    }

    static let fontScales: [(label: String, value: Double)] = [("Kiçik", 0.9), ("Orta", 1), ("Böyük", 1.15)]

    // MARK: Reset

    /// resetStatistics: wipes every qa_v32_* value (theme and layout are kept). Fires onLocalChange(true);
    /// deleting the cloud copy is the sync layer's job.
    func resetAll() {
        stopQuizTimer()
        data = StudyData()
        ReviewStore.shared.clear()
        QuizProgressStore.shared.clear()
        celebration = nil
        refreshDailyGoal(notify: false)
        markChanged(quick: true)
        flush()
    }
}

/// Serialises writes of the data file; a write older than the last one written is dropped.
final class StudyFileWriter: Sendable {
    private let lastGeneration = OSAllocatedUnfairLock(initialState: Int64(0))

    func write(_ data: StudyData, to url: URL, generation: Int64) {
        lastGeneration.withLock { last in
            guard generation > last else { return }
            last = generation
            guard let raw = try? JSONEncoder().encode(data) else { return }
            try? raw.write(to: url, options: .atomic)
        }
    }
}
