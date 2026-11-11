import Foundation

// Shared data contract. Every persisted shape mirrors the web app's localStorage JSON
// (keys qa_v32_*) exactly, so backups and the Firebase document stay compatible
// between the web app and this app. Do not rename coding keys.

/// One question. `c` = course key (subject name, "Mixed", "<subject>_pdf_<idx>" or "<subject>_final_<sinavId>"),
/// `u` = unit number (for Mixed: 1-based index into SUBJECTS; for pdf: exam idx + 1; -2 = frequent).
/// `q` and `o` contain light HTML (<strong>, <b>, <u>, <br>, <sup>, <p>, <img src="img/oys/..">, entities).
struct Question: Codable, Hashable, Sendable {
    var c: String
    var u: Int
    var q: String
    var o: [String]
    var a: Int

    init(c: String, u: Int, q: String, o: [String], a: Int) {
        self.c = c; self.u = u; self.q = q; self.o = o; self.a = a
    }

    enum CodingKeys: String, CodingKey { case c, u, q, o, a }

    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        c = (try? k.decode(String.self, forKey: .c)) ?? ""
        u = (try? k.decode(Int.self, forKey: .u)) ?? Int((try? k.decode(Double.self, forKey: .u)) ?? 0)
        q = (try? k.decode(String.self, forKey: .q)) ?? ""
        o = (try? k.decode([String].self, forKey: .o)) ?? []
        a = (try? k.decode(Int.self, forKey: .a)) ?? Int((try? k.decode(Double.self, forKey: .a)) ?? 0)
    }
}

/// Per sub-section counters: stats[course].bd[category][sub]. `last` = ms since 1970.
struct SubStat: Codable, Hashable, Sendable {
    var t: Int = 0
    var c: Int = 0
    var w: Int = 0
    var last: Int64 = 0

    init(t: Int = 0, c: Int = 0, w: Int = 0, last: Int64 = 0) { self.t = t; self.c = c; self.w = w; self.last = last }
    enum CodingKeys: String, CodingKey { case t, c, w, last }
    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        t = k.lenientInt(.t); c = k.lenientInt(.c); w = k.lenientInt(.w); last = Int64(k.lenientDouble(.last))
    }
}

/// stats[course]. Also used for "_platform" (only `time` set).
/// `bd` categories used by the web app: units, mixed, wrong, pdf-exam, mixed-only, conflicting-quiz, mock, surprise.
struct CourseStat: Codable, Hashable, Sendable {
    var t: Int = 0
    var c: Int = 0
    var w: Int = 0
    var time: Int = 0
    var bd: [String: [String: SubStat]] = [:]

    init(t: Int = 0, c: Int = 0, w: Int = 0, time: Int = 0, bd: [String: [String: SubStat]] = [:]) {
        self.t = t; self.c = c; self.w = w; self.time = time; self.bd = bd
    }
    enum CodingKeys: String, CodingKey { case t, c, w, time, bd }
    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        t = k.lenientInt(.t); c = k.lenientInt(.c); w = k.lenientInt(.w); time = k.lenientInt(.time)
        bd = (try? k.decode([String: [String: SubStat]].self, forKey: .bd)) ?? [:]
    }
}

/// dailyHistory["YYYY-MM-DD"][course] (pdf keys are folded into the subject name).
struct DayCourse: Codable, Hashable, Sendable {
    var time: Int = 0
    var correct: Int = 0
    var wrong: Int = 0
    init(time: Int = 0, correct: Int = 0, wrong: Int = 0) { self.time = time; self.correct = correct; self.wrong = wrong }
    enum CodingKeys: String, CodingKey { case time, correct, wrong }
    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        time = k.lenientInt(.time); correct = k.lenientInt(.correct); wrong = k.lenientInt(.wrong)
    }
}

/// One day of history. JSON shape: { "platformTime": 123, "<course>": {time,correct,wrong}, ... }.
/// Unknown non-object keys (e.g. "personalNotes") are kept verbatim in `extra` so nothing is lost on round-trip.
struct DayRecord: Codable, Hashable, Sendable {
    var platformTime: Int = 0
    var courses: [String: DayCourse] = [:]
    var extra: [String: JSONValue] = [:]

    init(platformTime: Int = 0, courses: [String: DayCourse] = [:]) { self.platformTime = platformTime; self.courses = courses }

    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: AnyKey.self)
        for key in k.allKeys {
            if key.stringValue == "platformTime" {
                platformTime = k.lenientInt(key)
            } else if let v = try? k.decode(DayCourse.self, forKey: key), (try? k.decode([String: JSONValue].self, forKey: key)) != nil {
                courses[key.stringValue] = v
            } else if let v = try? k.decode(JSONValue.self, forKey: key) {
                extra[key.stringValue] = v
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var k = encoder.container(keyedBy: AnyKey.self)
        if platformTime != 0 || courses.isEmpty { try k.encode(platformTime, forKey: AnyKey("platformTime")) }
        for (name, v) in courses { try k.encode(v, forKey: AnyKey(name)) }
        for (name, v) in extra { try k.encode(v, forKey: AnyKey(name)) }
    }
}

