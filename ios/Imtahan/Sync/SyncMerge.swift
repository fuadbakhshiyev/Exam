import Foundation

/// Line-by-line port of firebase.js `merge` / `sameData`, over packed snapshots
/// (`{stats, wrong, correct, marks, history, dailyGoal, settings, wrongCounts, ts}`).
/// Devices are merged, never overwritten: per course the side with more answers wins.
enum SyncMerge {
    private static func weight(_ o: JSONValue?) -> Double {
        guard let o, o.isObjectLike else { return 0 }
        return JS.num(o[js: "t"]) * 1e7 + JS.num(o[js: "time"])
    }

    private static func dayWeight(_ o: JSONValue?) -> Double {
        guard let o else { return 0 }
        if o.isObjectLike { return (JS.num(o[js: "correct"]) + JS.num(o[js: "wrong"])) * 1e7 + JS.num(o[js: "time"]) }
        return JS.num(o)
    }

    /// Returns the picked value and whether it was `a`'s.
    private static func pick(_ a: JSONValue?, _ b: JSONValue?, _ w: (JSONValue?) -> Double) -> (JSONValue?, fromA: Bool) {
        if a == nil { return (b, false) }
        if b == nil { return (a, true) }
        return w(b) > w(a) ? (b, false) : (a, true)
    }

    /// `qKey`: identity used to de-duplicate list entries.
    private enum QKey: Hashable { case str([UInt16]), num(Double), bool(Bool), unique(Int) }

    private static func qKey(_ x: JSONValue, uniq: inout Int) -> QKey {
        if case .string(let s) = x { return .str(Array(s.utf16)) }
        if let q = x[js: "q"], q.truthy, x.isObjectLike {
            switch q {
            case .string(let s): return .str(Array(s.utf16))
            case .number(let n): return .num(n)
            case .bool(let b): return .bool(b)
            default: uniq += 1; return .unique(uniq)   // object identity: never equal
            }
        }
        return .str(Array(CanonicalJSON.string(x).utf16))  // JSON.stringify(x)
    }

    private static func dedupe(_ items: [JSONValue]) -> [JSONValue] {
        var seen = Set<QKey>(), out: [JSONValue] = [], uniq = 0
        for x in items where seen.insert(qKey(x, uniq: &uniq)).inserted { out.append(x) }
        return out
    }

    static func merge(_ a: JSONValue, _ b: JSONValue) -> JSONValue {
        let aStats = a[js: "stats"], bStats = b[js: "stats"]

        // stats: per course, keep the side that answered more (then: studied longer)
        var stats: [String: JSONValue] = [:]
        var aWins: [String: Bool] = [:]
        for k in JS.keysOf(aStats, bStats) {
            let (v, fromA) = pick(JS.get(aStats, k), JS.get(bStats, k), weight)
            if let v { stats[k] = v }
            aWins[k] = fromA
        }
        // which side "owns" each course, so its answer lists stay consistent with its stats
        func winner(_ k: String) -> JSONValue? {
            guard let fromA = aWins[k] else { return nil }
            return fromA ? a : b
        }
        func lists(_ field: String) -> JSONValue {
            var out: [String: JSONValue] = [:]
            let fa = a[js: field], fb = b[js: field]
            for k in JS.keysOf(fa, fb) {
                if let w = winner(k) {
                    if let v = JS.get(w[js: field], k), v.truthy {
                        switch v {
                        case .array(let arr) where !arr.isEmpty: out[k] = v
                        case .string(let s) where !s.isEmpty: out[k] = v
                        default: break
                        }
                    }
                    continue
                }
                let u = dedupe(JS.elements(JS.get(fa, k)) + JS.elements(JS.get(fb, k)))
                if !u.isEmpty { out[k] = .array(u) }
            }
            return .object(out)
        }

        // daily history: per day and per course the bigger entry, platform time = the longer one
        var history: [String: JSONValue] = [:]
        let aHist = a[js: "history"], bHist = b[js: "history"]
        for day in JS.keysOf(aHist, bHist) {
            let xv = JS.get(aHist, day), yv = JS.get(bHist, day)
            let x: JSONValue = (xv?.truthy ?? false) ? xv! : .object([:])
            let y: JSONValue = (yv?.truthy ?? false) ? yv! : .object([:])
            var d: [String: JSONValue] = [:]
            for c in JS.keysOf(x, y) {
                if let v = pick(x[js: c], y[js: c], dayWeight).0 { d[c] = v }
            }
            history[day] = .object(d)
        }

        var wrongCounts: [String: JSONValue] = [:]
        let aWC = a[js: "wrongCounts"], bWC = b[js: "wrongCounts"]
        for k in JS.keysOf(aWC, bWC) {
            wrongCounts[k] = .number(max(JS.num(JS.get(aWC, k)), JS.num(JS.get(bWC, k))))
        }

        let aIsNewer = (JS.compare(a[js: "ts"], b[js: "ts"]).map { $0 >= 0 }) ?? false
        let newer = aIsNewer ? a : b, older = aIsNewer ? b : a

        // bookmarks: everything bookmarked on either side
        let marks = dedupe(JS.elements(newer[js: "marks"]) + JS.elements(older[js: "marks"]))

        let aDG = a[js: "dailyGoal"], bDG = b[js: "dailyGoal"]
        var dailyGoal: JSONValue = or(newer[js: "dailyGoal"], older[js: "dailyGoal"]) ?? .null
        if let ag = aDG, ag.truthy, let bg = bDG, bg.truthy {
            if JS.strictEqual(ag[js: "d"], bg[js: "d"]) {
                var o = newer[js: "dailyGoal"]?.objectValue ?? [:]
                o["c"] = .number(max(JS.num(ag[js: "c"]), JS.num(bg[js: "c"])))
                dailyGoal = .object(o)
            } else {
                let ad = or(ag[js: "d"]) ?? .string(""), bd = or(bg[js: "d"]) ?? .string("")
                dailyGoal = (JS.compare(ad, bd).map { $0 > 0 } ?? false) ? ag : bg
            }
        }

        return .object([
            "stats": .object(stats),
            "wrong": lists("wrong"),
            "correct": lists("correct"),
            "marks": .array(marks),
            "history": .object(history),
            "dailyGoal": dailyGoal,
            "settings": or(newer[js: "settings"], older[js: "settings"]) ?? .null,
            "wrongCounts": .object(wrongCounts),
            "ts": .number(max(JS.num(a[js: "ts"]), JS.num(b[js: "ts"]))),
        ])
    }

    /// `x || y || ...` (returns the first truthy, else nil — callers supply the final fallback).
    private static func or(_ vals: JSONValue?...) -> JSONValue? {
        for v in vals { if let v, v.truthy { return v } }
        return nil
    }

    static func sameData(_ a: JSONValue?, _ b: JSONValue?) -> Bool {
        CanonicalJSON.string(a) == CanonicalJSON.string(b)
    }
}
