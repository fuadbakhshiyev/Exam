import AppIntents
import Foundation

// Live Activity buttons. Compiled into both targets; the system runs LiveActivityIntents in the
// app's process when possible, otherwise in the extension. State lives in the app group either way.

struct ToggleStopwatchIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Xronometri dayandır / davam et"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        let s = StopwatchStorage.load().toggled()
        StopwatchStorage.save(s)
        if s.status == .running { pauseFocus() }
        await StopwatchLiveActivity.sync(allowStart: false)
        StopwatchStorage.postExternalChange()
        return .result()
    }
}

struct ResetStopwatchIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Xronometri sıfırla"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        StopwatchStorage.save(StopwatchSnapshot())
        await StopwatchLiveActivity.sync(allowStart: false)
        StopwatchStorage.postExternalChange()
        return .result()
    }
}

/// Only one timer runs at a time: starting the stopwatch pauses the Pomodoro.
private func pauseFocus() {
    let settings = PomodoroStorage.loadSettings()
    let p = PomodoroStorage.load(settings: settings)
    guard p.isRunning else { return }
    let paused = p.paused(settings)
    PomodoroStorage.save(paused)
    PomodoroNotifications.reschedule(paused, settings)
    PomodoroStorage.saveMode(.stopwatch)
}

/// Only one timer runs at a time: starting the Pomodoro pauses the stopwatch.
private func pauseStopwatch() {
    let sw = StopwatchStorage.load()
    guard sw.status == .running else { return }
    StopwatchStorage.save(sw.paused())
}

struct TogglePomodoroIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Fokusu dayandır / davam et"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        let settings = PomodoroStorage.loadSettings()
        let p = PomodoroStorage.load(settings: settings).toggled(settings)
        if p.isRunning { pauseStopwatch(); PomodoroStorage.saveMode(.focus) }
        await PomodoroActions.commit(p, settings, allowStart: false)
        StopwatchStorage.postExternalChange()
        return .result()
    }
}

struct SkipPomodoroIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Fokus mərhələsini keç"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        let settings = PomodoroStorage.loadSettings()
        let p = PomodoroStorage.load(settings: settings).skipped(settings)
        await PomodoroActions.commit(p, settings, allowStart: false)
        StopwatchStorage.postExternalChange()
        return .result()
    }
}