/// qa_v32_dg: { d: Date().toDateString() e.g. "Wed Nov 11 2026", c: count }
struct DailyGoal: Codable, Hashable, Sendable {
    var d: String = ""
    var c: Int = 0
}

/// qa_v32_conf
struct AppSettings: Codable, Hashable, Sendable {
    var scale: Double = 1
}

/// Everything persisted for the current semester (mirrors qa_v32_s/w/c/m/h/dg/conf/wc).
struct StudyData: Codable, Hashable, Sendable {
    var stats: [String: CourseStat] = [:]          // qa_v32_s
    var wrong: [String: [Question]] = [:]          // qa_v32_w
    var correct: [String: [Question]] = [:]        // qa_v32_c
    var marks: [Question] = []                     // qa_v32_m
    var history: [String: DayRecord] = [:]         // qa_v32_h
    var dailyGoal: DailyGoal? = nil                // qa_v32_dg
    var settings: AppSettings? = nil               // qa_v32_conf
    var wrongCounts: [String: Int] = [:]           // qa_v32_wc  (key = question text q)
    var updatedAt: Int64 = 0                       // qa_v32_localUpdatedAt (ms)
}

/// Which exam the user is preparing for. Device-local (UserDefaults "exam_mode"); deliberately NOT part of
/// StudyData, backups or the synced document, so the web app's data stays wire-compatible.
enum ExamMode: String, CaseIterable, Sendable, Identifiable {
    case vize, final

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vize: return "Vize"
        case .final: return "Final"
        }
    }

    /// Highest unit in scope; nil = every unit.
    var maxUnit: Int? {
        switch self {
        case .vize: return 7
        case .final: return nil
        }
    }

    var explanation: String {
        switch self {
        case .vize: return "Yalnız 1–7-ci ünitələr"
        case .final: return "Bütün ünitələr"
        }
    }

    /// Is a unit (1-based) studied in this mode?
    func includes(unit: Int) -> Bool { maxUnit.map { unit <= $0 } ?? true }
}

// MARK: - Static content (bundled)

struct CourseStyle: Sendable {
    let icon: String
    let accent: String   // hex "#rrggbb"
    let g1: String
    let g2: String
}

enum Catalog {
    /// Subjects in order. Mixed questions use u = index+1 into this list.
    static let subjects = ["Grafik Üretim Teknikleri", "Özgün Baskı Teknikleri", "Reklam Grafiği", "Tasarım Okumaları", "Web Tasarımının Temelleri"]
    static let unitCounts: [String: Int] = ["Grafik Üretim Teknikleri": 14, "Özgün Baskı Teknikleri": 14, "Reklam Grafiği": 14, "Tasarım Okumaları": 7, "Web Tasarımının Temelleri": 14]
    /// CONFIG keys order: "Mixed" first, then subjects.
    static let configKeys = ["Mixed"] + subjects
    static let mixedKey = "Mixed"
    static let mockKey = "🎲 Ümumi Sınaq"
    static let overallKey = "Ümumi Toplam"
    static let platformKey = "_platform"
    /// Dynamics chart window (inclusive).
    static let studyPeriod = (start: "2026-11-11", end: "2026-11-22")

    static let styles: [String: CourseStyle] = [
        "Grafik Üretim Teknikleri": .init(icon: "🖨️", accent: "#10b981", g1: "#10b981", g2: "#06b6d4"),
        "Özgün Baskı Teknikleri": .init(icon: "🎨", accent: "#8b5cf6", g1: "#8b5cf6", g2: "#8b5cf6"),
        "Reklam Grafiği": .init(icon: "📢", accent: "#f59e0b", g1: "#f59e0b", g2: "#ef4444"),
        "Tasarım Okumaları": .init(icon: "📖", accent: "#8b5cf6", g1: "#8b5cf6", g2: "#ec4899"),
        "Web Tasarımının Temelleri": .init(icon: "💻", accent: "#8b5cf6", g1: "#8b5cf6", g2: "#8b5cf6"),
        "Mixed": .init(icon: "🔀", accent: "#ec4899", g1: "#ec4899", g2: "#f43f5e"),
    ]
}

// MARK: - Coding helpers

struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { stringValue = String(intValue) }
}

extension KeyedDecodingContainer {
    func lenientDouble(_ key: Key) -> Double {
        if let v = try? decode(Double.self, forKey: key), v.isFinite { return v }
        if let v = try? decode(Int.self, forKey: key) { return Double(v) }
        if let s = try? decode(String.self, forKey: key), let v = Double(s) { return v }
        return 0
    }
    func lenientInt(_ key: Key) -> Int { Int(lenientDouble(key).rounded()) }
}

/// Arbitrary JSON, for values we must carry through untouched.
enum JSONValue: Codable, Hashable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): if n == n.rounded(), abs(n) < 1e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}
