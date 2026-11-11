import Foundation

// JavaScript-semantics helpers over JSONValue, so the cloud merge can be a line-by-line
// port of firebase.js. `nil` (Swift Optional) plays the role of JS `undefined`;
// `.null` is a real JSON null.

extension JSONValue {
    /// JS truthiness.
    var truthy: Bool {
        switch self {
        case .null: return false
        case .bool(let b): return b
        case .number(let n): return n != 0 && !n.isNaN
        case .string(let s): return !s.isEmpty
        case .array, .object: return true
        }
    }

    /// `typeof v === 'object' && v` (objects and arrays).
    var isObjectLike: Bool {
        switch self {
        case .array, .object: return true
        default: return false
        }
    }

    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var stringValue: String? { if case .string(let s) = self { return s }; return nil }

    /// `v[key]` for objects and arrays (index keys); `undefined` otherwise.
    subscript(js key: String) -> JSONValue? {
        switch self {
        case .object(let o): return o[key]
        case .array(let a): if let i = Int(key), i >= 0, i < a.count, String(i) == key { return a[i] }; return nil
        default: return nil
        }
    }

    /// `Object.keys(v || {})` for objects and arrays.
    var jsKeys: [String] {
        switch self {
        case .object(let o): return Array(o.keys)
        case .array(let a): return a.indices.map(String.init)
        default: return []
        }
    }
}

enum JS {
    /// firebase.js `num`: finite numbers only, everything else is 0.
    static func num(_ v: JSONValue?) -> Double {
        if case .number(let n)? = v, n.isFinite { return n }
        return 0
    }

    /// `Object.keys(o || {})` where o may be undefined.
    static func keys(_ v: JSONValue?) -> [String] {
        guard let v, v.truthy else { return [] }
        return v.jsKeys
    }

    /// `(o || {})[k]`
    static func get(_ v: JSONValue?, _ k: String) -> JSONValue? {
        guard let v, v.truthy else { return nil }
        return v[js: k]
    }

    /// `[...new Set(objs.flatMap(o => Object.keys(o || {})))]`
    static func keysOf(_ objs: JSONValue?...) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for o in objs { for k in keys(o) where seen.insert(k).inserted { out.append(k) } }
        return out
    }

    /// `[...(x || [])]` for array values (other shapes contribute nothing).
    static func elements(_ v: JSONValue?) -> [JSONValue] {
        guard let v, v.truthy, case .array(let a) = v else { return [] }
        return a
    }

    /// Unary `+v` / abstract relational coercion to number. `undefined` -> NaN.
    static func toNumber(_ v: JSONValue?) -> Double {
        guard let v else { return .nan }
        switch v {
        case .null: return 0
        case .bool(let b): return b ? 1 : 0
        case .number(let n): return n
        case .string(let s):
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? 0 : (Double(t) ?? .nan)
        case .array, .object: return .nan
        }
    }

    /// `a >= b` / `a > b` with JS coercion (string vs string compares UTF-16 code units).
    static func compare(_ a: JSONValue?, _ b: JSONValue?) -> Int? {
        if case .string(let x)? = a, case .string(let y)? = b {
            return utf16Compare(x, y)
        }
        let x = toNumber(a), y = toNumber(b)
        if x.isNaN || y.isNaN { return nil }
        return x < y ? -1 : (x > y ? 1 : 0)
    }

    static func utf16Compare(_ x: String, _ y: String) -> Int {
        var i = x.utf16.makeIterator(), j = y.utf16.makeIterator()
        while true {
            switch (i.next(), j.next()) {
            case (nil, nil): return 0
            case (nil, _): return -1
            case (_, nil): return 1
            case (let p?, let q?): if p != q { return p < q ? -1 : 1 }
            }
        }
    }

    /// Strict equality `a === b` for values parsed from JSON (objects/arrays are never identical).
    static func strictEqual(_ a: JSONValue?, _ b: JSONValue?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (.null?, .null?): return true
        case (.bool(let x)?, .bool(let y)?): return x == y
        case (.number(let x)?, .number(let y)?): return x == y
        case (.string(let x)?, .string(let y)?): return x.utf16.elementsEqual(y.utf16)
        default: return false
        }
    }
}

// MARK: - Canonical JSON (firebase.js `canon`)

enum CanonicalJSON {
    /// Sorted keys (by UTF-16 code units, like Array.prototype.sort), every `ts` key dropped at any depth.
    static func string(_ v: JSONValue?) -> String {
        var out = ""
        write(v ?? .object([:]), into: &out)
        return out
    }

    private static func write(_ v: JSONValue, into out: inout String) {
        switch v {
        case .null: out += "null"
        case .bool(let b): out += b ? "true" : "false"
        case .number(let n): out += number(n)
        case .string(let s): quote(s, into: &out)
        case .array(let a):
            out += "["
            for (i, x) in a.enumerated() { if i > 0 { out += "," }; write(x, into: &out) }
            out += "]"
        case .object(let o):
            out += "{"
            var first = true
            for k in o.keys.sorted(by: { JS.utf16Compare($0, $1) < 0 }) where k != "ts" {
                if !first { out += "," }
                first = false
                quote(k, into: &out)
                out += ":"
                write(o[k]!, into: &out)
            }
            out += "}"
        }
    }

    static func number(_ n: Double) -> String {
        if !n.isFinite { return "null" }
        if n == n.rounded(), abs(n) < 1e21 { return String(format: "%.0f", n) }
        return "\(n)"
    }

    private static func quote(_ s: String, into out: inout String) {
        out += "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
            }
        }
        out += "\""
    }
}

// MARK: - JSONValue <-> Codable / Foundation

enum JSONBridge {
    static func encode<T: Encodable>(_ value: T) -> JSONValue {
        guard let data = try? JSONEncoder().encode(value),
              let v = try? JSONDecoder().decode(JSONValue.self, from: data) else { return .null }
        return v
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: JSONValue) -> T? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// `JSON.stringify` of a value (slashes unescaped, like JS).
    static func stringify(_ value: JSONValue) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try enc.encode(value), as: UTF8.self)
    }

    /// `JSON.parse`, nil on failure.
    static func parse(_ text: String) -> JSONValue? {
        try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    /// Firestore / plist style `Any` (NSNumber, NSString, NSArray, NSDictionary, NSNull…) -> JSONValue.
    static func from(any: Any?) -> JSONValue {
        guard let any else { return .null }
        switch any {
        case is NSNull: return .null
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return .bool(n.boolValue) }
            return .number(n.doubleValue)
        case let s as String: return .string(s)
        case let a as [Any]: return .array(a.map { from(any: $0) })
        case let d as [String: Any]: return .object(d.mapValues { from(any: $0) })
        default: return .string(String(describing: any))
        }
    }
}
