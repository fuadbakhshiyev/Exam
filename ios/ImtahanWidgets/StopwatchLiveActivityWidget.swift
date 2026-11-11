import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct ImtahanWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StopwatchLiveActivityWidget()
        StudyProgressWidget()
        QuestionWidget()
    }
}

private let deepLink = URL(string: "imtahan://stopwatch")
private let focusLink = URL(string: "imtahan://focus")

/// One activity for both timers: the stopwatch, or the "Fokus" (Pomodoro) countdown when `state.focus` is set.
struct StopwatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StopwatchAttributes.self) { context in
            Group {
                if let f = context.state.focus {
                    LockScreenFocusView(display: FocusDisplay(f))
                } else {
                    LockScreenStopwatchView(state: context.state)
                }
            }
            .activityBackgroundTint(StopwatchPalette.background)
            .activitySystemActionForegroundColor(StopwatchPalette.accent)
            .widgetURL(context.state.focus == nil ? deepLink : focusLink)
        } dynamicIsland: { context in
            let state = context.state
            let focus = state.focus.map { FocusDisplay($0) }
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let focus {
                        Label(focus.phase.longTitle, systemImage: focus.phase.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(focus.tint)
                            .padding(.leading, 4)
                    } else {
                        Label("Xronometr", systemImage: "stopwatch")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(StopwatchPalette.accent)
                            .padding(.leading, 4)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let focus {
                        Text(focus.note ?? focus.roundText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(StopwatchPalette.muted)
                            .padding(.trailing, 4)
                    } else if !state.isRunning {
                        Text("Dayandırılıb")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(StopwatchPalette.muted)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let focus {
                        FocusExpandedBottom(display: focus)
                    } else {
                        VStack(spacing: 10) {
                            StopwatchTimeText(state: state)
                                .font(.system(size: 40, weight: .semibold).monospacedDigit())
                                .foregroundStyle(state.isRunning ? .white : StopwatchPalette.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 10) {
                                StopwatchToggleButton(isRunning: state.isRunning, showsTitle: true)
                                StopwatchResetButton(showsTitle: true)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            } compactLeading: {
                if let focus {
                    Image(systemName: focus.isRunning ? focus.phase.symbol : "pause.fill")
                        .foregroundStyle(focus.tint)
                } else {
                    Image(systemName: state.isRunning ? "stopwatch" : "pause.fill")
                        .foregroundStyle(StopwatchPalette.accent)
                }
            } compactTrailing: {
                Group {
                    if let focus {
                        FocusTimeText(display: focus)
                            .foregroundStyle(focus.isRunning ? focus.tint : StopwatchPalette.muted)
                    } else {
                        StopwatchTimeText(state: state)
                            .foregroundStyle(state.isRunning ? StopwatchPalette.accent : StopwatchPalette.muted)
                    }
                }
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(width: 62, alignment: .trailing)
            } minimal: {
                if let focus {
                    Image(systemName: focus.isRunning ? focus.phase.symbol : "pause.fill")
                        .foregroundStyle(focus.tint)
                } else {
                    Image(systemName: state.isRunning ? "stopwatch" : "pause.fill")
                        .foregroundStyle(StopwatchPalette.accent)
                }
            }
            .widgetURL(state.focus == nil ? deepLink : focusLink)
            .keylineTint(focus?.tint ?? StopwatchPalette.accent)
        }
    }
}

/// Ticks on its own while running (anchored at startDate - accumulated); frozen HH:MM:SS when paused.
struct StopwatchTimeText: View {
    let state: StopwatchAttributes.ContentState
    var body: some View {
        if let anchor = state.anchor {
            Text(timerInterval: anchor...Date.distantFuture, countsDown: false)
        } else {
            Text(state.frozenText)
        }
    }
}

struct StopwatchToggleButton: View {
    let isRunning: Bool
    let showsTitle: Bool
    var body: some View {
        Button(intent: ToggleStopwatchIntent()) {
            Label(isRunning ? "Dayandır" : "Davam et", systemImage: isRunning ? "pause.fill" : "play.fill")
                .labelStyle(StopwatchButtonLabelStyle(showsTitle: showsTitle))
                .foregroundStyle(.white)
                .frame(maxWidth: showsTitle ? .infinity : nil, minHeight: 40)
                .padding(.horizontal, showsTitle ? 12 : 0)
                .frame(minWidth: 40)
                .background(StopwatchPalette.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct StopwatchResetButton: View {
    let showsTitle: Bool
    var body: some View {
        Button(intent: ResetStopwatchIntent()) {
            Label("Sıfırla", systemImage: "arrow.counterclockwise")
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

struct StopwatchButtonLabelStyle: LabelStyle {
    let showsTitle: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            if showsTitle { configuration.title.lineLimit(1) }
        }
        .font(.subheadline.weight(.semibold))
    }
}

/// Lock Screen / banner: compact Cublya-style dark card.
struct LockScreenStopwatchView: View {
    let state: StopwatchAttributes.ContentState
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "stopwatch")
                .font(.title3.weight(.semibold))
                .foregroundStyle(StopwatchPalette.accent)
                .frame(width: 44, height: 44)
                .background(StopwatchPalette.accent.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(state.isRunning ? "Xronometr" : "Xronometr · Dayandırılıb")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(StopwatchPalette.muted)
                StopwatchTimeText(state: state)
                    .font(.system(size: 30, weight: .semibold).monospacedDigit())
                    .foregroundStyle(state.isRunning ? .white : StopwatchPalette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            StopwatchResetButton(showsTitle: false)
            StopwatchToggleButton(isRunning: state.isRunning, showsTitle: false)
        }
        .padding(16)
    }
}
