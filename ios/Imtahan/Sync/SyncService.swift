import Foundation
import Observation
import UIKit
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
@preconcurrency import GoogleSignIn

/// Google sign-in and cloud sync — a port of the web app's firebase.js.
///
/// Kept deliberately cheap: writes happen only when something changed, at most every few
/// minutes, ~8 s after an answer and when the app goes to the background. Devices are merged,
/// never overwritten: per course the side with more answers is kept. The web app and this app
/// read and write the very same Firestore document (users/{uid}/sync/v32).
@MainActor @Observable
final class SyncService {
    struct CloudUser: Sendable, Equatable {
        var uid: String
        var displayName: String?
        var email: String?
        var photoURL: URL?
        /// What the web shows: name, else e-mail.
        var title: String { displayName?.isEmpty == false ? displayName! : (email ?? "") }
    }

    enum Status: Equatable, Sendable {
        case syncing
        case ok(at: Date)
        case error(String, at: Date)
    }

    // MARK: Observable state

    private(set) var user: CloudUser?
    private(set) var status: Status = .syncing
    /// Last sign-in failure (nil after cancel). The UI may show it as an alert.
    var signInError: String?

    /// "Sinxron ✓ 14:05" / "Xəta: permission-denied: … (14:05)" / "Sinxronlaşır…"
    var statusText: String {
        switch status {
        case .syncing: return "Sinxronlaşır…"
        case .ok(let at): return "Sinxron ✓ " + Self.hm(at)
        case .error(let err, let at): return "Xəta: \(err) (\(Self.hm(at)))"
        }
    }
    var isError: Bool { if case .error = status { return true }; return false }

