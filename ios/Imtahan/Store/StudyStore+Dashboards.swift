import Foundation

// Read-only page models: home (start + renderHomeCharts), subject page (renderCoursePage), Mixed page
// (renderMixedPage), İmtahan pages (showPdfExamsDashboard / showPdfExamsList / buildPdfExamsHTML),
// Ümumi Toplam (showOverallDashboard), Statistika (showStats / showStatDetails / showStatDetailsModal),
// Səhvlərim (showWrong), the dynamics chart and the formatting helpers.
// Advice texts keep the web wording; <b>…</b> became **…** (render with AttributedString(markdown:)).

/// What tapping a row opens. The UI maps it to a QuizSession.Kind or a page.
enum RowTarget: Hashable, Sendable {
    case unit(course: String, index: Int)          // QuizApp.startUnit(c, idx) (Mixed parts too)
    case mixedSubject(String)                      // selectMixedSubSubject
    case course(String)                            // showCourseDashboard
    case pdfSubject(String)                        // showPdfExamsList
    case pdfExam(subject: String, index: Int)      // startPdfExam
    case pdfExamWrong(subject: String, index: Int) // startPdfExamWrQs (the red "Səhv" number)
    case pdfFrequent(String)                       // startPdfSubjectFrequentQs
    case mixedOnly(String)                         // startMixedOnlyQs
}

/// One card / table row of cpList.
struct StudyListRow: Hashable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let total: Int
    let ok: Int
    let bad: Int
    let done: Int
    let lastStr: String
    /// Small extra caption of the card ("3 hissə", "2 / 5 imtahan").
    var extra: String? = nil
    let target: RowTarget
    /// Set when the "Səhv" number itself is a link (pdf exams with wrong answers).
    var badTarget: RowTarget? = nil

    /// Card header: done/total in % (nil → "sual yoxdur").
    var progressPercent: Int? { total > 0 ? min(100, Int((Double(done) / Double(total) * 100).rounded())) : nil }
    /// Table "Faiz": ok/done in % (nil → "-").
    var accuracy: Int? { done > 0 ? Int((Double(ok) / Double(done) * 100).rounded()) : nil }
    /// Bar segment widths (0…1) of cpBar.
    var okShare: Double { StudyStore.share(ok, of: total) }
    var badShare: Double { StudyStore.share(bad, of: total) }
}

/// The "Multi (səhvlərin təkrarı)" lead row (cpMulti / the pdf variant).
struct MultiRow: Hashable, Sendable {
    let wrongCount: Int
    let hard: Int
    let veryHard: Int
    let lastStr: String
}

/// cpStrip: Cəmi sual / İşlənən / Düz / Səhv / Dəqiqlik / one extra cell.
struct StatStrip: Hashable, Sendable {
    let totalQ: Int
    let answered: Int
    let correct: Int
    let wrong: Int
    let extraLabel: String
    let extraValue: String
    var accuracy: Int { answered > 0 ? Int((Double(correct) / Double(answered) * 100).rounded()) : 0 }
    var okShare: Double { StudyStore.share(correct, of: totalQ) }
    var badShare: Double { StudyStore.share(wrong, of: totalQ) }
}

/// "Qarışıq sınaq" / "Böyük sınaq" tab numbers.
struct MixTabInfo: Hashable, Sendable {
    let questionCount: String   // "20" or "20 sual"
    let sources: String         // "5 bölmə" / "5 fənn"
    let notYetAnswered: Int
    /// "Son sınaq" line (when and how the last mixed exam went); nil before the first one.
    var last: String? = nil
}

struct HomeTotals: Hashable, Sendable {
    let subjectCount: Int
    let totalQuestions: Int
    let globalTime: Int
    let globalCorrect: Int
    let globalWrong: Int
    let globalAnswered: Int
    let accuracy: Int
    let unanswered: Int
    let todayQuestions: Int
    let todayCorrect: Int
    let todayWrong: Int
    let todayPlatformTime: Int
    let todayTestTime: Int
    let examTotal: Int
    let examRows: [ExamSubjectRow]

    var headline: String { "\(subjectCount) fənn · \(totalQuestions) sual · sərf edilən vaxt" }
    var todayPlatformTimeText: String { StudyStore.formatTodayTime(todayPlatformTime) }
    var todayTestTimeText: String { StudyStore.formatTodayTime(todayTestTime) }
    var globalTimeText: String { StudyStore.formatTime(globalTime) }
}

struct ExamSubjectRow: Hashable, Sendable, Identifiable {
    var id: String { subject }
    let subject: String
    let examCount: Int
    var pill: String { "\(examCount) sınaq imtahanı" }
}

/// One row of "Fənn üzrə irəliləyiş".
struct ProgressRow: Hashable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let correct: Int
    let wrong: Int
    let total: Int
    let isTotal: Bool
    var answered: Int { correct + wrong }
    var accuracy: Int { answered > 0 ? Int((Double(correct) / Double(answered) * 100).rounded()) : 0 }
    /// hx-acc class: "hi" ≥ 80, "lo" < 60, "" otherwise or when nothing answered.
    var tone: String { answered == 0 ? "" : (accuracy >= 80 ? "hi" : (accuracy < 60 ? "lo" : "")) }
    var okShare: Double { StudyStore.share(correct, of: total, clamp: false) }
    var badShare: Double { StudyStore.share(wrong, of: total, clamp: false) }
}

