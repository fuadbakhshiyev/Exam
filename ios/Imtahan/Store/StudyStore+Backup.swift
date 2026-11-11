import Foundation

// exportBackup / importBackup in the web's format: an object of localStorage keys (qa_v32_* and theme)
// with parsed JSON values, printed like JSON.stringify(backup, null, 2).

extension StudyStore {
    /// The web's localStorage keys.
    enum Key {
        static let stats = "qa_v32_s", wrong = "qa_v32_w", correct = "qa_v32_c", marks = "qa_v32_m"
        static let daily = "qa_v32_h", dailyGoal = "qa_v32_dg", settings = "qa_v32_conf", wrongCounts = "qa_v32_wc"
        static let updatedAt = "qa_v32_localUpdatedAt", legacyDaily = "qa_v32_d"
    }

    /// Firestore-style names accepted by importBackup.
    static let firestoreKeyMap: [String: String] = [
        "stats": Key.stats, "wrong": Key.wrong, "correct": Key.correct, "bookmarks": Key.marks,
        "daily": Key.daily, "dailyGoal": Key.dailyGoal, "settings": Key.settings,
        "wrongCounts": Key.wrongCounts, "localUpdatedAt": Key.updatedAt,
    ]

    // MARK: Export

    func exportBackup() -> String {
        var obj: [String: JSONValue] = [:]
        func put<T: Encodable>(_ key: String, _ v: T) {
            if let raw = try? JSONEncoder().encode(v), let j = try? JSONDecoder().decode(JSONValue.self, from: raw) { obj[key] = j }
        }
        put(Key.stats, data.stats)
        put(Key.wrong, data.wrong)
        put(Key.correct, data.correct)
        put(Key.marks, data.marks)
        put(Key.daily, data.history)
        if let dg = data.dailyGoal { put(Key.dailyGoal, dg) }
        if let st = data.settings { put(Key.settings, st) }
        put(Key.wrongCounts, data.wrongCounts)
        if data.updatedAt > 0 { obj[Key.updatedAt] = .number(Double(data.updatedAt)) }
        if let t = defaults.string(forKey: Self.themeKey) { obj["theme"] = .string(t) }
        return Self.jsStringify(.object(obj))
    }

    /// JSON.stringify(value, null, 2) (object keys sorted, since dictionaries have no insertion order).
    nonisolated static func jsStringify(_ v: JSONValue, indent: Int = 0) -> String {
        let pad = String(repeating: " ", count: indent + 2)
        let close = String(repeating: " ", count: indent)
        switch v {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return jsNumber(n)
        case .string(let s): return jsQuote(s)
        case .array(let a):
            if a.isEmpty { return "[]" }
            return "[\n" + a.map { pad + jsStringify($0, indent: indent + 2) }.joined(separator: ",\n") + "\n" + close + "]"
        case .object(let o):
            if o.isEmpty { return "{}" }
            let keys = o.keys.sorted(by: jsKeyLess)
            return "{\n" + keys.map { pad + jsQuote($0) + ": " + jsStringify(o[$0]!, indent: indent + 2) }.joined(separator: ",\n") + "\n" + close + "}"
        }
    }

