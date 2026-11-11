import Foundation
import Observation

// main.js SidebarTimer: a free stopwatch persisted with the web's localStorage keys
// (sb_timer_status, sb_timer_accumulated, sb_timer_session_start; values stored as strings like localStorage).
// Storage is the app-group UserDefaults (StopwatchStorage) so the Live Activity buttons share it.
//
// Also owns the "Fokus" (Pomodoro) timer (PomodoroStorage, same app group). Only one of the two runs
// at a time: starting one pauses the other.

@MainActor
@Observable
final class SidebarStopwatch {
    typealias Status = StopwatchStatus

    static let statusKey = StopwatchStorage.statusKey
    static let accumulatedKey = StopwatchStorage.accumulatedKey
    static let sessionStartKey = StopwatchStorage.sessionStartKey

    private(set) var snapshot = StopwatchSnapshot()
    private(set) var seconds = 0

    // MARK: Pomodoro state
    private(set) var pomodoro = PomodoroSnapshot()
    /// Seconds left in the current Pomodoro phase (ticks while running).
    private(set) var pomodoroSeconds = 0
    var pomodoroSettings: PomodoroSettings {
        didSet {
            guard pomodoroSettings != oldValue else { return }
            PomodoroStorage.saveSettings(pomodoroSettings, to: defaults)
            // A stopped or ready timer picks up the new length right away.
            if pomodoro.status == .stopped { applyPomodoro(.stopped(pomodoroSettings)) }
            else if pomodoro.isReady {
                var p = pomodoro
                p.duration = pomodoroSettings.seconds(p.phase)
                p.remaining = p.duration
                commitPomodoro(p, allowStart: false)
            }
        }
    }
    /// Profil's Xronometr / Fokus switch.
    var mode: TimerMode {
        didSet { if mode != oldValue { PomodoroStorage.saveMode(mode, to: defaults); syncLiveActivity() } }
    }

    var status: Status { snapshot.status }
    /// Stopwatch running, or paused with time on the clock.
    var stopwatchActive: Bool { snapshot.status == .running || (snapshot.status == .paused && seconds > 0) }
    var isRunning: Bool { snapshot.status == .running }

    /// Which timer the indicators (tab bar accessory, quiz capsule) show; nil = none.
    var surface: TimerMode? {
        var sw = snapshot
        if !stopwatchActive { sw = StopwatchSnapshot() }
        return TimerSurface.pick(stopwatch: sw, pomodoro: pomodoro, mode: mode)
    }
    /// Either timer is running or has time on it: the in-app indicators show only then.
    var isActive: Bool { surface != nil }

    /// "MM:SS", from one hour "H:MM:SS"
    var display: String { StopwatchSnapshot.format(seconds) }
    var pomodoroDisplay: String { StopwatchSnapshot.format(pomodoroSeconds) }
    var pomodoroRound: Int { pomodoro.round(pomodoroSettings) }
    /// 0...1 of the current phase already elapsed.
    var pomodoroProgress: Double {
        pomodoro.duration > 0 ? 1 - Double(pomodoroSeconds) / Double(pomodoro.duration) : 0
    }

    /// Start button: "Durdur" while running, "Davam et" when paused, "Başla" when stopped.
    var buttonTitle: String {
        switch status {
        case .running: return "Durdur"
        case .paused: return "Davam et"
        case .stopped: return "Başla"
        }
    }

