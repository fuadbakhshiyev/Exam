import Foundation
import SwiftUI
import UserNotifications

// Compiled into both the app and the ImtahanWidgets extension.
// "Fokus" (Pomodoro) timer: focus / break phases, state in the app-group UserDefaults next to the
// stopwatch so Live Activity buttons (LiveActivityIntents) and the app share it.
//
// Phase flow: a running focus phase rolls straight into its break (the Live Activity already carries
// the break's end date, so it can show it without the app); when a break ends the timer waits,
// ready for the next focus round, until the user starts it.

enum PomodoroPhase: String, Codable, Hashable, Sendable {
    case focus, shortBreak, longBreak

    var isBreak: Bool { self != .focus }
    var title: String { self == .focus ? "Fokus" : "Fasilə" }
    var longTitle: String {
        switch self {
        case .focus: "Fokus"
        case .shortBreak: "Fasilə"
        case .longBreak: "Uzun fasilə"
        }
    }
    var symbol: String { self == .focus ? "brain.head.profile" : "cup.and.saucer.fill" }
}

struct PomodoroSettings: Codable, Equatable, Sendable {
    var focusMinutes = 25
    var breakMinutes = 5
    var longBreakMinutes = 15
    /// A long break comes after every this many focus rounds.
    var roundsBeforeLongBreak = 4

    func seconds(_ p: PomodoroPhase) -> Int {
        switch p {
        case .focus: focusMinutes * 60
        case .shortBreak: breakMinutes * 60
        case .longBreak: longBreakMinutes * 60
        }
    }

    /// The break that follows the focus round number `completed` (1-based count after finishing it).
    func breakAfter(completed: Int) -> PomodoroPhase {
        roundsBeforeLongBreak > 0 && completed > 0 && completed % roundsBeforeLongBreak == 0 ? .longBreak : .shortBreak
    }
}

/// A point-in-time copy of the persisted Pomodoro.
struct PomodoroSnapshot: Codable, Equatable, Sendable {
    var status: StopwatchStatus = .stopped
    var phase: PomodoroPhase = .focus
    /// Focus rounds finished (or skipped) since the last reset.
    var completed = 0
    /// Length of the current phase in seconds.
    var duration = 0
    /// Unix ms when the running phase ends (0 when not running).
    var endMs: Int64 = 0
    /// Seconds left while paused / ready.
    var remaining = 0

    static func stopped(_ s: PomodoroSettings) -> PomodoroSnapshot {
        PomodoroSnapshot(duration: s.seconds(.focus), remaining: s.seconds(.focus))
    }

    var isRunning: Bool { status == .running }
    /// Running, paused or waiting for the next round: the indicators show only then.
    var isActive: Bool { status != .stopped }
    /// Paused at the very start of a phase (after a break ended, or a skip while paused).
    var isReady: Bool { status == .paused && remaining >= duration }

    var endDate: Date? { isRunning ? Date(timeIntervalSince1970: TimeInterval(endMs) / 1000) : nil }

    func secondsLeft(at now: Date = Date()) -> Int {
        guard isRunning else { return remaining }
        // Round up so the display reads 25:00 right after start and 00:01 in the last second.
        return max(0, Int(((Double(endMs - StopwatchSnapshot.nowMs(now))) / 1000).rounded(.up)))
    }

    /// 1-based round within the current long-break cycle ("Raund 2/4").
    func round(_ s: PomodoroSettings) -> Int {
        let n = max(1, s.roundsBeforeLongBreak)
        return phase == .focus ? completed % n + 1 : max(0, completed - 1) % n + 1
    }

    /// Applies phase ends that have already passed: focus → its break (keeps running), break → ready focus.
    func resolved(_ s: PomodoroSettings, at now: Date = Date()) -> PomodoroSnapshot {
        var r = self
        let nowMs = StopwatchSnapshot.nowMs(now)
        while r.status == .running && nowMs >= r.endMs {
            if r.phase == .focus {
                r.completed += 1
                r.phase = s.breakAfter(completed: r.completed)
                r.duration = s.seconds(r.phase)
                r.endMs += Int64(r.duration) * 1000
            } else {
                r = r.readyFocus(s)
            }
        }
        return r
    }

    private func readyFocus(_ s: PomodoroSettings) -> PomodoroSnapshot {
        var r = self
        r.status = .paused
        r.phase = .focus
        r.duration = s.seconds(.focus)
        r.remaining = r.duration
        r.endMs = 0
        return r
    }

    func started(_ s: PomodoroSettings, at now: Date = Date()) -> PomodoroSnapshot {
        var r = resolved(s, at: now)
        guard r.status != .running else { return r }
        if r.status == .stopped { r = .stopped(s); r.completed = 0 }
        let left = r.remaining > 0 ? r.remaining : r.duration
        r.status = .running
        r.endMs = StopwatchSnapshot.nowMs(now) + Int64(left) * 1000
        return r
    }

    func paused(_ s: PomodoroSettings, at now: Date = Date()) -> PomodoroSnapshot {
        var r = resolved(s, at: now)
        guard r.status == .running else { return r }
        r.remaining = r.secondsLeft(at: now)
        r.status = .paused
        r.endMs = 0
        return r
    }

    func toggled(_ s: PomodoroSettings, at now: Date = Date()) -> PomodoroSnapshot {
        let r = resolved(s, at: now)
        return r.isRunning ? r.paused(s, at: now) : r.started(s, at: now)
    }