struct CoursePage: Hashable, Sendable {
    let course: String
    let subtitle: String            // "14 bölmə · 3 vize imtahanı"
    let strip: StatStrip
    let advice: String
    let wrongCount: Int             // "Səhvlərim N" button (disabled when 0)
    let multi: MultiRow
    let mixedOnlyCount: Int         // 0 → row hidden
    let mixedOnlyRow: StudyListRow?
    let units: [StudyListRow]
    let worstUnit: Int?
    let examCount: Int
    let mixTab: MixTabInfo
}

struct MixedPage: Hashable, Sendable {
    let subtitle: String            // "5 fənn · 40 hissə"
    let strip: StatStrip
    let advice: String
    let wrongCount: Int
    let multi: MultiRow
    let subjects: [StudyListRow]
    let worstSubject: Int?
    let mixTab: MixTabInfo
}

struct MixedSubjectPage: Hashable, Sendable {
    let subject: String
    let subtitle: String            // "Mixed · 8 hissə"
    let strip: StatStrip
    let parts: [StudyListRow]
    let worstPart: Int?
}

struct PdfDashboard: Hashable, Sendable {
    let subtitle: String            // "5 fənn · 15 vize imtahanı"
    let strip: StatStrip
    let advice: String
    let rows: [StudyListRow]
    let worstRow: Int?
}

struct PdfExamListPage: Hashable, Sendable {
    let subject: String
    let subtitle: String            // "3 vize imtahanı"
    let strip: StatStrip
    /// Multi lead row; nil when there are no pdf wrong answers.
    let leadWrongCount: Int?
    let rows: [StudyListRow]
    let worstRow: Int?
}

struct OverallPage: Hashable, Sendable {
    let strip: StatStrip
    let advice: String
    let wrongCount: Int
    let multi: MultiRow
    let rows: [StudyListRow]
    let worstRow: Int?
    let mixTab: MixTabInfo
}

struct StatsRow: Hashable, Sendable, Identifiable {
    var id: String { course }
    let course: String
    let t: Int
    let c: Int
    let w: Int
    let time: Int
    var accuracy: Int { t > 0 ? Int((Double(c) / Double(t) * 100).rounded()) : 0 }
    var timeText: String { StudyStore.formatTime(time) }
    var okShare: Double { StudyStore.share(c, of: t) }
    var badShare: Double { StudyStore.share(w, of: t) }
}

struct StatsPage: Hashable, Sendable {
    let answered: Int
    let correct: Int
    let wrong: Int
    let accuracyText: String        // "85%" or "-"
    let timeText: String            // "1h 5m / 3h 0m"
    let rows: [StatsRow]
}

enum StatDetailType: String, CaseIterable, Sendable {
    case total, correct, wrong, accuracy, time
    var title: String {
        switch self {
        case .total: return "Sual"
        case .time: return "Vaxt"
        case .correct: return "Doğru"
        case .wrong: return "Yanlış"
        case .accuracy: return "Dəqiqlik"
        }
    }
}

struct StatDetailRow: Hashable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let display: String
}

struct StatBreakdownSection: Hashable, Sendable, Identifiable {
    var id: String { category }
    let category: String
    let title: String               // "📘 Dərs", "🏛️ Keçmiş", "🔀 Qarışıq", "🎲 Sınaq"
    let rows: [StatDetailRow]       // name, "c D / w Y"
}

struct WrongSource: Hashable, Sendable, Identifiable {
    var id: String { key }
    let key: String
    let label: String               // "<subj> · İmtahan N" for pdf keys
    let count: Int
    let hard: Int
    let veryHard: Int
}

struct DynamicsPoint: Hashable, Sendable, Identifiable {
    var id: String { day }
    let day: String                 // "2026-11-03"
    let label: String               // "3 noy"
    let correct: Int
    let wrong: Int
    let minutes: Int
}

extension StudyStore {
    // MARK: Small helpers

    nonisolated static func share(_ n: Int, of total: Int, clamp: Bool = true) -> Double {
        guard total > 0 else { return 0 }
        let v = Double(n) / Double(total)
        return clamp ? min(1, v) : v
    }

    nonisolated static func pct(_ n: Int, _ d: Int) -> Int { d > 0 ? Int((Double(n) / Double(d) * 100).rounded()) : 0 }

    /// formatTime: "Xh Ym".
    nonisolated static func formatTime(_ s: Int) -> String { "\(s / 3600)h \((s % 3600) / 60)m" }

    /// formatTodayTime: "0s", "12s", "3m 4s", "1h 0m 5s".
    nonisolated static func formatTodayTime(_ s: Int) -> String {
        if s <= 0 { return "0s" }
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 || h > 0 { parts.append("\(m)m") }
        parts.append("\(sec)s")
        return parts.joined(separator: " ")
    }

