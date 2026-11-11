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
        await StopwatchLiveActivity.apply(s, allowStart: false)
        StopwatchStorage.postExternalChange()
        return .result()
    }
}

struct ResetStopwatchIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Xronometri sıfırla"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        let s = StopwatchSnapshot()
        StopwatchStorage.save(s)
        await StopwatchLiveActivity.apply(s, allowStart: false)
        StopwatchStorage.postExternalChange()
        return .result()
    }
}
