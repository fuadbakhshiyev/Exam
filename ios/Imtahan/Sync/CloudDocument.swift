import Foundation
@preconcurrency import FirebaseFirestore

/// Where this semester is stored (firebase.js `ref()`): its own document
/// users/{uid}/sync/v32, or — if the security rules only allow users/{uid} — one field of it.
enum SyncMode: String, Sendable { case doc, field }

/// A raw read of the Firestore document, already converted to Sendable JSON.
struct RawCloudDoc: Sendable {
    var exists: Bool
    var data: JSONValue        // whole document data
    var hasPendingWrites: Bool
}

/// Firestore errors carried as the JS SDK's code strings ("permission-denied", …) so the
/// status line reads like the web app's.
struct CloudError: Error, Sendable, LocalizedError {
    var code: String
    var message: String
    var errorDescription: String? { message.isEmpty ? code : "\(code): \(message)" }

    static func from(_ error: Error) -> CloudError {
        if let e = error as? CloudError { return e }
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain {
            return CloudError(code: firestoreCode(ns.code), message: ns.localizedDescription)
        }
        return CloudError(code: "xəta", message: ns.localizedDescription)
    }

    static func firestoreCode(_ code: Int) -> String {
        switch code {
        case 1: "cancelled"; case 2: "unknown"; case 3: "invalid-argument"; case 4: "deadline-exceeded"
        case 5: "not-found"; case 6: "already-exists"; case 7: "permission-denied"; case 8: "resource-exhausted"
        case 9: "failed-precondition"; case 10: "aborted"; case 11: "out-of-range"; case 12: "unimplemented"
        case 13: "internal"; case 14: "unavailable"; case 15: "data-loss"; case 16: "unauthenticated"
        default: "xəta"
        }
    }
}

/// Thin, nonisolated wrapper over the Firestore calls. Only Sendable values go in and out.
struct CloudDocument: Sendable {
    static let semester = "v32"
    static let sizeLimit = 950_000

    let uid: String
    let mode: SyncMode

    private var ref: DocumentReference {
        let user = Firestore.firestore().collection("users").document(uid)
        return mode == .field ? user : user.collection("sync").document(Self.semester)
    }

    func read() async throws -> RawCloudDoc {
        do {
            let d = try await ref.getDocument()
            return Self.raw(d)
        } catch { throw CloudError.from(error) }
    }

    /// `{ v: 3, ts, z }` where z = base64(raw DEFLATE(json UTF-8)) — the web app uses
    /// CompressionStream('deflate-raw'), Apple's .zlib is the same raw DEFLATE. Compressed because the
    /// users/{uid} document (field mode) hit Firestore's 1 MiB limit with plain `{ v: 2, json }`.
    /// Stored as the doc itself or as field "v32" of users/{uid}.
    func write(json: String, ts: Double) async throws {
        let raw = Data(json.utf8)
        guard let z = try? (raw as NSData).compressed(using: .zlib) as Data else {
            throw CloudError(code: "sıxışdırma", message: "Data sıxışdırıla bilmədi")
        }
        let b64 = z.base64EncodedString()
        if b64.utf8.count > Self.sizeLimit {
            throw CloudError(code: "çox böyük", message: "Data \(Int((Double(b64.utf8.count) / 1024).rounded())) KB-dır (limit ~1 MB)")
        }
        let tsNumber: NSNumber = (ts == ts.rounded() && abs(ts) < 9e15) ? NSNumber(value: Int64(ts)) : NSNumber(value: ts)
        let value: [String: Any] = ["v": 3, "ts": tsNumber, "z": b64]
        do {
            if mode == .field {
                // update() replaces the whole field (set with merge would keep the old broken keys)
                do { try await ref.updateData([Self.semester: value]) }
                catch let e as NSError where e.domain == FirestoreErrorDomain && e.code == FirestoreErrorCode.notFound.rawValue {
                    try await ref.setData([Self.semester: value])
                }
            } else {
                try await ref.setData(value)
            }
        } catch { throw CloudError.from(error) }
    }

    func delete() async throws {
        do {
            if mode == .field { try await ref.updateData([Self.semester: FieldValue.delete()]) }
            else { try await ref.delete() }
        } catch { throw CloudError.from(error) }
    }

    /// Live updates. The callback runs on the main queue (Firestore's default).
    func listen(_ onChange: @escaping @Sendable (Result<RawCloudDoc, CloudError>) -> Void) -> ListenerRegistration {
        ref.addSnapshotListener { snap, error in
            if let snap { onChange(.success(Self.raw(snap))) }
            else { onChange(.failure(CloudError.from(error ?? CloudError(code: "xəta", message: "")))) }
        }
    }

    private static func raw(_ d: DocumentSnapshot) -> RawCloudDoc {
        RawCloudDoc(exists: d.exists,
                    data: d.exists ? JSONBridge.from(any: d.data() ?? [:]) : .null,
                    hasPendingWrites: d.metadata.hasPendingWrites)
    }

    /// firebase.js `decode`: the packed snapshot stored in the document, or nil.
    static func decode(_ raw: RawCloudDoc, mode: SyncMode) -> JSONValue? {
        guard raw.exists else { return nil }
        let v = mode == .field ? raw.data[js: semester] : raw.data
        guard let v, v.truthy else { return nil }
        if case .string(let z)? = v[js: "z"] {
            guard let data = Data(base64Encoded: z),
                  let raw = try? (data as NSData).decompressed(using: .zlib) as Data,
                  let json = String(data: raw, encoding: .utf8),
                  let parsed = JSONBridge.parse(json), parsed.truthy else { return nil }
            return parsed
        }
        if case .string(let json)? = v[js: "json"] {
            guard let parsed = JSONBridge.parse(json), parsed.truthy else { return nil }
            return parsed
        }
        return v
    }
}
