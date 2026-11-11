import Foundation

/// FNV-1a 32-bit over UTF-16 code units (JS `charCodeAt`), printed like `(h >>> 0).toString(36)`.
enum QuestionHash {
    static func hash(_ s: String) -> String {
        var h: UInt32 = 0x811c9dc5
        for u in s.utf16 {
            h ^= UInt32(u)
            h = h &* 0x01000193
        }
        return String(h, radix: 36, uppercase: false)
    }
}

/// Port of firebase.js packDB / unpackDB / packCounts / unpackCounts / snapshot / apply.
/// Packed snapshots are kept as `JSONValue` so merging can follow the JS exactly and
/// unknown shapes written by the web app pass through untouched.
struct SyncCodec: Sendable {
    /// pools[courseKey][hash] = question
    private let pools: [String: [String: Question]]
    /// hash -> question text
    private let textByHash: [String: String]

    init(quizData: [Question], pdfExams: [String: [[Question]]], pdfSubjects: [String]) {
        var pools: [String: [String: Question]] = [:]
        var texts: [String: String] = [:]
        func add(_ k: String, _ q: Question) {
            guard !q.q.isEmpty else { return }
            let h = QuestionHash.hash(q.q)
            pools[k, default: [:]][h] = q
            texts[h] = q.q
        }
        for q in quizData { add(q.c, q) }
        let subjects = pdfSubjects + pdfExams.keys.filter { !pdfSubjects.contains($0) }.sorted()
        for s in subjects {
            for (i, exam) in (pdfExams[s] ?? []).enumerated() {
                for q in exam { add("\(s)_pdf_\(i)", q) }
            }
        }
        self.pools = pools
        self.textByHash = texts
    }

    // MARK: Questions <-> JSON

    static func json(_ q: Question) -> JSONValue {
        .object(["c": .string(q.c), "u": .number(Double(q.u)), "q": .string(q.q),
                 "o": .array(q.o.map { .string($0) }), "a": .number(Double(q.a))])
    }

    static func question(_ v: JSONValue) -> Question? {
        guard case .object = v else { return nil }
        return JSONBridge.decode(Question.self, from: v)
    }

    // MARK: pack / unpack

    /// { course: [Question] } -> { course: ["#hash" or full object] }
    func packDB(_ db: [String: [Question]]) -> JSONValue {
        var out: [String: JSONValue] = [:]
        for (k, list) in db {
            let pool = pools[k] ?? [:]
            out[k] = .array(list.map { q in
                if !q.q.isEmpty { let h = QuestionHash.hash(q.q); if pool[h] != nil { return .string("#" + h) } }
                return Self.json(q)
            })
        }
        return .object(out)
    }

    func unpackDB(_ db: JSONValue?) -> [String: [Question]] {
        var out: [String: [Question]] = [:]
        for k in JS.keys(db) {
            let pool = pools[k] ?? [:]
            let pdfIdx = Self.pdfIndex(k)
            let list: [Question] = JS.elements(JS.get(db, k)).compactMap { x in
                guard case .string(let s) = x else { return x.truthy ? Self.question(x) : nil }
                guard var q = pool[String(s.dropFirst())] else { return nil }
                if let pdfIdx { q.c = k; q.u = pdfIdx + 1 }
                return q
            }
            if !list.isEmpty { out[k] = list }
        }
        return out
    }

    /// `k.match(/_pdf_(\d+)$/)`
    static func pdfIndex(_ k: String) -> Int? {
        guard let r = k.range(of: "_pdf_[0-9]+$", options: .regularExpression) else { return nil }
        return Int(k[r].dropFirst(5))
    }

    func packCounts(_ wc: [String: Int]) -> JSONValue {
        var out: [String: JSONValue] = [:]
        for (t, n) in wc {
            let h = QuestionHash.hash(t)
            let key = (textByHash[h].map { $0.utf16.elementsEqual(t.utf16) } ?? false) ? "#" + h : t
            out[key] = .number(Double(n))
        }
        return .object(out)
    }

    func unpackCounts(_ wc: JSONValue?) -> [String: Int] {
        var out: [String: Int] = [:]
        for k in JS.keys(wc) {
            let t: String? = k.hasPrefix("#") ? textByHash[String(k.dropFirst())] : k
            guard let t, !t.isEmpty, let v = JS.get(wc, k) else { continue }
            out[t] = Int(JS.toNumber(v).isFinite ? JS.toNumber(v).rounded() : 0)
        }
        return out
    }

    // MARK: snapshot / apply

    /// firebase.js `snapshot()`: local data in the packed cloud form.
    func snapshot(_ d: StudyData) -> JSONValue {
        .object([
            "stats": JSONBridge.encode(d.stats),
            "wrong": packDB(d.wrong),
            "correct": packDB(d.correct),
            "marks": .array(d.marks.map(Self.json)),
            "history": JSONBridge.encode(d.history),
            "dailyGoal": d.dailyGoal.map { JSONBridge.encode($0) } ?? .null,
            "settings": d.settings.map { JSONBridge.encode($0) } ?? .null,
            "wrongCounts": packCounts(d.wrongCounts),
            "ts": .number(Double(d.updatedAt)),
        ])
    }

    /// firebase.js `apply(cloud)`: packed snapshot -> local data. `current` supplies
    /// dailyGoal/settings when the cloud has none (the web keeps the local key then).
    func unpack(_ cloud: JSONValue, current: StudyData) -> StudyData {
        var d = StudyData()
        d.stats = decodeMap(cloud[js: "stats"], CourseStat.self)
        d.wrong = unpackDB(cloud[js: "wrong"])
        d.correct = unpackDB(cloud[js: "correct"])
        d.marks = JS.elements(cloud[js: "marks"]).compactMap(Self.question)
        d.history = decodeMap(cloud[js: "history"], DayRecord.self)
        if let g = cloud[js: "dailyGoal"], g.truthy { d.dailyGoal = JSONBridge.decode(DailyGoal.self, from: g) ?? current.dailyGoal }
        else { d.dailyGoal = current.dailyGoal }
        if let s = cloud[js: "settings"], s.truthy { d.settings = JSONBridge.decode(AppSettings.self, from: s) ?? current.settings }
        else { d.settings = current.settings }
        d.wrongCounts = unpackCounts(cloud[js: "wrongCounts"])
        let ts = JS.num(cloud[js: "ts"])
        d.updatedAt = ts != 0 ? Int64(ts) : Int64(Date().timeIntervalSince1970 * 1000)
        return d
    }

    /// Decodes each entry separately so one odd value cannot drop the whole map.
    private func decodeMap<T: Decodable>(_ v: JSONValue?, _ type: T.Type) -> [String: T] {
        guard case .object(let o)? = v else { return [:] }
        var out: [String: T] = [:]
        for (k, x) in o { if let t = JSONBridge.decode(T.self, from: x) { out[k] = t } }
        return out
    }
}
