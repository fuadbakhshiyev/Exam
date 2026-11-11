import SwiftUI

// In-app "stopwatch is running" indicators. Both read SidebarStopwatch (sessionStart + accumulated, or the
// Pomodoro's phase end), the same state the Live Activity is built from.

/// Tab bar accessory, shown only while the stopwatch or the Pomodoro is running or paused with time on it.
struct StopwatchAccessoryModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isEnabled) { StopwatchAccessory() }
        } else if isEnabled {
            content.tabViewBottomAccessory { StopwatchAccessory() }
        } else {
            content
        }
    }
}

struct StopwatchAccessory: View {
    @Environment(SidebarStopwatch.self) private var stopwatch
    @Environment(AppRouter.self) private var router
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if stopwatch.surface == .focus {
            FocusAccessory()
        } else {
            stopwatchBody
        }
    }

    private var stopwatchBody: some View {
        HStack(spacing: 10) {
            Button {
                router.openTimer()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch")
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.pulse, options: .repeating, isActive: stopwatch.isRunning)
                    Text(stopwatch.display)
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(stopwatch.isRunning ? Theme.text : Theme.textMuted)
                        .contentTransition(.numericText())
                    if placement != .inline && !stopwatch.isRunning {
                        Text("Dayandırılıb").font(.caption).foregroundStyle(Theme.textMuted)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Xronometr \(stopwatch.display)\(stopwatch.isRunning ? "" : ", dayandırılıb")")
            .accessibilityHint("Profildə aç")

            if placement != .inline {
                Button { stopwatch.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textCaption)
                .accessibilityLabel("Sıfırla")
            }
            Button { stopwatch.toggle() } label: {
                Image(systemName: stopwatch.isRunning ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
            .accessibilityLabel(stopwatch.isRunning ? "Dayandır" : "Davam et")
        }
        .padding(.horizontal, 16)
        .sensoryFeedback(.impact(weight: .light), trigger: stopwatch.status)
    }
}

/// Small capsule in the quiz's progress strip: "⏱ 00:12:34"; tap pauses / resumes.
/// While the Pomodoro is the visible timer it shows its countdown instead.
struct QuizStopwatchCapsule: View {
    @Environment(SidebarStopwatch.self) private var stopwatch

    var body: some View {
        if stopwatch.surface == .focus {
            QuizFocusCapsule()
        } else if stopwatch.isActive {
            Button { stopwatch.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: stopwatch.isRunning ? "stopwatch" : "pause.fill")
                        .contentTransition(.symbolEffect(.replace))
                    Text(stopwatch.display).monospacedDigit().contentTransition(.numericText())
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(stopwatch.isRunning ? Theme.accent : Theme.textMuted)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((stopwatch.isRunning ? Theme.accent : Theme.textMuted).opacity(0.15), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: stopwatch.status)
            .accessibilityLabel("Xronometr \(stopwatch.display)")
            .accessibilityHint(stopwatch.isRunning ? "Dayandırmaq üçün toxun" : "Davam etmək üçün toxun")
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

/// Tab bar accessory while the Pomodoro is the visible timer: phase icon + countdown, skip, pause/resume.
private struct FocusAccessory: View {
    @Environment(SidebarStopwatch.self) private var stopwatch
    @Environment(AppRouter.self) private var router
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        let p = stopwatch.pomodoro
        let tint = p.phase.tint
        HStack(spacing: 10) {
            Button {
                stopwatch.mode = .focus
                router.openTimer()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: p.phase.symbol)
                        .foregroundStyle(tint)
                        .symbolEffect(.pulse, options: .repeating, isActive: p.isRunning)
                        .contentTransition(.symbolEffect(.replace))
                    Text(stopwatch.pomodoroDisplay)
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(p.isRunning ? Theme.text : Theme.textMuted)
                        .contentTransition(.numericText(countsDown: true))
                    if placement != .inline {
                        Text(statusText(p)).font(.caption).foregroundStyle(p.isRunning ? tint : Theme.textMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(p.phase.longTitle) \(stopwatch.pomodoroDisplay)\(p.isRunning ? "" : ", dayandırılıb")")
            .accessibilityHint("Profildə aç")

            if placement != .inline {
                Button { stopwatch.pomodoroSkip() } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textCaption)
                .accessibilityLabel(p.phase == .focus ? "Fasiləyə keç" : "Fokusa keç")
            }
            Button { stopwatch.pomodoroToggle() } label: {
                Image(systemName: p.isRunning ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .foregroundStyle(tint)
            .accessibilityLabel(p.isRunning ? "Dayandır" : "Davam et")
        }
        .padding(.horizontal, 16)
        .sensoryFeedback(.impact(weight: .light), trigger: p.status)
        .sensoryFeedback(.impact(weight: .medium), trigger: p.phase)
    }

    private func statusText(_ p: PomodoroSnapshot) -> String {
        if p.isRunning { return "\(p.phase.longTitle) · \(stopwatch.pomodoroRound)/\(max(1, stopwatch.pomodoroSettings.roundsBeforeLongBreak))" }
        return p.isReady ? (p.phase == .focus ? "Fokusa hazır" : "Fasiləyə hazır") : "Dayandırılıb"
    }
}

/// Quiz capsule for the Pomodoro: "🧠 18:42" in the phase colour; tap pauses / resumes.
private struct QuizFocusCapsule: View {
    @Environment(SidebarStopwatch.self) private var stopwatch

    var body: some View {
        let p = stopwatch.pomodoro
        let tint = p.isRunning ? p.phase.tint : Theme.textMuted
        Button { stopwatch.pomodoroToggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: p.isRunning ? p.phase.symbol : "pause.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(stopwatch.pomodoroDisplay).monospacedDigit().contentTransition(.numericText(countsDown: true))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: p.status)
        .accessibilityLabel("\(p.phase.longTitle) \(stopwatch.pomodoroDisplay)")
        .accessibilityHint(p.isRunning ? "Dayandırmaq üçün toxun" : "Davam etmək üçün toxun")
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
