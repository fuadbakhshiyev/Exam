import Foundation
@preconcurrency import FirebaseFirestore

/// App-only data that the web app does not know about: exam dates per subject and learned questions.
/// Kept apart from the semester snapshot (its wire format is shared with the web app):
/// field "v32_ios" of users/{uid} (field mode) or users/{uid}/sync/v32_ios.
/// Stored compressed like the semester: { v: 1, z: base64(raw DEFLATE(json)) }.
struct SyncExtras: Codable, Equatable, Sendable {
    var dates: [String: [Double]] = [:]
    var mastery: [String: [Double]] = [:]

    /// Per entry, the newer change wins (index 1 is the change time).
    static func merge(_ a: SyncExtras, _ b: SyncExtras) -> SyncExtras {
        func pick(_ x: [String: [Double]], _ y: [String: [Double]]) -> [String: [Double]] {
            x.merging(y) { l, r in (r[safe: 1] ?? 0) > (l[safe: 1] ?? 0) ? r : l }
        }
        return SyncExtras(dates: pick(a.dates, b.dates), mastery: pick(a.mastery, b.mastery))
    }

    @MainActor static var local: SyncExtras {
        SyncExtras(dates: ExamDates.shared.syncValue, mastery: MasteryStore.shared.syncValue)
    }

    @MainActor func apply() {
        ExamDates.shared.merge(dates)
        MasteryStore.shared.merge(mastery)
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
