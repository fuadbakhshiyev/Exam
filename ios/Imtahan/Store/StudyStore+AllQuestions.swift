import Foundation

// "Bütün suallar": every distinct question of one subject for the current exam mode, shuffled, as one
// test. Vize = units 1–7, Final = all units. Sources: the subject's unit questions, their Mixed copies
// (real unit from mixed_units.json), the past vize booklets and (Final only) the final booklets.
// Duplicates are merged by normalized text; a copy with a known unit wins, so every question can show
// which unit it belongs to. Booklet-only questions whose unit is unknown keep u = 0 ("Keçmiş imtahan").

extension StudyStore {
    /// Comparable form of a question text: no HTML, entities decoded, lower-cased, letters/digits only.
    nonisolated static func normalizedQuestionText(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (e, c) in [("&nbsp;", " "), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] {
            t = t.replacingOccurrences(of: e, with: c)
        }
        t = t.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "tr"))
        let parts = t.unicodeScalars.split { !CharacterSet.alphanumerics.contains($0) }
        return parts.map { String(String.UnicodeScalarView($0)) }.joined(separator: " ")
    }

    /// Distinct in-scope questions of `subject`, in a stable order (shuffle when starting).
    /// Every returned question has `c == subject` and `u` = its unit (0 when unknown).
    func allSubjectQuestions(_ subject: String) -> [Question] {
        let mode = examMode
        let cacheKey = "\(mode.rawValue)|\(subject)"
        if let hit = AllQuestionsCache.shared.items[cacheKey] { return hit }
        var out: [Question] = []
        defer { AllQuestionsCache.shared.items[cacheKey] = out }
        var index: [String: Int] = [:]

        func add(_ q: Question, unit: Int?) {
            if let u = unit, !mode.includes(unit: u) { return }
            var item = q
            item.c = subject
            item.u = unit ?? 0
            let key = Self.normalizedQuestionText(q.q)
            guard !key.isEmpty else { return }
            if let i = index[key] {
                if out[i].u == 0, item.u > 0 { out[i] = item }
            } else {
                index[key] = out.count
                out.append(item)
            }
        }

        // 1. Unit questions.
        for q in bank.questions(course: subject) where q.u >= 1 { add(q, unit: q.u) }
        // 2. Mixed copies of this subject (Mixed carries the subject index in u).
        if let si = Catalog.subjects.firstIndex(of: subject) {
            for q in bank.questions(course: Catalog.mixedKey) where q.u == si + 1 {
                add(q, unit: bank.unit(of: q))
            }
        }
        // 3. Past vize booklets: unit unknown unless the text matches a unit question above.
        for exam in bank.exams(subject: subject) {
            for q in exam { add(q, unit: nil) }
        }
        // 4. Final booklets (units 8–14 live here) — Final mode only.
        if mode == .final {
            for exam in bank.finals(subject: subject) {
                for q in exam.questions { add(q, unit: q.u >= 1 ? q.u : nil) }
            }
        }
        return out
    }
}

/// The bank never changes while the app runs, so each subject × mode list is built once.
@MainActor
final class AllQuestionsCache {
    static let shared = AllQuestionsCache()
    var items: [String: [Question]] = [:]
}
