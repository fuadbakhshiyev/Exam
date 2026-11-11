import Foundation
import Observation

// main.js SidebarTimer: a free stopwatch persisted with the web's localStorage keys
// (sb_timer_status, sb_timer_accumulated, sb_timer_session_start; values stored as strings like localStorage).
// Storage is the app-group UserDefaults (StopwatchStorage) so the Live Activity buttons share it.

@MainActor
@Observable
final class SidebarStopwatch {
    typealias Status = StopwatchStatus

    static let statusKey = StopwatchStorage.statusKey
    static let accumulatedKey = StopwatchStorage.accumulatedKey
    static let sessionStartKey = StopwatchStorage.sessionStartKey

    private(set) var snapshot = StopwatchSnapshot()
    private(set) var seconds = 0

    var status: Status { snapshot.status }
    /// Running, or paused with time on the clock: the in-app indicators show only then.
    var isActive: Bool { snapshot.status == .running || (snapshot.status == .paused && seconds > 0) }
    var isRunning: Bool { snapshot.status == .running }

    /// "MM:SS", from one hour "H:MM:SS"
    var display: String { StopwatchSnapshot.format(seconds) }
    /// Start button: "Durdur" while running, "Davam et" when paused, "Başla" when stopped.
    var buttonTitle: String {
        switch status {
        case .running: return "Durdur"
        case .paused: return "Davam et"
        case .stopped: return "Başla"
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var observer: NSObjectProtocol?

    /// init(): restores a running or paused stopwatch.
    init(defaults: UserDefaults? = nil) {
        if defaults == nil { StopwatchStorage.migrateIfNeeded() }
        self.defaults = defaults ?? StopwatchStorage.defaults
        apply(StopwatchStorage.load(from: self.defaults))
        observer = NotificationCenter.default.addObserver(forName: StopwatchStorage.didChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        Self.observeDarwin()
    }

    /// Re-reads storage (after a Live Activity button or on returning to the foreground).
    func reload() {
        let s = StopwatchStorage.load(from: defaults)
        if s != snapshot { apply(s) } else { refreshSeconds() }
    }

    func toggle() { status == .running ? pause() : start() }

    func start() {
        guard status != .running else { return }
        commit(snapshot.started())
    }

    func pause() {
        guard status == .running else { return }
        commit(snapshot.paused())
    }

    func reset() { commit(StopwatchSnapshot()) }

    /// Launch / foreground: update or end the Live Activity so it never shows a stale state.
    func syncLiveActivity() {
        let s = snapshot
        Task { await StopwatchLiveActivity.apply(s, allowStart: false) }
    }

    private func commit(_ s: StopwatchSnapshot) {
        StopwatchStorage.save(s, to: defaults)
        apply(s)
        Task { await StopwatchLiveActivity.apply(s, allowStart: true) }
    }

    private func apply(_ s: StopwatchSnapshot) {
        snapshot = s
        refreshSeconds()
        if s.status == .running { startTicking() } else { tickTask?.cancel(); tickTask = nil }
    }

    private func refreshSeconds() {
        let v = snapshot.seconds()
        if v != seconds { seconds = v }
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                self.refreshSeconds()
            }
        }
    }

    /// Darwin notification from the widget extension process → in-process didChange.
    private static var darwinInstalled = false
    private static func observeDarwin() {
        guard !darwinInstalled else { return }
        darwinInstalled = true
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { _, _, _, _, _ in
            Task { @MainActor in NotificationCenter.default.post(name: StopwatchStorage.didChange, object: nil) }
        }, StopwatchStorage.darwinName as CFString, nil, .deliverImmediately)
    }
}
