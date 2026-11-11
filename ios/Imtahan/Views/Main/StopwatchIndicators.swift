import SwiftUI

// In-app "stopwatch is running" indicators. Both read SidebarStopwatch (sessionStart + accumulated),
// the same state the Live Activity is built from.

/// Tab bar accessory, shown only while the stopwatch is running or paused with time on it.
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
        HStack(spacing: 10) {
            Button {
                router.profilePath = []
                router.tab = .profile
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
struct QuizStopwatchCapsule: View {
    @Environment(SidebarStopwatch.self) private var stopwatch

    var body: some View {
        if stopwatch.isActive {
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
