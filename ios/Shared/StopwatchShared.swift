import Foundation
import ActivityKit
import SwiftUI

// Compiled into both the app and the ImtahanWidgets extension.
// Single source of truth for the stopwatch: the app-group UserDefaults (same web localStorage keys,
// values stored as strings). Every surface (Profil, tab bar accessory, quiz capsule, Live Activity)
// derives its time from sessionStart + accumulated.

enum StopwatchStatus: String, Sendable, Codable { case stopped, running, paused }

/// A point-in-time copy of the persisted stopwatch.
struct StopwatchSnapshot: Sendable, Equatable {
    var status: StopwatchStatus = .stopped
    /// Whole seconds counted before the current running session.
    var accumulated: Int = 0
    /// Unix ms when the current running session started (0 when not running).
    var sessionStartMs: Int64 = 0

    static func nowMs(_ date: Date = Date()) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }

    func seconds(at now: Date = Date()) -> Int {
        guard status == .running else { return accumulated }
        return max(0, Int((Self.nowMs(now) - sessionStartMs) / 1000)) + accumulated
    }

    /// Running, or paused with time on the clock.
    var isActive: Bool { status == .running || (status == .paused && accumulated > 0) }

    var sessionStartDate: Date? {
        status == .running ? Date(timeIntervalSince1970: TimeInterval(sessionStartMs) / 1000) : nil
    }

    /// The moment the clock would read 0 if it had run continuously; drives live timer text.
    var anchorDate: Date? { sessionStartDate.map { $0.addingTimeInterval(-TimeInterval(accumulated)) } }

    func started(at now: Date = Date()) -> StopwatchSnapshot {
        guard status != .running else { return self }
        return StopwatchSnapshot(status: .running, accumulated: accumulated, sessionStartMs: Self.nowMs(now))
    }

    func paused(at now: Date = Date()) -> StopwatchSnapshot {
        guard status == .running else { return self }
        return StopwatchSnapshot(status: .paused, accumulated: seconds(at: now), sessionStartMs: 0)
    }

    func toggled(at now: Date = Date()) -> StopwatchSnapshot { status == .running ? paused(at: now) : started(at: now) }

    var contentState: StopwatchAttributes.ContentState {
        .init(startDate: sessionStartDate, accumulated: TimeInterval(accumulated), isRunning: status == .running)
    }

    /// "MM:SS" under an hour, then "H:MM:SS" (same shape as the Live Activity's system timer).
    static func format(_ s: Int) -> String {
        s < 3600 ? String(format: "%02d:%02d", s / 60, s % 60)
                 : String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

enum StopwatchStorage {
    static let appGroup = "group.az.fuadb.imtahan"
    static let statusKey = "sb_timer_status"
    static let accumulatedKey = "sb_timer_accumulated"
    static let sessionStartKey = "sb_timer_session_start"
    private static let migratedKey = "sb_timer_migrated_to_group"

    /// Posted (in-process) when the state was changed outside SidebarStopwatch, e.g. by a Live Activity button.
    static let didChange = Notification.Name("StopwatchStorageDidChange")
    /// Cross-process signal (extension → app).
    static let darwinName = "az.fuadb.imtahan.stopwatch.changed"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    /// One-time copy of the pre-app-group values from standard defaults.
    static func migrateIfNeeded() {
        let group = defaults
        guard !group.bool(forKey: migratedKey) else { return }
        let old = UserDefaults.standard
        if group.object(forKey: statusKey) == nil, let st = old.object(forKey: statusKey) {
            group.set(st, forKey: statusKey)
            if let v = old.object(forKey: accumulatedKey) { group.set(v, forKey: accumulatedKey) }
            if let v = old.object(forKey: sessionStartKey) { group.set(v, forKey: sessionStartKey) }
        }
        group.set(true, forKey: migratedKey)
    }

    static func load(from d: UserDefaults = defaults) -> StopwatchSnapshot {
        let status = StopwatchStatus(rawValue: d.string(forKey: statusKey) ?? "") ?? .stopped
        let acc = Int(d.string(forKey: accumulatedKey) ?? "") ?? d.integer(forKey: accumulatedKey)
        let start = Int64(d.string(forKey: sessionStartKey) ?? "") ?? Int64(d.integer(forKey: sessionStartKey))
        switch status {
        case .running: return StopwatchSnapshot(status: .running, accumulated: acc, sessionStartMs: start)
        case .paused: return StopwatchSnapshot(status: .paused, accumulated: acc, sessionStartMs: 0)
        case .stopped: return StopwatchSnapshot()
        }
    }

    static func save(_ s: StopwatchSnapshot, to d: UserDefaults = defaults) {
        switch s.status {
        case .stopped:
            d.removeObject(forKey: statusKey)
            d.removeObject(forKey: sessionStartKey)
            d.removeObject(forKey: accumulatedKey)
        case .running:
            d.set("running", forKey: statusKey)
            d.set(String(s.sessionStartMs), forKey: sessionStartKey)
            d.set(String(s.accumulated), forKey: accumulatedKey)
        case .paused:
            d.set("paused", forKey: statusKey)
            d.set(String(s.accumulated), forKey: accumulatedKey)
        }
    }

    static func postExternalChange() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(darwinName as CFString), nil, nil, true)
    }
}

// MARK: Live Activity

struct StopwatchAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var startDate: Date?
        var accumulated: TimeInterval
        var isRunning: Bool

        /// Clock-zero moment while running.
        var anchor: Date? { isRunning ? startDate.map { $0.addingTimeInterval(-accumulated) } : nil }
        var frozenText: String { StopwatchSnapshot.format(Int(accumulated)) }
    }
}

enum StopwatchLiveActivity {
    /// Brings Live Activities in line with the stopwatch: update, end when stopped, and (when allowed) start one.
    static func apply(_ s: StopwatchSnapshot, allowStart: Bool) async {
        let activities = Activity<StopwatchAttributes>.activities
        guard s.isActive || s.status == .running else {
            for a in activities { await a.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let content = ActivityContent(state: s.contentState, staleDate: nil)
        if activities.isEmpty {
            guard allowStart, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            _ = try? Activity.request(attributes: StopwatchAttributes(), content: content, pushType: nil)
        } else {
            // Keep exactly one.
            for (i, a) in activities.enumerated() {
                if i == 0 { await a.update(content) } else { await a.end(nil, dismissalPolicy: .immediate) }
            }
        }
    }
}

/// Cublya palette for surfaces that cannot use the app's Theme (widget extension).
enum StopwatchPalette {
    static let accent = Color(red: 0x3B / 255, green: 0x8E / 255, blue: 0xFF / 255)
    static let background = Color(red: 0x02 / 255, green: 0x02 / 255, blue: 0x02 / 255)
    static let surface = Color(red: 0x19 / 255, green: 0x19 / 255, blue: 0x19 / 255)
    static let muted = Color(red: 0x8A / 255, green: 0x8A / 255, blue: 0x8A / 255)
}