    /// Ends the current phase now. Skipping focus counts the round and goes to its break; skipping a
    /// break goes to focus. A running timer keeps running in the new phase.
    func skipped(_ s: PomodoroSettings, at now: Date = Date()) -> PomodoroSnapshot {
        var r = resolved(s, at: now)
        let wasRunning = r.status == .running
        if r.phase == .focus {
            r.completed += 1
            r.phase = s.breakAfter(completed: r.completed)
        } else {
            r.phase = .focus
        }
        r.duration = s.seconds(r.phase)
        r.remaining = r.duration
        if wasRunning {
            r.status = .running
            r.endMs = StopwatchSnapshot.nowMs(now) + Int64(r.duration) * 1000
        } else {
            r.status = .paused
            r.endMs = 0
        }
        return r
    }

    #if !targetEnvironment(macCatalyst)
    /// Live Activity state; while focus runs it also carries the break that follows.
    func liveState(_ s: PomodoroSettings) -> StopwatchAttributes.ContentState.Focus {
        var next: PomodoroPhase?
        var nextEnd: Date?
        if isRunning && phase == .focus, let end = endDate {
            let b = s.breakAfter(completed: completed + 1)
            next = b
            nextEnd = end.addingTimeInterval(TimeInterval(s.seconds(b)))
        }
        return .init(phase: phase, isRunning: isRunning, endDate: endDate, duration: TimeInterval(duration),
                     remaining: TimeInterval(remaining), isReady: isReady,
                     round: round(s), rounds: max(1, s.roundsBeforeLongBreak),
                     nextPhase: next, nextEndDate: nextEnd)
    }
    #endif
}

enum TimerMode: String, Codable, Sendable { case stopwatch, focus }

enum PomodoroStorage {
    static let stateKey = "pomo_state"
    static let settingsKey = "pomo_settings"
    /// Which timer the Profil switch shows / was used last.
    static let modeKey = "timer_mode"

    static var defaults: UserDefaults { StopwatchStorage.defaults }

    static func loadSettings(from d: UserDefaults = defaults) -> PomodoroSettings {
        guard let data = d.data(forKey: settingsKey),
              let s = try? JSONDecoder().decode(PomodoroSettings.self, from: data) else { return PomodoroSettings() }
        return s
    }

    static func saveSettings(_ s: PomodoroSettings, to d: UserDefaults = defaults) {
        if let data = try? JSONEncoder().encode(s) { d.set(data, forKey: settingsKey) }
    }

    /// Stored state with already-passed phase ends applied.
    static func load(from d: UserDefaults = defaults, settings: PomodoroSettings? = nil) -> PomodoroSnapshot {
        let s = settings ?? loadSettings(from: d)
        guard let data = d.data(forKey: stateKey),
              let p = try? JSONDecoder().decode(PomodoroSnapshot.self, from: data) else { return .stopped(s) }
        return p.status == .stopped ? .stopped(s) : p.resolved(s)
    }

    static func save(_ p: PomodoroSnapshot, to d: UserDefaults = defaults) {
        if p.status == .stopped { d.removeObject(forKey: stateKey); return }
        if let data = try? JSONEncoder().encode(p) { d.set(data, forKey: stateKey) }
    }

    static func loadMode(from d: UserDefaults = defaults) -> TimerMode {
        TimerMode(rawValue: d.string(forKey: modeKey) ?? "") ?? .stopwatch
    }

    static func saveMode(_ m: TimerMode, to d: UserDefaults = defaults) { d.set(m.rawValue, forKey: modeKey) }
}

/// Phase-end notifications ("Fokus bitdi — 5 dəq fasilə", "Fasilə bitdi — fokusa qayıt").
enum PomodoroNotifications {
    static let idPrefix = "pomodoro-"
    private static let focusEndId = "pomodoro-focus-end"
    private static let breakEndId = "pomodoro-break-end"

    static func requestAuthorization() async {
        let c = UNUserNotificationCenter.current()
        guard await c.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await c.requestAuthorization(options: [.alert, .sound])
    }

    /// Replaces the pending phase-end notifications to match `p`.
    static func reschedule(_ p: PomodoroSnapshot, _ s: PomodoroSettings) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [focusEndId, breakEndId])
        guard p.isRunning, let end = p.endDate else { return }
        var breakEnd = end
        if p.phase == .focus {
            let b = s.breakAfter(completed: p.completed + 1)
            let mins = s.seconds(b) / 60
            add(c, id: focusEndId, at: end,
                title: "Fokus bitdi — \(mins) dəq \(b == .longBreak ? "uzun fasilə" : "fasilə")",
                body: "Raund \(p.round(s))/\(max(1, s.roundsBeforeLongBreak)) tamamlandı. Bir az dincəl.")
            breakEnd = end.addingTimeInterval(TimeInterval(s.seconds(b)))
        }
        add(c, id: breakEndId, at: breakEnd, title: "Fasilə bitdi — fokusa qayıt",
            body: "Növbəti \(s.focusMinutes) dəqiqəlik fokusa başlamaq üçün toxun.")
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusEndId, breakEndId])
    }

    private static func add(_ c: UNUserNotificationCenter, id: String, at date: Date, title: String, body: String) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0.5 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["url": "imtahan://focus"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        c.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

/// Mutations shared by the app and the Live Activity buttons: save, notifications, Live Activity, signal.
enum PomodoroActions {
    static func commit(_ p: PomodoroSnapshot, _ s: PomodoroSettings, allowStart: Bool) async {
        PomodoroStorage.save(p)
        PomodoroNotifications.reschedule(p, s)
        await StopwatchLiveActivity.sync(allowStart: allowStart)
    }
}

extension StopwatchPalette {
    static let breakGreen = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    static func phase(_ p: PomodoroPhase) -> Color { p.isBreak ? breakGreen : accent }
}
