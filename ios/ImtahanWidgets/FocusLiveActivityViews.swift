import AppIntents
import SwiftUI
import WidgetKit

// "Fokus" (Pomodoro) presentation of the shared Live Activity (StopwatchAttributes with `focus` set).
// The content carries the running phase's end and, while focus runs, the break that follows; the
// activity's staleDate is the phase end, so the system re-renders it then and these views move on to
// the break (or to "ready for focus") without the app.

/// What to show right now, derived from the content state and the clock at render time.
struct FocusDisplay {
    let phase: PomodoroPhase
    let isRunning: Bool
    /// Countdown range while running.
    let interval: ClosedRange<Date>?
    /// Frozen time while paused / ready.
    let frozen: String
    let round: Int
    let rounds: Int
    /// "Fokusa hazır" etc. when not running.
    let note: String?

    init(_ f: StopwatchAttributes.ContentState.Focus, now: Date = Date()) {
        round = f.round
        rounds = f.rounds
        if f.isRunning, let end = f.endDate {
            if end > now {
                phase = f.phase; isRunning = true
                interval = end.addingTimeInterval(-max(1, f.duration))...end
                frozen = ""; note = nil
                return
            }
            if let next = f.nextPhase, let nextEnd = f.nextEndDate, nextEnd > now {
                phase = next; isRunning = true
                interval = end...nextEnd
                frozen = ""; note = nil
                return
            }
            // The break ended too: waiting for the next focus round.
            phase = .focus; isRunning = false; interval = nil
            frozen = StopwatchSnapshot.format(0); note = "Fasilə bitdi"
            return
        }
        phase = f.phase; isRunning = false; interval = nil
        frozen = StopwatchSnapshot.format(Int(f.remaining))
        note = f.isReady ? (f.phase == .focus ? "Fokusa hazır" : "Fasiləyə hazır") : "Dayandırılıb"
    }

    var tint: Color { StopwatchPalette.phase(phase) }
    var roundText: String { "Raund \(round)/\(rounds)" }
}

struct FocusTimeText: View {
    let display: FocusDisplay
    var body: some View {
        if let r = display.interval {
            Text(timerInterval: r, countsDown: true)
        } else {
            Text(display.frozen)
        }
    }
}

struct FocusProgressBar: View {
    let display: FocusDisplay
    var body: some View {
        if let r = display.interval {
            ProgressView(timerInterval: r, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(display.tint)
                .labelsHidden()
        }
    }
}

struct FocusToggleButton: View {
    let display: FocusDisplay
    let showsTitle: Bool
    var body: some View {
        Button(intent: TogglePomodoroIntent()) {
            Label(display.isRunning ? "Dayandır" : (display.note == "Dayandırılıb" ? "Davam et" : "Başla"),
                  systemImage: display.isRunning ? "pause.fill" : "play.fill")
                .labelStyle(StopwatchButtonLabelStyle(showsTitle: showsTitle))
                .foregroundStyle(.white)
                .frame(maxWidth: showsTitle ? .infinity : nil, minHeight: 40)
                .padding(.horizontal, showsTitle ? 12 : 0)
                .frame(minWidth: 40)
                .background(display.tint, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct FocusSkipButton: View {
    let display: FocusDisplay
    let showsTitle: Bool
    var body: some View {
        Button(intent: SkipPomodoroIntent()) {
            Label(display.phase == .focus ? "Fasiləyə keç" : "Fokusa keç", systemImage: "forward.end.fill")
                .labelStyle(StopwatchButtonLabelStyle(showsTitle: showsTitle))
                .foregroundStyle(.white)
                .frame(maxWidth: showsTitle ? .infinity : nil, minHeight: 40)
                .padding(.horizontal, showsTitle ? 12 : 0)
                .frame(minWidth: 40)
                .background(Color.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Lock Screen / banner card for the Pomodoro.
struct LockScreenFocusView: View {
    let display: FocusDisplay
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: display.phase.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(display.tint)
                    .frame(width: 44, height: 44)
                    .background(display.tint.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text([display.phase.longTitle, display.roundText, display.note].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(display.isRunning ? display.tint : StopwatchPalette.muted)
                        .lineLimit(1)
                    FocusTimeText(display: display)
                        .font(.system(size: 30, weight: .semibold).monospacedDigit())
                        .foregroundStyle(display.isRunning ? .white : StopwatchPalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                FocusSkipButton(display: display, showsTitle: false)
                FocusToggleButton(display: display, showsTitle: false)
            }
            FocusProgressBar(display: display)
        }
        .padding(16)
    }
}

/// Expanded Dynamic Island bottom region.
struct FocusExpandedBottom: View {
    let display: FocusDisplay
    var body: some View {
        VStack(spacing: 10) {
            FocusTimeText(display: display)
                .font(.system(size: 40, weight: .semibold).monospacedDigit())
                .foregroundStyle(display.isRunning ? .white : StopwatchPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            FocusProgressBar(display: display)
            HStack(spacing: 10) {
                FocusToggleButton(display: display, showsTitle: true)
                FocusSkipButton(display: display, showsTitle: true)
            }
        }
        .padding(.horizontal, 4)
    }
}
