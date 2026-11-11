import Foundation

extension StudyStore {
    /// "Davam et" target (Home Screen quick action): the most recently tested in-scope unit, or the next
    /// one if it is finished; the first unit of the first subject otherwise. Same rule as Ana səhifə's
    /// "Davam et" row (HomeView.continueTarget).
    func continueUnit() -> (course: String, index: Int) {
        var best: (course: String, index: Int, stat: SubStat)?
        let mixedIndex = Dictionary(scopedMixedParts.enumerated().map { ($1.statKey, $0) }, uniquingKeysWith: { a, _ in a })
        for c in Catalog.configKeys {
            for (key, st) in data.stats[c]?.bd["units"] ?? [:] where st.last > 0 {
                let idx: Int
                if c == Catalog.mixedKey {
                    guard let i = mixedIndex[key] else { continue }
                    idx = i
                } else {
                    guard key.hasPrefix("Unit "), let n = Int(key.dropFirst(5)), n >= 1, inScope(unit: n) else { continue }
                    idx = n - 1
                }
                if best == nil || st.last > best!.stat.last { best = (c, idx, st) }
            }
        }
        guard let best else { return (Catalog.subjects[0], 0) }
        let total = unitQuestionCount(best.course, index: best.index)
        if total > 0 && best.stat.c + best.stat.w >= total && best.index + 1 < unitTitles(best.course).count {
            return (best.course, best.index + 1)
        }
        return (best.course, best.index)
    }
}