    var pomodoroButtonTitle: String {
        if pomodoro.isRunning { return "Durdur" }
        if pomodoro.status == .stopped || pomodoro.isReady { return "Başla" }
        return "Davam et"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var askedNotifications = false

    /// init(): restores a running or paused stopwatch / Pomodoro.
    init(defaults: UserDefaults? = nil) {
        if defaults == nil { StopwatchStorage.migrateIfNeeded() }
        let d = defaults ?? StopwatchStorage.defaults
        self.defaults = d
        pomodoroSettings = PomodoroStorage.loadSettings(from: d)
        mode = PomodoroStorage.loadMode(from: d)
        apply(StopwatchStorage.load(from: d))
        applyPomodoro(PomodoroStorage.load(from: d, settings: pomodoroSettings))
        observer = NotificationCenter.default.addObserver(forName: StopwatchStorage.didChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        Self.observeDarwin()
    }

    /// Re-reads storage (after a Live Activity button or on returning to the foreground).
    func reload() {
        let s = StopwatchStorage.load(from: defaults)
        if s != snapshot { apply(s) } else { refreshSeconds() }
        let m = PomodoroStorage.loadMode(from: defaults)
        if m != mode { mode = m }
        let p = PomodoroStorage.load(from: defaults, settings: pomodoroSettings)
        if p != pomodoro {
            applyPomodoro(p)
            // Persists a phase end that passed while the app was away (load() already applied it).
            PomodoroStorage.save(p, to: defaults)
        } else { refreshSeconds() }
    }

    // MARK: Stopwatch

    func toggle() { status == .running ? pause() : start() }

    func start() {
        guard status != .running else { return }
        if pomodoro.isRunning { commitPomodoro(pomodoro.paused(pomodoroSettings), allowStart: false, sync: false) }
        mode = .stopwatch
        commit(snapshot.started())
    }

    func pause() {
        guard status == .running else { return }
        commit(snapshot.paused())
    }

    func reset() { commit(StopwatchSnapshot()) }

    // MARK: Pomodoro

    func pomodoroToggle() { pomodoro.isRunning ? pomodoroPause() : pomodoroStart() }

    func pomodoroStart() {
        let p = pomodoro.started(pomodoroSettings)
        guard p.isRunning else { return }
        if status == .running {
            let s = snapshot.paused()
            StopwatchStorage.save(s, to: defaults)
            apply(s)
        }
        mode = .focus
        commitPomodoro(p, allowStart: true)
        requestNotificationsOnce()
    }

    func pomodoroPause() { commitPomodoro(pomodoro.paused(pomodoroSettings), allowStart: false) }

    func pomodoroSkip() {
        guard pomodoro.status != .stopped else { return }
        commitPomodoro(pomodoro.skipped(pomodoroSettings), allowStart: pomodoro.isRunning)
    }

    func pomodoroReset() { commitPomodoro(.stopped(pomodoroSettings), allowStart: false) }

    /// Launch / foreground: update or end the Live Activity so it never shows a stale state.
    func syncLiveActivity() {
        Task { await StopwatchLiveActivity.sync(allowStart: false) }
    }

    private func requestNotificationsOnce() {
        guard !askedNotifications else { return }
        askedNotifications = true
        Task { await PomodoroNotifications.requestAuthorization() }
    }

    private func commit(_ s: StopwatchSnapshot) {
        StopwatchStorage.save(s, to: defaults)
        apply(s)
        Task { await StopwatchLiveActivity.sync(allowStart: true) }
    }

    private func commitPomodoro(_ p: PomodoroSnapshot, allowStart: Bool, sync: Bool = true) {
        applyPomodoro(p)
        if sync {
            let settings = pomodoroSettings
            Task { await PomodoroActions.commit(p, settings, allowStart: allowStart) }
        } else {
            PomodoroStorage.save(p, to: defaults)
            PomodoroNotifications.reschedule(p, pomodoroSettings)
        }
    }

    private func apply(_ s: StopwatchSnapshot) {
        snapshot = s
        refreshSeconds()
        updateTicking()
    }

    private func applyPomodoro(_ p: PomodoroSnapshot) {
        pomodoro = p
        refreshSeconds()
        updateTicking()
    }

    private func refreshSeconds() {
        let v = snapshot.seconds()
        if v != seconds { seconds = v }
        if pomodoro.isRunning {
            let r = pomodoro.resolved(pomodoroSettings)
            if r != pomodoro {
                // Phase ended in the foreground: persist, update the Live Activity (the notification fires on its own).
                pomodoro = r
                PomodoroStorage.save(r, to: defaults)
                syncLiveActivity()
                updateTicking()
            }
        }
        let p = pomodoro.secondsLeft()
        if p != pomodoroSeconds { pomodoroSeconds = p }
    }

    private func updateTicking() {
        if snapshot.status == .running || pomodoro.isRunning {
            if tickTask == nil { startTicking() }
        } else {
            tickTask?.cancel(); tickTask = nil
        }
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
