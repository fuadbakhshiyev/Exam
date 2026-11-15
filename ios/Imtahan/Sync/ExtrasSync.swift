import Foundation
@preconcurrency import FirebaseFirestore

/// App-only data that the web app does not know about: exam dates per subject and learned questions.
/// Kept apart from the semester snapshot (its wire format is shared with the web app):
/// field "v32_ios" of users/{uid} (field mode) or users/{uid}/sync/v32_ios.
/// Stored compressed like the semester: { v: 1, z: base64(raw DEFLATE(json)) }.
struct SyncExtras: Codable, Equatable, Sendable {
    var dates: [String: [Double]] = [:]
    var mastery: [String: [Double]] = [:]
    /// App settings shared by all devices (SyncedPrefs.keys).
    var prefs: [String: SyncPref] = [:]

    init(dates: [String: [Double]] = [:], mastery: [String: [Double]] = [:], prefs: [String: SyncPref] = [:]) {
        self.dates = dates; self.mastery = mastery; self.prefs = prefs
    }

    /// Older clouds have no "prefs" field.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dates = try c.decodeIfPresent([String: [Double]].self, forKey: .dates) ?? [:]
        mastery = try c.decodeIfPresent([String: [Double]].self, forKey: .mastery) ?? [:]
        prefs = try c.decodeIfPresent([String: SyncPref].self, forKey: .prefs) ?? [:]
    }

    var isEmpty: Bool { dates.isEmpty && mastery.isEmpty && prefs.isEmpty }

    /// Per entry, the newer change wins (index 1 is the change time).
    static func merge(_ a: SyncExtras, _ b: SyncExtras) -> SyncExtras {
        func pick(_ x: [String: [Double]], _ y: [String: [Double]]) -> [String: [Double]] {
            x.merging(y) { l, r in (r[safe: 1] ?? 0) > (l[safe: 1] ?? 0) ? r : l }
        }
        let prefs = a.prefs.merging(b.prefs) { l, r in r.t > l.t ? r : l }
        return SyncExtras(dates: pick(a.dates, b.dates), mastery: pick(a.mastery, b.mastery), prefs: prefs)
    }

    @MainActor static var local: SyncExtras {
        SyncExtras(dates: ExamDates.shared.syncValue, mastery: MasteryStore.shared.syncValue,
                   prefs: SyncedPrefs.syncValue)
    }

    @MainActor func apply() {
        ExamDates.shared.merge(dates)
        MasteryStore.shared.merge(mastery)
        SyncedPrefs.merge(prefs)
    }

    // MARK: Wire

    static let field = "v32_ios"

    func encoded() -> [String: Any]? {
        guard let json = try? JSONEncoder().encode(self),
              let z = try? (json as NSData).compressed(using: .zlib) as Data else { return nil }
        return ["v": 1, "z": z.base64EncodedString()]
    }

    static func decode(_ v: JSONValue?) -> SyncExtras? {
        guard case .string(let z)? = v?[js: "z"], let data = Data(base64Encoded: z),
              let raw = try? (data as NSData).decompressed(using: .zlib) as Data else { return nil }
        return try? JSONDecoder().decode(SyncExtras.self, from: raw)
    }

    /// The extras inside a users/{uid} snapshot (field mode).
    static func decode(document raw: RawCloudDoc) -> SyncExtras? {
        raw.exists ? decode(raw.data[js: field]) : nil
    }
}

/// One synced setting: its value and when it was last changed.
struct SyncPref: Codable, Equatable, Sendable {
    var v: String
    var t: Double
}

/// UserDefaults settings that follow the user to every device (Fənlər görünüşü, sıralama, sıra).
/// The newest change wins. Change times are kept beside the values, so @AppStorage stays as is.
@MainActor enum SyncedPrefs {
    static let keys = ["subjects_layout", "subjects_sort", "subjects_order"]
    private static let metaKey = "synced_prefs_meta"

    private static func load() -> [String: SyncPref] {
        guard let d = UserDefaults.standard.data(forKey: metaKey),
              let m = try? JSONDecoder().decode([String: SyncPref].self, from: d) else { return [:] }
        return m
    }

    private static func save(_ m: [String: SyncPref]) {
        if let d = try? JSONEncoder().encode(m) { UserDefaults.standard.set(d, forKey: metaKey) }
    }

    /// Current values, stamping any that changed since the last look.
    /// A setting never touched on this device gets time 0, so it never beats a real choice elsewhere.
    static var syncValue: [String: SyncPref] {
        var m = load()
        var changed = false
        for k in keys {
            let v = UserDefaults.standard.string(forKey: k) ?? ""
            if m[k]?.v != v {
                m[k] = SyncPref(v: v, t: m[k] == nil && v.isEmpty ? 0 : Date().timeIntervalSince1970 * 1000)
                changed = true
            }
        }
        if changed { save(m) }
        return m
    }

    /// Call after the user changes one of the keys: stamps it and pushes soon.
    static func noteChanged() {
        let before = load()
        let after = syncValue
        if before != after { StudyStore.shared.onLocalChange?(true) }
    }

    static func merge(_ remote: [String: SyncPref]) {
        var m = syncValue
        var changed = false
        for (k, r) in remote where keys.contains(k) && r.t > (m[k]?.t ?? 0) && r.v != m[k]?.v {
            if r.v.isEmpty { UserDefaults.standard.removeObject(forKey: k) }
            else { UserDefaults.standard.set(r.v, forKey: k) }
            m[k] = r
            changed = true
        }
        if changed { save(m) }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

struct ExtrasDocument: Sendable {
    let uid: String
    let mode: SyncMode

    private var ref: DocumentReference {
        let user = Firestore.firestore().collection("users").document(uid)
        return mode == .field ? user : user.collection("sync").document(SyncExtras.field)
    }

    func read() async throws -> SyncExtras? {
        let d = try await ref.getDocument()
        guard d.exists else { return nil }
        let data = JSONBridge.from(any: d.data() ?? [:])
        return SyncExtras.decode(mode == .field ? data[js: SyncExtras.field] : data)
    }

    func write(_ e: SyncExtras) async throws {
        guard let value = e.encoded() else { return }
        if mode == .field {
            do { try await ref.updateData([SyncExtras.field: value]) }
            catch let err as NSError where err.domain == FirestoreErrorDomain && err.code == FirestoreErrorCode.notFound.rawValue {
                try await ref.setData([SyncExtras.field: value], merge: true)
            }
        } else {
            try await ref.setData(value)
        }
    }
}
