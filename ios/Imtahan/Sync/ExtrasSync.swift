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
    /// Finished mixed exams and vize booklets (MixedExamHistory).
    var history: [MixedExamAttempt] = []
    /// Nailiyyətlər (AchievementStore).
    var achievements: AchievementStore.FileShape? = nil
    /// Ağıllı təkrar boxes by question text, and removals (ReviewStore).
    var review: ReviewSync? = nil
    /// Half-done tests (QuizProgressStore), so a test left on one device continues on the other.
    var progress: ProgressSync? = nil
    /// Asan / Çətin marks (DifficultyStore): key → [level, changedAt].
    var difficulty: [String: [Double]] = [:]

    init(dates: [String: [Double]] = [:], mastery: [String: [Double]] = [:], prefs: [String: SyncPref] = [:],
         history: [MixedExamAttempt] = [], achievements: AchievementStore.FileShape? = nil, review: ReviewSync? = nil,
         progress: ProgressSync? = nil, difficulty: [String: [Double]] = [:]) {
        self.dates = dates; self.mastery = mastery; self.prefs = prefs
        self.history = history; self.achievements = achievements; self.review = review
        self.progress = progress; self.difficulty = difficulty
    }

    /// Older clouds lack the newer fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dates = try c.decodeIfPresent([String: [Double]].self, forKey: .dates) ?? [:]
        mastery = try c.decodeIfPresent([String: [Double]].self, forKey: .mastery) ?? [:]
        prefs = (try? c.decodeIfPresent([String: SyncPref].self, forKey: .prefs)) ?? [:]
        history = (try? c.decodeIfPresent([MixedExamAttempt].self, forKey: .history)) ?? []
        achievements = try? c.decodeIfPresent(AchievementStore.FileShape.self, forKey: .achievements)
        review = try? c.decodeIfPresent(ReviewSync.self, forKey: .review)
        progress = try? c.decodeIfPresent(ProgressSync.self, forKey: .progress)
        difficulty = (try? c.decodeIfPresent([String: [Double]].self, forKey: .difficulty)) ?? [:]
    }

    var isEmpty: Bool {
        dates.isEmpty && mastery.isEmpty && prefs.isEmpty && history.isEmpty && achievements == nil && (review?.isEmpty ?? true) && (progress?.isEmpty ?? true) && difficulty.isEmpty
    }

    /// Per entry, the newer change wins (index 1 is the change time).
    static func merge(_ a: SyncExtras, _ b: SyncExtras) -> SyncExtras {
        func pick(_ x: [String: [Double]], _ y: [String: [Double]]) -> [String: [Double]] {
            x.merging(y) { l, r in (r[safe: 1] ?? 0) > (l[safe: 1] ?? 0) ? r : l }
        }
        let prefs = a.prefs.merging(b.prefs) { l, r in r.t > l.t ? r : l }
        let ach: AchievementStore.FileShape? = switch (a.achievements, b.achievements) {
        case let (x?, y?): AchievementStore.FileShape.merge(x, y)
        case let (x, y): x ?? y
        }
        let rev: ReviewSync? = switch (a.review, b.review) {
        case let (x?, y?): ReviewSync.merge(x, y)
        case let (x, y): x ?? y
        }
        let prog: ProgressSync? = switch (a.progress, b.progress) {
        case let (x?, y?): ProgressSync.merge(x, y)
        case let (x, y): x ?? y
        }
        return SyncExtras(dates: pick(a.dates, b.dates), mastery: pick(a.mastery, b.mastery), prefs: prefs,
                          history: MixedExamAttempt.merge(a.history, b.history), achievements: ach, review: rev,
                          progress: prog, difficulty: pick(a.difficulty, b.difficulty))
    }

    @MainActor static var local: SyncExtras {
        SyncExtras(dates: ExamDates.shared.syncValue, mastery: MasteryStore.shared.syncValue,
                   prefs: SyncedPrefs.syncValue, history: MixedExamHistory.shared.syncValue,
                   achievements: AchievementStore.shared.syncValue, review: ReviewStore.shared.syncValue,
                   progress: QuizProgressStore.shared.syncValue, difficulty: DifficultyStore.shared.syncValue)
    }

    @MainActor func apply() {
        ExamDates.shared.merge(dates)
        MasteryStore.shared.merge(mastery)
        SyncedPrefs.merge(prefs)
        MixedExamHistory.shared.merge(history)
        if let achievements { AchievementStore.shared.merge(achievements) }
        if let review { ReviewStore.shared.merge(review) }
        if let progress { QuizProgressStore.shared.merge(progress) }
        DifficultyStore.shared.merge(difficulty)
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

/// One synced setting: its value (JSON of the UserDefaults object, "" = not set) and when it changed.
struct SyncPref: Codable, Equatable, Sendable {
    var v: String
    var t: Double
}

/// UserDefaults settings that follow the user to every device. The newest change wins.
/// Change times are kept beside the values, so the settings code (@AppStorage, didSet) stays as is:
/// any UserDefaults write is noticed, stamped and pushed.
@MainActor enum SyncedPrefs {
    static let keys = [
        // Fənlər
        "subjects_layout", "subjects_sort", "subjects_order",
        // Tənzimləmələr
        "theme", "quiz_dashboard_layout", "exam_mode", "exam_date", "haptics_enabled",
        "requeue_wrong", "quiz_list_mode", "quiz_reveal_at_end", "sort_show_answer",
        // Sürpriz sual
        "surprise_enabled", "surprise_interval_min", "surprise_subjects",
        // Kilid ekranında sual (on/off stays per device, so the Mac and the phone don't both ring)
        "lockq_interval_min", "lockq_start_hour", "lockq_end_hour",
        // Bildirişlər
        "reminder_enabled", "reminder_hour", "reminder_minute", "reminder_goal", "weekly_report_enabled",
    ]
    private static let metaKey = "synced_prefs_meta"
    /// Posted after cloud values were written, so objects holding a copy reload.
    static let didApply = Notification.Name("SyncedPrefsDidApply")
    private static var observer: NSObjectProtocol?
    private static var pending: Task<Void, Never>?

    /// Watches UserDefaults: a changed synced key is stamped and pushed soon.
    static func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                pending?.cancel()
                pending = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    noteChanged()
                }
            }
        }
    }

    private static func encode(_ o: Any?) -> String {
        guard let o, let d = try? JSONSerialization.data(withJSONObject: [o]), let s = String(data: d, encoding: .utf8) else { return "" }
        return s
    }

    private static func decode(_ s: String) -> Any? {
        guard !s.isEmpty, let d = s.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: d) as? [Any] else { return nil }
        return arr.first
    }

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
            let v = encode(UserDefaults.standard.object(forKey: k))
            if m[k]?.v != v {
                m[k] = SyncPref(v: v, t: m[k] == nil && v.isEmpty ? 0 : Date().timeIntervalSince1970 * 1000)
                changed = true
            }
        }
        if changed { save(m) }
        return m
    }

    /// Stamps changed keys and pushes soon.
    static func noteChanged() {
        let before = load()
        let after = syncValue
        if before != after { StudyStore.shared.onLocalChange?(true) }
    }

    static func merge(_ remote: [String: SyncPref]) {
        var m = syncValue
        var changed = false
        for (k, r) in remote where keys.contains(k) && r.t > (m[k]?.t ?? 0) && r.v != m[k]?.v {
            m[k] = r
            save(m)   // before the write, so the change observer sees nothing new
            if let o = decode(r.v) { UserDefaults.standard.set(o, forKey: k) }
            else { UserDefaults.standard.removeObject(forKey: k) }
            changed = true
        }
        if changed { NotificationCenter.default.post(name: didApply, object: nil) }
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