    /// formatLastTested(ts ms, hasData).
    nonisolated static func formatLastTested(_ ts: Int64, hasData: Bool = false, now: Date = Date()) -> String {
        if ts == 0 { return hasData ? "Əvvəllər" : "Heç vaxt" }
        let d = Date(timeIntervalSince1970: Double(ts) / 1000)
        let diffMs = now.timeIntervalSince1970 * 1000 - Double(ts)
        let mins = Int(floor(diffMs / 60000)), hours = Int(floor(diffMs / 3_600_000)), days = Int(floor(diffMs / 86_400_000))
        if mins < 1 { return "İndi" }
        if mins < 60 { return "\(mins) dəq əvvəl" }
        if hours < 24 { return "\(hours) saat əvvəl" }
        if days == 1 { return "Dünən" }
        if days < 7 { return "\(days) gün əvvəl" }
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: d)
        return String(format: "%02d.%02d.%04d %02d:%02d", c.day ?? 0, c.month ?? 0, c.year ?? 0, c.hour ?? 0, c.minute ?? 0)
    }

    var platformTime: Int { data.stats[Catalog.platformKey]?.time ?? 0 }

    private func timePair(_ t: Int) -> String { "\(Self.formatTime(t)) / \(Self.formatTime(platformTime))" }

    private func lastStr(_ last: Int64, done: Int, course: String) -> String {
        Self.formatLastTested(last == 0 && done > 0 ? getCourseLastActiveDateFromHistory(course) : last, hasData: done > 0)
    }

    /// Index of the row with the most wrong answers (first one wins ties); nil if none.
    nonisolated static func worstIndex(_ rows: [StudyListRow]) -> Int? {
        var worst: Int?
        for (i, r) in rows.enumerated() where r.bad > 0 {
            if worst == nil || r.bad > rows[worst!].bad { worst = i }
        }
        return worst
    }

    func hardCounts(_ qs: [Question]) -> (hard: Int, veryHard: Int) {
        let wc = data.wrongCounts
        return (qs.filter { (wc[$0.q] ?? 0) >= 2 }.count, qs.filter { (wc[$0.q] ?? 0) >= 3 }.count)
    }

    /// getCourseLastTested: newest bd[*][*].last, else the last history day.
    func getCourseLastTested(_ c: String) -> Int64 {
        var maxTs: Int64 = 0
        if let cs = data.stats[c] {
            for (_, subs) in cs.bd { for (_, it) in subs where it.last > maxTs { maxTs = it.last } }
        }
        if maxTs == 0 { maxTs = getCourseLastActiveDateFromHistory(c) }
        return maxTs
    }

    /// Newest history day that has an entry for c, at 12:00 local time (ms); 0 if none.
    func getCourseLastActiveDateFromHistory(_ c: String) -> Int64 {
        var best: String?
        for (day, rec) in data.history where rec.courses[c] != nil || rec.extra[c] != nil {
            if best == nil || day > best! { best = day }
        }
        guard let best else { return 0 }
        let parts = best.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return 0 }
        var dc = DateComponents(); dc.year = parts[0]; dc.month = parts[1]; dc.day = parts[2]; dc.hour = 12
        guard let date = Calendar(identifier: .gregorian).date(from: dc) else { return 0 }
        return Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    /// getCourseAdvice(s, totalQ).
    nonisolated static func courseAdvice(_ s: CourseStat, totalQ: Int) -> String {
        let answered = s.t
        if answered == 0 {
            return "Bu fənn üzrə hələ heç bir sual cavablandırmamısınız. Öyrənməyə və özünüzü sınamağa başlamaq üçün aşağıdakı bölmələrdən birini seçib 'Başla' düyməsinə klikləyin!"
        }
        let percent = pct(s.c, s.t)
        if answered < 15 {
            let progress = totalQ > 0 ? pct(answered, totalQ) : 0
            return "Siz hələ ki bu fənn üzrə cəmi **\(answered) sual** cavablandırmısınız (doğru cavab nisbəti: \(percent)%, fənn üzrə irəliləyiş: \(progress)%). AI-in daha dolğun analiz və tövsiyələr verə bilməsi üçün bölmələri işləməyə davam edin!"
        }
        if percent >= 80 {
            return "Mükəmməl göstərici! Bu fənn üzrə cavablarınızın \(percent)%-i doğrudur. Biliklərinizi daha da möhkəmləndirmək üçün sol menyudakı **Böyük Sınaq** rejimi ilə özünüzü sınaqdan keçirə bilərsiniz."
        }
        if percent >= 50 {
            return "Göstəriciniz yaxşıdır (\(percent)% doğru). Səhv etdiyiniz sualları yenidən nəzərdən keçirmək üçün sol menyudan **Səhvlərim** bölməsinə daxil olmanızı və zəif olduğunuz bölmələri yenidən təkrarlamanızı tövsiyə edirik."
        }
        return "Bu fənn üzrə çətinlik çəkdiyiniz görünür (doğru cavab: \(percent)%). Sualları daha diqqətlə oxumağı, hər bir bölməni (Unit) ayrıca olaraq təkrar-təkrar işləməyi və çətin sualları **Seçilmişlər** (Bookmark) siyahısına əlavə edərək təkrar etməyi tövsiyə edirik."
    }

    func getCourseAdvice(_ course: String, totalQ: Int) -> String {
        Self.courseAdvice(data.stats[course] ?? CourseStat(), totalQ: totalQ)
    }

    /// Renders a **bold** advice string.
    nonisolated static func attributed(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(markdown)
    }

    // MARK: Totals per subject (subject + its "_pdf_" keys)

    /// Question count of a CONFIG course plus its pdf exams (renderHomeCharts / renderCoursePage / nav ring).
    /// In-scope questions only (pdf exams are vize papers and always count; final booklets in Final mode).
    func courseTotalQuestions(_ c: String) -> Int {
        scopedQuestions(course: c).count + (bank.pdfExams[c] ?? []).reduce(0) { $0 + $1.count }
            + (examMode == .final ? bank.finalQuestionCount(subject: c) : 0)
    }

    /// Sum of stats[c], stats["c_pdf_*"] and stats["c_final_*"]: (t, c, w, time), without out-of-scope
    /// unit buckets (final booklet keys count in Final mode only, see scopedStat).
    func courseAggregate(_ c: String) -> (t: Int, c: Int, w: Int, time: Int) {
        var r = (t: 0, c: 0, w: 0, time: 0)
        for key in data.stats.keys where key == c || key.hasPrefix(c + "_pdf_") || key.hasPrefix(c + "_final_") {
            guard let st = scopedStat(key) else { continue }
            r.t += st.t; r.c += st.c; r.w += st.w; r.time += st.time
        }
        return r
    }

    /// LifeOS.updateNavProgress: % of a subject's questions answered (sidebar ring).
    func navProgress(_ subject: String) -> Int {
        let total = courseTotalQuestions(subject)
        guard total > 0 else { return 0 }
        return min(100, Self.pct(courseAggregate(subject).t, total))
    }

    // MARK: Home (QuizApp.start + renderHomeCharts)

    func homeTotals() -> HomeTotals {
        var time = 0, correct = 0, wrong = 0, answered = 0
        for k in data.stats.keys where k != Catalog.platformKey {
            guard let s = scopedStat(k) else { continue }
            time += s.time; correct += s.c; wrong += s.w; answered += s.t
        }
        let totalQ = bank.grandTotal(mode: examMode)
        let today = data.history[Self.dayKey()]
        var tq = 0, tc = 0, tw = 0, tt = 0
        for (k, c) in today?.courses ?? [:] where historyKeyInScope(k) { tq += c.correct + c.wrong; tc += c.correct; tw += c.wrong; tt += c.time }
        let examRows = pdfSubjectsOrdered.map { ExamSubjectRow(subject: $0, examCount: bank.pdfExams[$0]?.count ?? 0) }
        return HomeTotals(subjectCount: Catalog.subjects.count, totalQuestions: totalQ, globalTime: time,
                          globalCorrect: correct, globalWrong: wrong, globalAnswered: answered,
                          accuracy: Self.pct(correct, answered), unanswered: max(0, totalQ - answered),
                          todayQuestions: tq, todayCorrect: tc, todayWrong: tw,
                          todayPlatformTime: today?.platformTime ?? 0, todayTestTime: tt,
                          examTotal: examRows.reduce(0) { $0 + $1.examCount }, examRows: examRows)
    }

    var pdfSubjectsOrdered: [String] {
        bank.pdfSubjects.isEmpty ? bank.pdfExams.keys.sorted() : bank.pdfSubjects
    }

    /// "Fənn üzrə irəliləyiş": Ümumi Toplam first, then every CONFIG course (Mixed included).
    func homeProgressRows() -> [ProgressRow] {
        let h = homeTotals()
        var rows = [ProgressRow(name: Catalog.overallKey, icon: "📊", correct: h.globalCorrect, wrong: h.globalWrong,
                                total: h.globalCorrect + h.globalWrong + h.unanswered, isTotal: true)]
        for c in Catalog.configKeys {
            let a = courseAggregate(c)
            rows.append(ProgressRow(name: c, icon: Catalog.styles[c]?.icon ?? "📘", correct: a.c, wrong: a.w,
                                    total: courseTotalQuestions(c), isTotal: false))
        }
        return rows
    }

    // MARK: Subject page (renderCoursePage)

    /// Unit / Mixed part names of a course in the current mode (Vize: units 1–7, Vize Mixed parts).
    func unitTitles(_ c: String) -> [String] { unitTitles(c, mode: examMode) }

    func unitTitles(_ c: String, mode: ExamMode) -> [String] {
        if c == Catalog.mixedKey { return bank.mixedParts(for: mode).map(\.name) }
        return (0..<bank.unitCount(course: c, mode: mode)).map { "Unit \($0 + 1)" }
    }

    /// Question count of unit/part `index` (0-based) of a course in the current mode.
    func unitQuestionCount(_ c: String, index: Int) -> Int {
        if c == Catalog.mixedKey { return scopedMixedParts[studySafe: index]?.questions.count ?? 0 }
        return inScope(unit: index + 1) ? bank.unitQuestions(course: c, unit: index + 1).count : 0
    }

    func coursePage(_ c: String) -> CoursePage {
        let s = scopedStat(c) ?? CourseStat()
        let totalQ = courseTotalQuestions(c)
        let exams = bank.pdfExams[c] ?? []
        let a = courseAggregate(c)
        let unitStats = s.bd["units"] ?? [:]
        let courseQs = bank.questions(course: c)
        let units: [StudyListRow] = unitTitles(c).enumerated().map { i, name in
            let us = unitStats["Unit \(i + 1)"] ?? SubStat()
            let total = courseQs.filter { $0.u == i + 1 }.count
            return StudyListRow(name: name, total: total, ok: us.c, bad: us.w, done: us.c + us.w,
                           lastStr: lastStr(us.last, done: us.c + us.w, course: c), target: .unit(course: c, index: i))
        }
        let wr = scopedWrong(c)
        let hc = hardCounts(wr)
        let m = unitStats["Multi"] ?? SubStat()
        let multi = MultiRow(wrongCount: wr.count, hard: hc.hard, veryHard: hc.veryHard, lastStr: lastStr(m.last, done: m.t, course: c))
        let mixedOnly = getMixedOnlyQuestions(c)
        let mo = s.bd["mixed-only"]?["Yalnız Mixed-də olan suallar"] ?? SubStat()
        let moRow: StudyListRow? = mixedOnly.isEmpty ? nil : StudyListRow(
            name: "Yalnız Mixed-də olan suallar", total: mixedOnly.count, ok: mo.c, bad: mo.w, done: mo.t,
            lastStr: Self.formatLastTested(mo.last, hasData: mo.t > 0), target: .mixedOnly(c))
        return CoursePage(
            course: c, subtitle: "\(examMode.title) · \(units.count) bölmə · \(exams.count) vize imtahanı",
            strip: StatStrip(totalQ: totalQ, answered: a.t, correct: a.c, wrong: a.w, extraLabel: "Vaxt", extraValue: timePair(a.time)),
            advice: Self.courseAdvice(s, totalQ: totalQ), wrongCount: wr.count, multi: multi,
            mixedOnlyCount: mixedOnly.count, mixedOnlyRow: moRow, units: units, worstUnit: Self.worstIndex(units),
            examCount: exams.count,
            mixTab: MixTabInfo(questionCount: "20", sources: "\(units.filter { $0.total > 0 }.count) bölmə",
                               notYetAnswered: unansweredQuestions(c).count, last: mixedLast(s)))
    }

    // MARK: Mixed page (renderMixedPage)

    private func mixedPartRows() -> [(subject: String, row: StudyListRow, last: Int64)] {
        let unitStats = data.stats[Catalog.mixedKey]?.bd["units"] ?? [:]
        return scopedMixedParts.enumerated().map { idx, chunk in
            let us = unitStats[chunk.statKey] ?? SubStat()
            let done = us.c + us.w
            let row = StudyListRow(name: "Hissə \(chunk.part) (\(chunk.startIdx + 1)-\(chunk.endIdx))", total: chunk.endIdx - chunk.startIdx,
                              ok: us.c, bad: us.w, done: done, lastStr: lastStr(us.last, done: done, course: Catalog.mixedKey),
                              target: .unit(course: Catalog.mixedKey, index: idx))
            return (chunk.subject, row, us.last)
        }
    }

    /// Level 1: the subjects.
    func mixedPage() -> MixedPage {
        let c = Catalog.mixedKey
        let s = data.stats[c] ?? CourseStat()
        let parts = mixedPartRows()
        let totalQ = scopedQuestions(course: c).count
        let wr = scopedWrong(c)
        let hc = hardCounts(wr)
        let m = s.bd["units"]?["Multi"] ?? SubStat()
        let subs: [StudyListRow] = Catalog.subjects.map { name in
            let ps = parts.filter { $0.subject == name }
            let total = ps.reduce(0) { $0 + $1.row.total }, ok = ps.reduce(0) { $0 + $1.row.ok }
            let bad = ps.reduce(0) { $0 + $1.row.bad }, done = ps.reduce(0) { $0 + $1.row.done }
            let last = ps.reduce(Int64(0)) { max($0, $1.last) }
            return StudyListRow(name: name, total: total, ok: ok, bad: bad, done: done, lastStr: lastStr(last, done: done, course: c),
                           extra: "\(ps.count) hissə", target: .mixedSubject(name))
        }
        return MixedPage(
            subtitle: "\(examMode.title) · \(subs.count) fənn · \(parts.count) hissə",
            strip: StatStrip(totalQ: totalQ, answered: s.t, correct: s.c, wrong: s.w, extraLabel: "Vaxt", extraValue: timePair(s.time)),
            advice: Self.courseAdvice(s, totalQ: totalQ), wrongCount: wr.count,
            multi: MultiRow(wrongCount: wr.count, hard: hc.hard, veryHard: hc.veryHard, lastStr: lastStr(m.last, done: m.t, course: c)),
            subjects: subs, worstSubject: Self.worstIndex(subs),
            mixTab: MixTabInfo(questionCount: "20", sources: "\(subs.filter { $0.total > 0 }.count) fənn", notYetAnswered: max(0, totalQ - s.t)))
    }

    /// Level 2: the 20-question parts of one subject.
    func mixedSubjectPage(_ subject: String) -> MixedSubjectPage {
        let rows = mixedPartRows().filter { $0.subject == subject }.map(\.row)
        let sum: (KeyPath<StudyListRow, Int>) -> Int = { kp in rows.reduce(0) { $0 + $1[keyPath: kp] } }
        return MixedSubjectPage(
            subject: subject, subtitle: "Mixed · \(rows.count) hissə",
            strip: StatStrip(totalQ: sum(\.total), answered: sum(\.done), correct: sum(\.ok), wrong: sum(\.bad), extraLabel: "Hissə", extraValue: "\(rows.count)"),
            parts: rows, worstPart: Self.worstIndex(rows))
    }

    // MARK: İmtahan (pdf exams)

    nonisolated static func pdfKey(_ subject: String, _ idx: Int) -> String { "\(subject)_pdf_\(idx)" }

    func pdfDashboard() -> PdfDashboard {
        var totalQ = 0, answered = 0, correct = 0, wrong = 0, time = 0, examCount = 0
        let subjects = pdfSubjectsOrdered
        let rows: [StudyListRow] = subjects.map { subject in
            let exams = bank.pdfExams[subject] ?? []
            var done = 0, total = 0, t = 0, ok = 0, bad = 0
            var last: Int64 = 0
            for (idx, qs) in exams.enumerated() {
                let st = data.stats[Self.pdfKey(subject, idx)] ?? CourseStat()
                total += qs.count
                if st.t > 0 { done += 1 }
                t += st.t; ok += st.c; bad += st.w
                last = max(last, st.bd["pdf-exam"]?["İmtahan \(idx + 1)"]?.last ?? 0)
                time += st.time
            }
            totalQ += total; answered += t; correct += ok; wrong += bad; examCount += exams.count
            return StudyListRow(name: subject, total: total, ok: ok, bad: bad, done: t, lastStr: Self.formatLastTested(last, hasData: t > 0),
                           extra: "\(done) / \(exams.count) imtahan", target: .pdfSubject(subject))
        }
        let acc = Self.pct(correct, answered)
        let rec: String
        if answered == 0 { rec = "Siz hələ heç bir vize imtahanı işləməmisiniz. Biliklərinizi yoxlamaq üçün aşağıdakı fənlərdən birini seçib ilk imtahana başlayın!" }
        else if acc >= 80 { rec = "Əla göstərici! Vize imtahanlarında ümumi dəqiqliyiniz **\(acc)%** təşkil edir. Hələ işləmədiyiniz digər imtahanları tamamlayaraq hazırlığınızı mükəmməlləşdirə bilərsiniz." }
        else if acc >= 50 { rec = "İrəliləyişiniz yaxşıdır (ümumi dəqiqlik: **\(acc)%**). Daha yüksək nəticə üçün səhv cavablandırdığınız sualları yenidən işləməyi tövsiyə edirik." }
        else { rec = "Vize imtahanlarında dəqiqliyiniz **\(acc)%** səviyyəsindədir. Sualları tələsmədən oxumağı və zəif nəticə göstərdiyiniz imtahanları təkrar işləməyi tövsiyə edirik." }
        return PdfDashboard(
            subtitle: "\(rows.count) fənn · \(examCount) vize imtahanı",
            strip: StatStrip(totalQ: totalQ, answered: answered, correct: correct, wrong: wrong, extraLabel: "Vaxt", extraValue: timePair(time)),
            advice: rec, rows: rows, worstRow: Self.worstIndex(rows))
    }

    /// Total wrong answers across a subject's pdf exams (the Multi lead row).
    func pdfWrongCount(_ subject: String) -> Int {
        (bank.pdfExams[subject] ?? []).indices.reduce(0) { $0 + (data.wrong[Self.pdfKey(subject, $1)]?.count ?? 0) }
    }

    /// buildPdfExamsHTML rows: "Ən çox düşən suallar" (if any), then each exam.
    func pdfExamRows(_ subject: String) -> [StudyListRow] {
        let exams = bank.pdfExams[subject] ?? []
        var rows: [StudyListRow] = []
        let freq = getMostFrequentQuestions(subject)
        if !freq.isEmpty {
            let f = data.stats[subject]?.bd["pdf-exam"]?["Ən çox düşən suallar"] ?? SubStat()
            rows.append(StudyListRow(name: "Ən çox düşən suallar", total: freq.count, ok: f.c, bad: f.w, done: f.c + f.w,
                                lastStr: Self.formatLastTested(f.last, hasData: f.c + f.w > 0), target: .pdfFrequent(subject)))
        }
        for (idx, qs) in exams.enumerated() {
            let title = "İmtahan \(idx + 1)"
            let st = data.stats[Self.pdfKey(subject, idx)] ?? CourseStat()
            let last = st.bd["pdf-exam"]?[title]?.last ?? 0
            rows.append(StudyListRow(name: title, total: qs.count, ok: st.c, bad: st.w, done: st.c + st.w,
                                lastStr: Self.formatLastTested(last, hasData: st.c + st.w > 0),
                                target: .pdfExam(subject: subject, index: idx), badTarget: .pdfExamWrong(subject: subject, index: idx)))
        }
        return rows
    }

    func pdfExamListPage(_ subject: String) -> PdfExamListPage {
        let exams = bank.pdfExams[subject] ?? []
        var totalQ = 0, answered = 0, correct = 0, wrong = 0, time = 0
        for (idx, qs) in exams.enumerated() {
            let st = data.stats[Self.pdfKey(subject, idx)] ?? CourseStat()
            totalQ += qs.count; answered += st.t; correct += st.c; wrong += st.w; time += st.time
        }
        let rows = pdfExamRows(subject)
        let wc = pdfWrongCount(subject)
        return PdfExamListPage(
            subject: subject, subtitle: "\(exams.count) vize imtahanı",
            strip: StatStrip(totalQ: totalQ, answered: answered, correct: correct, wrong: wrong, extraLabel: "Vaxt", extraValue: timePair(time)),
            leadWrongCount: wc > 0 ? wc : nil, rows: rows, worstRow: Self.worstIndex(rows))
    }

    // MARK: Ümumi Toplam (showOverallDashboard)

    func overallPage() -> OverallPage {
        var time = 0, correct = 0, wrong = 0, answered = 0
        for k in data.stats.keys where k != Catalog.platformKey {
            guard let st = scopedStat(k) else { continue }
            time += st.time; correct += st.c; wrong += st.w; answered += st.t
        }
        let acc = Self.pct(correct, answered)
        let totalQ = scopedQuestionsTotal
        let wr = allWrongQuestions()
        var multiLast: Int64 = 0, multiDone = false
        for (_, st) in data.stats {
            guard let m = st.bd["units"]?["Multi"] else { continue }
            multiLast = max(multiLast, m.last)
            if m.t > 0 { multiDone = true }
        }
        if multiLast == 0 && multiDone {
            for k in data.stats.keys { multiLast = max(multiLast, getCourseLastActiveDateFromHistory(k)) }
        }
        let rows: [StudyListRow] = Catalog.configKeys.map { name in
            let cs = scopedStat(name) ?? CourseStat()
            return StudyListRow(name: name, total: scopedQuestions(course: name).count, ok: cs.c, bad: cs.w, done: cs.t,
                           lastStr: Self.formatLastTested(getCourseLastTested(name), hasData: cs.t > 0), target: .course(name))
        }
        let rec: String
        if answered == 0 { rec = "Hələ ki heç bir sual cavablandırmamısınız. İmtahana hazırlaşmaq üçün hər hansı bir fənni seçib sualları işləməyə başlayın!" }
        else if acc >= 80 { rec = "Mükəmməl ümumi nəticə! Dəqiqliyiniz \(acc)%-dir. Bu tempi qoruyub saxlamaq üçün mütəmadi olaraq **Böyük sınaq** işləyin." }
        else if acc >= 50 { rec = "Ümumi hazırlıq səviyyəniz yaxşıdır (\(acc)% doğru). Göstəricinizi daha da yaxşılaşdırmaq üçün zəif olduğunuz fənlərə diqqət yetirin, səhv etdiyiniz sualları **Səhvlərim** ilə yenidən işləyin." }
        else { rec = "Ümumi nəticəniz zəifdir (\(acc)% doğru). Hər bir fənni ayrı-ayrılıqda daha diqqətlə öyrənməyinizi və çətinlik çəkdiyiniz mövzuları təkrarlamağı tövsiyə edirik." }
        let hc = hardCounts(wr)
        return OverallPage(
            strip: StatStrip(totalQ: totalQ, answered: answered, correct: correct, wrong: wrong, extraLabel: "Vaxt", extraValue: timePair(time)),
            advice: rec, wrongCount: wr.count,
            multi: MultiRow(wrongCount: wr.count, hard: hc.hard, veryHard: hc.veryHard, lastStr: Self.formatLastTested(multiLast, hasData: multiDone)),
            rows: rows, worstRow: Self.worstIndex(rows),
            mixTab: MixTabInfo(questionCount: "20 sual", sources: "\(rows.filter { $0.total > 0 }.count) fənn", notYetAnswered: max(0, totalQ - answered)))
    }

    // MARK: Statistika (showStats / showStatDetails / showStatDetailsModal)

    func statsPage() -> StatsPage {
        var gt = 0, gc = 0, gw = 0, tm = 0
        var rows: [StatsRow] = []
        for c in Catalog.configKeys + [Catalog.mockKey] {
            guard let s = scopedStat(c), s.t > 0 else { continue }
            gt += s.t; gc += s.c; gw += s.w; tm += s.time
            rows.append(StatsRow(course: c, t: s.t, c: s.c, w: s.w, time: s.time))
        }
        return StatsPage(answered: gt, correct: gc, wrong: gw, accuracyText: gt > 0 ? "\(Self.pct(gc, gt))%" : "-",
                         timeText: timePair(tm), rows: rows)
    }

    /// Every stats key with t > 0, sorted by the value descending.
    func statDetails(_ type: StatDetailType) -> [StatDetailRow] {
        var items: [(n: String, v: Double, d: String)] = []
        for c in data.stats.keys {
            guard let s = scopedStat(c), s.t > 0 else { continue }
            switch type {
            case .time: items.append((c, Double(s.time), Self.formatTime(s.time)))
            case .accuracy:
                let v = Double(s.c) / Double(s.t)
                items.append((c, v, "\(Int((v * 100).rounded()))%"))
            case .total: items.append((c, Double(s.t), "\(s.t)"))
            case .correct: items.append((c, Double(s.c), "\(s.c)"))
            case .wrong: items.append((c, Double(s.w), "\(s.w)"))
            }
        }
        items.sort { $0.v != $1.v ? $0.v > $1.v : Self.jsLess($0.n, $1.n) }
        return items.map { StatDetailRow(name: $0.n, display: $0.d) }
    }

    /// Breakdown modal for one course. nil = "Bu fənn üzrə hələ heç bir sual cavablandırılmayıb." (no bd at all).
    func statBreakdown(_ c: String) -> [StatBreakdownSection]? {
        guard let s = scopedStat(c), !s.bd.isEmpty else { return nil }
        let cats: [(String, String)] = [("units", "📘 Dərs"), ("exams", "🏛️ Keçmiş"), ("mixed", "🔀 Qarışıq"), ("mock", "🎲 Sınaq")]
        return cats.compactMap { key, title in
            guard let subs = s.bd[key] else { return nil }
            let rows = subs.keys.sorted(by: Self.jsLess).map { k in
                let d = subs[k]!
                return StatDetailRow(name: k, display: "\(d.c) D / \(d.w) Y")
            }
            return StatBreakdownSection(category: key, title: title, rows: rows)
        }
    }

    /// JS default sort order (UTF-16 code units).
    nonisolated static func jsLess(_ a: String, _ b: String) -> Bool { a.utf16.lexicographicallyPrecedes(b.utf16) }

    // MARK: Səhvlərim (showWrong)

    /// Display label of a wrong-list key: "<subj> · İmtahan N" for pdf keys.
    nonisolated static func wrongKeyLabel(_ k: String) -> String {
        if let r = k.range(of: "_pdf_", options: .backwards), let n = Int(k[r.upperBound...]) {
            return "\(k[..<r.lowerBound]) · İmtahan \(n + 1)"
        }
        if let f = QuestionBank.parseFinalKey(k) {
            let name = QuestionBank.shared.finalExam(subject: f.subject, id: f.id).map { finalExamShortName($0.name) } ?? "Final \(f.id)"
            return "\(f.subject) · \(name)"
        }
        return k
    }

    /// Sort order for wrong/correct keys (the web uses insertion order, which a dictionary cannot keep):
    /// Catalog order, each subject followed by its pdf exams, then anything else alphabetically.
    nonisolated static func keyOrder(_ a: String, _ b: String) -> Bool {
        func rank(_ k: String) -> (Int, Int, String) {
            let base = foldPdfKeyStatic(k)
            // pdf exams 1…99 after the subject, final booklets after them (newest = highest sinavId first)
            let pdf = k.range(of: "_pdf_").flatMap { Int(k[$0.upperBound...]) }.map { $0 + 1 }
                ?? QuestionBank.parseFinalKey(k).map { 100_000 - $0.id } ?? 0
            let i = Catalog.configKeys.firstIndex(of: base) ?? Catalog.configKeys.count
            return (i, pdf, k)
        }
        let ra = rank(a), rb = rank(b)
        if ra.0 != rb.0 { return ra.0 < rb.0 }
        if ra.1 != rb.1 { return ra.1 < rb.1 }
        return jsLess(ra.2, rb.2)
    }

    nonisolated static func foldPdfKeyStatic(_ course: String) -> String { QuestionBank.baseCourse(course) }

    func wrongSources() -> [WrongSource] {
        data.wrong.keys.filter { !scopedWrong($0).isEmpty }.sorted(by: Self.keyOrder).map { k in
            let arr = scopedWrong(k)
            let hc = hardCounts(arr)
            return WrongSource(key: k, label: Self.wrongKeyLabel(k), count: arr.count, hard: hc.hard, veryHard: hc.veryHard)
        }
    }

    /// "<total> səhv sual · <n> mənbə"
    var wrongTotal: Int { data.wrong.keys.reduce(0) { $0 + scopedWrong($1).count } }

    /// Non-Mixed in-scope questions of quizData (Ümumi Toplam "Cəmi sual").
    var scopedQuestionsTotal: Int { bank.all.lazy.filter { $0.c != Catalog.mixedKey && self.inScope($0) }.count }

    /// Questions answered wrong ≥ 2 times / ≥ 3 times, over every wrong list.
    var hardCount: Int { hardCounts(allWrongQuestions()).hard }
    var veryHardCount: Int { hardCounts(allWrongQuestions()).veryHard }

    // MARK: Dynamics chart (drawDynamicsChart)

    /// Days of Catalog.studyPeriod with correct/wrong counts and minutes; course "all" or a CONFIG key.
    func dynamicsSeries(course sel: String = "all") -> [DynamicsPoint] {
        let months = ["yan", "fev", "mar", "apr", "may", "iyn", "iyl", "avq", "sen", "okt", "noy", "dek"]
        let cal = Calendar(identifier: .gregorian)
        func parse(_ s: String) -> Date? {
            let p = s.split(separator: "-").compactMap { Int($0) }
            guard p.count == 3 else { return nil }
            var dc = DateComponents(); dc.year = p[0]; dc.month = p[1]; dc.day = p[2]; dc.hour = 12
            return cal.date(from: dc)
        }
        guard var d = parse(Catalog.studyPeriod.start), let end = parse(Catalog.studyPeriod.end) else { return [] }
        var out: [DynamicsPoint] = []
        while d <= end {
            let key = Self.dayKey(d)
            var c = 0, w = 0, t = 0
            for (k, v) in data.history[key]?.courses ?? [:] {
                if !historyKeyInScope(k) || (sel != "all" && QuestionBank.baseCourse(k) != sel) { continue }
                c += v.correct; w += v.wrong; t += v.time
            }
            let comps = cal.dateComponents([.day, .month], from: d)
            out.append(DynamicsPoint(day: key, label: "\(comps.day ?? 0) \(months[(comps.month ?? 1) - 1])", correct: c, wrong: w,
                                     minutes: Int((Double(t) / 60).rounded())))
            d = cal.date(byAdding: .day, value: 1, to: d) ?? end.addingTimeInterval(86400)
        }
        return out
    }

    /// Y axis of the chart: (max, step), exactly like drawDynamicsChart.
    nonisolated static func dynamicsScale(_ points: [DynamicsPoint], timeMode: Bool) -> (max: Int, step: Int) {
        let top = max(4, points.map { timeMode ? $0.minutes : $0.correct + $0.wrong }.max() ?? 0)
        let step = top > 200 ? 50 : top > 80 ? 20 : top > 30 ? 10 : top > 12 ? 5 : top > 6 ? 2 : 1
        return (Int((Double(top) / Double(step)).rounded(.up)) * step, step)
    }

    /// Chart filter options: ("all", "Hamısı") + every CONFIG key.
    nonisolated static var dynamicsFilters: [(value: String, label: String)] {
        [("all", "Hamısı")] + Catalog.configKeys.map { ($0, $0) }
    }

    /// In-scope questions of a subject never answered (neither in the correct nor the wrong list).
    func unansweredQuestions(_ c: String) -> [Question] {
        let seen = Set((data.correct[c] ?? []).map(\.q)).union((data.wrong[c] ?? []).map(\.q))
        return scopedQuestions(course: c).filter { !seen.contains($0.q) }
    }

    /// "14 noy · 52 düz, 8 səhv" for the subject's "Qarışıq Sınaq" stat.
    func mixedLast(_ s: CourseStat) -> String? {
        guard let m = s.bd["mixed"]?["Qarışıq Sınaq"], m.t > 0 else { return nil }
        return "\(Self.formatLastTested(m.last, hasData: true)) · cəmi \(m.c) düz, \(m.w) səhv"
    }
}