    /// True only when GoogleService-Info.plist is bundled; otherwise every method is a no-op.
    nonisolated static var isConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }
    static let notConfiguredMessage = "Firebase konfiqurasiya olunmayıb"

    // MARK: Private state

    private static let saveEvery: Duration = .seconds(3 * 60)   // at most one write per 3 minutes while studying
    private static let pullEvery: TimeInterval = 60              // re-check the cloud on return, at most once a minute
    private static let quickDelay: Duration = .seconds(8)       // an answer goes out ~8 seconds later
    private static let modeKey = "fb_sync_mode"
    private static let syncedKey = "qa_v32_syncedUid"

    @ObservationIgnored private weak var store: StudyStore?
    @ObservationIgnored private var codecCache: SyncCodec?
    @ObservationIgnored private var mode: SyncMode?
    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var saving = false
    @ObservationIgnored private var applying = false
    @ObservationIgnored private var lastPull: Date = .distantPast
    @ObservationIgnored private var quickTask: Task<Void, Never>?
    @ObservationIgnored private var periodicTask: Task<Void, Never>?
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    init() {
        guard Self.isConfigured else { return }
        Self.configureFirebase()
        authHandle = Auth.auth().addStateDidChangeListener { _, u in
            let info = u.map { CloudUser(uid: $0.uid, displayName: $0.displayName, email: $0.email, photoURL: $0.photoURL) }
            Task { @MainActor [weak self] in self?.authChanged(info) }
        }
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.saveEvery)
                await self?.save()
            }
        }
    }

    private static func configureFirebase() {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    /// For `.onOpenURL { SyncService.handle(url: $0) }`.
    @discardableResult
    static func handle(url: URL) -> Bool {
        guard isConfigured else { return false }
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: Store

    /// Connects the local store: every local change marks the data for the next write.
    func attach(_ store: StudyStore) {
        self.store = store
        store.onLocalChange = { [weak self] quick in
            guard let self else { return }
            self.dirty = true
            if quick { self.scheduleQuick() }
        }
        if user != nil, Self.isConfigured {
            Task { await self.sync(); self.listen() }
        }
    }

    private var codec: SyncCodec {
        if let codecCache { return codecCache }
        let bank = QuestionBank.shared
        let c = SyncCodec(quizData: bank.all, pdfExams: bank.pdfExams, pdfSubjects: bank.pdfSubjects)
        codecCache = c
        return c
    }

    // MARK: Auth

    private func authChanged(_ u: CloudUser?) {
        user = u
        stopListening()
        if u != nil {
            status = .syncing
            Task { await self.sync(); self.listen() }
        }
    }

    func signIn() async {
        guard Self.isConfigured else { signInError = Self.notConfiguredMessage; return }
        signInError = nil
        guard let presenter = Self.topViewController() else { signInError = "Giriş pəncərəsi açılmadı"; return }
        do {
            let tokens: (id: String, access: String) = try await withCheckedThrowingContinuation { cont in
                GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
                    if let error { cont.resume(throwing: error); return }
                    guard let u = result?.user, let id = u.idToken?.tokenString else {
                        cont.resume(throwing: CloudError(code: "xəta", message: "Google ID token yoxdur")); return
                    }
                    cont.resume(returning: (id, u.accessToken.tokenString))
                }
            }
            let credential = GoogleAuthProvider.credential(withIDToken: tokens.id, accessToken: tokens.access)
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                Auth.auth().signIn(with: credential) { _, error in
                    if let error { cont.resume(throwing: error) } else { cont.resume() }
                }
            }
        } catch {
            let ns = error as NSError
            if ns.domain == kGIDSignInErrorDomain && ns.code == GIDSignInError.canceled.rawValue { return }
            signInError = "Giriş alınmadı: " + ns.localizedDescription
        }
    }

    func signOut() async {
        guard Self.isConfigured, user != nil else { return }
        await save()
        stopListening()
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        user = nil
        status = .syncing
    }

    // MARK: Sync

    /// Status button: write now.
    func syncNow() {
        Task { await save(force: true) }
    }

    func appDidBecomeActive() {
        guard user != nil, Date().timeIntervalSince(lastPull) > Self.pullEvery else { return }
        Task { await sync() }
    }

    func appWillResignActive() {
        guard user != nil, dirty else { return }
        store?.flush()
        beginBackgroundTask()
        Task {
            await save()
            endBackgroundTask()
        }
    }

    func save(force: Bool = false) async {
        guard Self.isConfigured, user != nil, dirty || force else { return }
        await sync()
    }

    /// Bring this device and the cloud together. Nothing is ever replaced wholesale:
    /// both sides are merged, so a device that was only left open can never wipe the
    /// progress made on another one.
    func sync() async {
        guard Self.isConfigured, let uid = user?.uid, let store else { return }
        if saving { dirty = true; return }
        saving = true
        lastPull = Date()
        dirty = false
        do {
            let cloud = try await readCloud(uid: uid)
            guard user?.uid == uid else { saving = false; return }   // signed out meanwhile
            let codec = self.codec
            let local = codec.snapshot(store.data)
            let merged = cloud.map { SyncMerge.merge(local, $0) } ?? local
            UserDefaults.standard.set(uid, forKey: Self.syncedKey)
            if !SyncMerge.sameData(merged, local) { apply(merged) }
            if cloud == nil || !SyncMerge.sameData(merged, cloud) {
                if cloud != nil || hasLocalData {
                    try await CloudDocument(uid: uid, mode: mode ?? .doc).write(json: JSONBridge.stringify(merged), ts: JS.num(merged[js: "ts"]))
                }
            }
            status = .ok(at: Date())
        } catch {
            dirty = true
            let e = CloudError.from(error)
            status = .error(e.errorDescription ?? e.code, at: Date())
        }
        saving = false
        if dirty { scheduleQuick() }
    }

    /// "Sıfırla": remove only this semester from the cloud.
    func deleteCloud() async throws {
        guard Self.isConfigured, let uid = user?.uid else { return }
        if mode == nil { _ = try? await readCloud(uid: uid) }
        try await CloudDocument(uid: uid, mode: mode ?? .doc).delete()
        dirty = false
    }

    private var hasLocalData: Bool {
        store?.data.stats.values.contains { $0.t > 0 } ?? false
    }

    private func readCloud(uid: String) async throws -> JSONValue? {
        if mode == nil { mode = SyncMode(rawValue: UserDefaults.standard.string(forKey: Self.modeKey) ?? "") ?? .doc }
        let m = mode ?? .doc
        do {
            let raw = try await CloudDocument(uid: uid, mode: m).read()
            return CloudDocument.decode(raw, mode: m)
        } catch let e as CloudError where e.code == "permission-denied" && m == .doc {
            mode = .field
            UserDefaults.standard.set(SyncMode.field.rawValue, forKey: Self.modeKey)
            return try await readCloud(uid: uid)
        }
    }

    private func apply(_ cloud: JSONValue) {
        guard let store else { return }
        applying = true
        defer { applying = false }
        store.applyRemote(codec.unpack(cloud, current: store.data))
    }

    private func scheduleQuick() {
        guard user != nil, quickTask == nil else { return }
        quickTask = Task { [weak self] in
            try? await Task.sleep(for: Self.quickDelay)
            guard let self else { return }
            self.quickTask = nil
            await self.save()
        }
    }

    // MARK: Live updates — when another device writes, merge it in right away

    private func listen() {
        guard Self.isConfigured, let uid = user?.uid, listener == nil, let mode else { return }
        listener = CloudDocument(uid: uid, mode: mode).listen { result in
            Task { @MainActor [weak self] in self?.onSnapshot(result, uid: uid, mode: mode) }
        }
    }

    private func onSnapshot(_ result: Result<RawCloudDoc, CloudError>, uid: String, mode: SyncMode) {
        guard user?.uid == uid, let store else { return }
        switch result {
        case .success(let raw):
            if raw.hasPendingWrites || applying || saving { return }
            guard let cloud = CloudDocument.decode(raw, mode: mode) else { return }
            let local = codec.snapshot(store.data)
            let merged = SyncMerge.merge(local, cloud)
            if !SyncMerge.sameData(merged, local) { apply(merged) }
            if !SyncMerge.sameData(merged, cloud) { dirty = true; scheduleQuick() }
            status = .ok(at: Date())
        case .failure(let e):
            status = .error(e.code, at: Date())
            listener?.remove()
            listener = nil
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: Helpers

    private static func hm(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var vc = window?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }

    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "cloud-sync") { [weak self] in
            MainActor.assumeIsolated { self?.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
