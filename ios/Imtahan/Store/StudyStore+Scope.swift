import Foundation

// Exam scope (Vize = units 1–7, Final = all units). Nothing stored is ever removed: wrong/correct lists,
// bookmarks and per-unit stats of out-of-scope units stay in `data` (and in sync/backup) and are only
// filtered when read. Every list, count and question pool goes through the helpers below.

extension StudyStore {
    /// Is the question studied in the current mode? Pdf exam questions, "frequent" copies and Mixed
    /// questions without a known unit are always in scope.
    func inScope(_ q: Question) -> Bool { bank.inScope(q, mode: examMode) }

    /// Is the unit (1-based) studied in the current mode?
    func inScope(unit: Int) -> Bool { examMode.includes(unit: unit) }

    /// A course's own questions (subject or "Mixed") in scope.
    func scopedQuestions(course: String) -> [Question] { bank.questions(course: course, mode: examMode) }

    /// Units shown for a subject in the current mode.
    func scopedUnitCount(_ course: String) -> Int { bank.unitCount(course: course, mode: examMode) }

    /// Mixed 20-question parts of the current mode.
    var scopedMixedParts: [QuestionBank.MixedPart] { bank.mixedParts(for: examMode) }

    /// wrong[key] in scope.
    func scopedWrong(_ key: String) -> [Question] { scoped(data.wrong[key]) }

    /// correct[key] in scope.
    func scopedCorrect(_ key: String) -> [Question] { scoped(data.correct[key]) }

    /// Bookmarks in scope.
    var scopedMarks: [Question] { scoped(data.marks) }

    private func scoped(_ list: [Question]?) -> [Question] {
        guard let list else { return [] }
        return examMode.maxUnit == nil ? list : list.filter { inScope($0) }
    }

    /// stats[key] with the per-unit buckets of out-of-scope units ("Unit 8"… of a subject) taken out of
    /// bd and of t/c/w. Other keys (Mixed, pdf, mock, platform) are returned unchanged: their answers
    /// cannot be attributed to a unit. Time is never adjusted. Final booklet keys ("_final_") exist only
    /// in Final mode (nil in Vize mode; the data itself is kept).
    func scopedStat(_ key: String) -> CourseStat? {
        guard var s = data.stats[key] else { return nil }
        if examMode != .final && QuestionBank.isFinalKey(key) { return nil }
        guard examMode.maxUnit != nil, Catalog.unitCounts[key] != nil, var units = s.bd["units"] else { return s }
        for (name, st) in units {
            guard name.hasPrefix("Unit "), let n = Int(name.dropFirst(5)), !inScope(unit: n) else { continue }
            units[name] = nil
            s.t = max(0, s.t - st.t); s.c = max(0, s.c - st.c); s.w = max(0, s.w - st.w)
        }
        s.bd["units"] = units.isEmpty ? nil : units
        return s
    }

    /// Short read-only label of the mode: "Vize · 1–7-ci ünitələr" / "Final · bütün ünitələr".
    var examModeLabel: String {
        examMode == .vize ? "Vize · 1–7-ci ünitələr" : "Final · bütün ünitələr"
    }
}