    /// JS property order: array-index-like keys ascending first, then the rest (sorted here).
    nonisolated static func jsKeyLess(_ a: String, _ b: String) -> Bool {
        let ia = UInt32(a).flatMap { String($0) == a ? $0 : nil }, ib = UInt32(b).flatMap { String($0) == b ? $0 : nil }
        switch (ia, ib) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return jsLess(a, b)
        }
    }

    nonisolated static func jsNumber(_ n: Double) -> String {
        guard n.isFinite else { return "null" }
        if n == n.rounded(), abs(n) < 1e21 { return String(Int64(n)) }
        return "\(n)"
    }

    nonisolated static func jsQuote(_ s: String) -> String {
        var out = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
            }
        }
        return out + "\""
    }

    // MARK: Import

    /// importBackup: accepts qa_v32_* keys (values as JSON or as JSON strings), Firestore-style names
    /// (stats, wrong, correct, bookmarks, daily, dailyGoal, settings, wrongCounts, localUpdatedAt) and the
    /// legacy qa_v32_d history, merged into qa_v32_h with per-field max. Only the keys present are replaced.
    /// Returns how many keys were imported.
    @discardableResult
    func importBackup(_ text: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BackupImportError.empty }
        let root: Any
        do { root = try JSONSerialization.jsonObject(with: Data(trimmed.utf8), options: [.fragmentsAllowed]) }
        catch { throw BackupImportError.invalid(error.localizedDescription) }
        guard let input = root as? [String: Any] else { throw BackupImportError.noKeys }

        var normalized: [String: Any] = [:]
        for (k, v) in input { normalized[Self.firestoreKeyMap[k] ?? k] = v }

        // Daily history: qa_v32_h, merged with the legacy qa_v32_d
        var history: [String: Any]? = Self.jsonValue(normalized[Key.daily]) as? [String: Any]
        if let legacy = Self.jsonValue(input[Key.legacyDaily]) as? [String: Any], !legacy.isEmpty {
            if history == nil {
                history = legacy
            } else {
                for (date, dayAny) in legacy where date != "c" && date != "d" {
                    guard var day = history?[date] as? [String: Any] else { history?[date] = dayAny; continue }
                    if let legacyDay = dayAny as? [String: Any] {
                        for (course, v2) in legacyDay {
                            if let c1 = day[course] as? [String: Any], let c2 = v2 as? [String: Any] {
                                func n(_ d: [String: Any], _ k: String) -> Double { (d[k] as? NSNumber)?.doubleValue ?? 0 }
                                day[course] = ["time": max(n(c1, "time"), n(c2, "time")),
                                               "correct": max(n(c1, "correct"), n(c2, "correct")),
                                               "wrong": max(n(c1, "wrong"), n(c2, "wrong"))]
                            } else if day[course] == nil {
                                day[course] = v2
                            }
                        }
                    }
                    history?[date] = day
                }
            }
        }
        if let history { normalized[Key.daily] = history }
        normalized.removeValue(forKey: Key.legacyDaily)

        var next = data
        var count = 0
        func decode<T: Decodable>(_ key: String, _ type: T.Type) -> T? {
            guard let any = Self.jsonValue(normalized[key]), !(any is NSNull),
                  let raw = try? JSONSerialization.data(withJSONObject: any, options: [.fragmentsAllowed]) else { return nil }
            return try? JSONDecoder().decode(T.self, from: raw)
        }
        for key in normalized.keys where key.hasPrefix("qa_v32_") || key == "theme" {
            switch key {
            case Key.stats: if let v = decode(key, [String: CourseStat].self) { next.stats = v; count += 1 }
            case Key.wrong: if let v = decode(key, [String: [Question]].self) { next.wrong = v; count += 1 }
            case Key.correct: if let v = decode(key, [String: [Question]].self) { next.correct = v; count += 1 }
            case Key.marks: if let v = decode(key, [Question].self) { next.marks = v; count += 1 }
            case Key.daily: if let v = decode(key, [String: DayRecord].self) { next.history = v; count += 1 }
            case Key.dailyGoal: if let v = decode(key, DailyGoal.self) { next.dailyGoal = v; count += 1 }
            case Key.settings: if let v = decode(key, AppSettings.self) { next.settings = v; count += 1 }
            case Key.wrongCounts: if let v = decode(key, [String: Double].self) { next.wrongCounts = v.mapValues { Int($0) }; count += 1 }
            case "theme":
                if let t = normalized[key] as? String, let mode = ThemeMode(rawValue: t) { theme = mode; count += 1 }
            default:
                count += 1 // other qa_v32_* keys are stored by the web too (e.g. localUpdatedAt)
            }
        }
        guard count > 0 else { throw BackupImportError.noKeys }
        stopQuizTimer()
        data = next
        batch {
            markChanged(quick: true)
            updateDaily(increment: false)
        }
        celebration = nil
        return count
    }

    /// A localStorage value: strings are JSON text (parsed when possible), anything else is used as is.
    nonisolated static func jsonValue(_ v: Any?) -> Any? {
        guard let v else { return nil }
        if let s = v as? String {
            if let parsed = try? JSONSerialization.jsonObject(with: Data(s.utf8), options: [.fragmentsAllowed]) { return parsed }
            return s
        }
        return v
    }
}
