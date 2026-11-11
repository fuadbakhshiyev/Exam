import Foundation

// Read-only models for the "Statistika" tab. Everything goes through the scoped helpers
// (scopedStat / courseAggregate / courseTotalQuestions / scopedMixedParts), so it follows `examMode`.

/// One row of "Fənlər üzrə": a subject (with its pdf exams), Mixed or the mock exam.
struct SubjectStatsRow: Hashable, Sendable, Identifiable {
    var id: String { key }
    let key: String
    /// In-scope question count; 0 when it has no fixed size (mock).
    let total: Int
    let answered: Int
    let correct: Int
    let wrong: Int
    let time: Int
    let lastTested: Int64

    var accuracy: Int? { answered > 0 ? StudyStore.pct(correct, answered) : nil }
}

/// One line of a breakdown section (a unit, a Mixed part, a mock subject…).
struct StatsLine: Hashable, Sendable, Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let correct: Int
    let wrong: Int
    let last: Int64
    var answered: Int { correct + wrong }
    var accuracy: Int? { answered > 0 ? StudyStore.pct(correct, answered) : nil }
}

struct StatsLineSection: Hashable, Sendable, Identifiable {
    var id: String { category }
    let category: String
    let title: String
    let lines: [StatsLine]
}

extension StudyStore {
    /// Subjects (pdf exams included), then Mixed, then the mock exam when it has answers.
    func subjectStatsRows() -> [SubjectStatsRow] {
        var rows = (Catalog.subjects + [Catalog.mixedKey]).map(subjectStatsRow)
        if let m = scopedStat(Catalog.mockKey), m.t > 0 { rows.append(subjectStatsRow(Catalog.mockKey)) }
        return rows
    }

    func subjectStatsRow(_ key: String) -> SubjectStatsRow {
        if key == Catalog.mockKey {
            let s = scopedStat(key) ?? CourseStat()
            return SubjectStatsRow(key: key, total: 0, answered: s.t, correct: s.c, wrong: s.w, time: s.time,
                                   lastTested: getCourseLastTested(key))
        }
        let a = courseAggregate(key)
        return SubjectStatsRow(key: key, total: courseTotalQuestions(key), answered: a.t, correct: a.c, wrong: a.w,
                               time: a.time, lastTested: getCourseLastTested(key))
    }

    /// Per-category breakdown of one stats key (pdf exam rows excluded — they have their own section).
    /// Mixed parts outside the current mode are left out; units are listed in numeric order.
    func statsLineSections(_ key: String) -> [StatsLineSection] {
        guard let s = scopedStat(key) else { return [] }
        let order = ["units", "mixed", "mixed-only", "exams", "mock", "review"]
        let titles = ["units": "Bölmələr", "mixed": "Qarışıq sınaq", "mixed-only": "Yalnız Mixed",
                      "exams": "Keçmiş imtahanlar", "mock": "Böyük sınaq", "review": "Təkrarlar"]
        let mixedNames = key == Catalog.mixedKey
            ? Dictionary(scopedMixedParts.map { ($0.statKey, $0.name) }, uniquingKeysWith: { a, _ in a }) : [:]
        let cats = s.bd.keys.filter { $0 != "pdf-exam" }.sorted {
            (order.firstIndex(of: $0) ?? order.count, $0) < (order.firstIndex(of: $1) ?? order.count, $1)
        }
        return cats.compactMap { cat in
            let lines: [StatsLine] = (s.bd[cat] ?? [:]).compactMap { name, st in
                guard st.c + st.w > 0 else { return nil }
                var title = name == "Multi" ? "Səhvlərin təkrarı" : name
                if key == Catalog.mixedKey && cat == "units" && name != "Multi" {
                    guard let n = mixedNames[name] else { return nil }
                    title = n
                }
                return StatsLine(key: name, title: title, correct: st.c, wrong: st.w, last: st.last)
            }
            .sorted { a, b in
                if (a.key == "Multi") != (b.key == "Multi") { return b.key == "Multi" }
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            guard !lines.isEmpty else { return nil }
            return StatsLineSection(category: cat, title: titles[cat] ?? cat.capitalized, lines: lines)
        }
    }
}
