import SwiftUI

extension PomodoroPhase {
    /// Focus = accent blue, breaks = green (same as the Live Activity).
    var tint: Color { isBreak ? Theme.success : Theme.accent }
}

/// Profil → "Xronometr" section: a Xronometr / Fokus switch over the free stopwatch and the Pomodoro.
struct TimerSection: View {
    @Environment(SidebarStopwatch.self) private var stopwatch

    var body: some View {
        @Bindable var stopwatch = stopwatch
        Section {
            Picker("Rejim", selection: $stopwatch.mode) {
                Text("Xronometr").tag(TimerMode.stopwatch)
                Text("Fokus").tag(TimerMode.focus)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowSeparator(.hidden, edges: .bottom)
            .appRow()

            if stopwatch.mode == .stopwatch {
                stopwatchRow
            } else {
                focusRow
                durations
            }
        } header: {
            Text("Xronometr")
        } footer: {
            if stopwatch.mode == .focus {
                Text("Fokus bitəndə bildiriş gəlir və fasilə öz-özünə başlayır. Fasilədən sonra növbəti raundu sən başladırsan.")
            }
        }
    }

    private var stopwatchRow: some View {
        HStack(spacing: 12) {
            Text(stopwatch.display).font(.title.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.text)
                .contentTransition(.numericText())
            Spacer()
            Button { stopwatch.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(.glass)
                .accessibilityLabel("Sıfırla")
            Button(stopwatch.buttonTitle) { stopwatch.toggle() }
                .buttonStyle(.glassProminent)
        }
        .listRowSeparator(.hidden, edges: .top)
        .appRow()
    }

    private var focusRow: some View {
        let p = stopwatch.pomodoro
        let tint = p.phase.tint
        let rounds = max(1, stopwatch.pomodoroSettings.roundsBeforeLongBreak)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    IconTile(symbol: p.phase.symbol, color: tint, size: 24)
                    Text(p.phase.longTitle)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                Spacer(minLength: 8)
                Text("Raund \(stopwatch.pomodoroRound)/\(rounds)")
                    .font(.subheadline).monospacedDigit()
                    .foregroundStyle(Theme.textMuted)
            }
            HStack(spacing: 12) {
                Text(stopwatch.pomodoroDisplay)
                    .font(.title.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(p.isRunning ? Theme.text : Theme.textMuted)
                    .contentTransition(.numericText(countsDown: true))
                Spacer()
                Button { stopwatch.pomodoroReset() } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(.glass)
                    .disabled(p.status == .stopped)
                    .accessibilityLabel("Sıfırla")
                Button { stopwatch.pomodoroSkip() } label: { Image(systemName: "forward.end.fill") }
                    .buttonStyle(.glass)
                    .disabled(p.status == .stopped)
                    .accessibilityLabel(p.phase == .focus ? "Fasiləyə keç" : "Fokusa keç")
                Button(stopwatch.pomodoroButtonTitle) { stopwatch.pomodoroToggle() }
                    .buttonStyle(.glassProminent)
                    .tint(tint)
            }
            ProgressView(value: stopwatch.pomodoroProgress)
                .tint(tint)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .animation(.snappy, value: p.phase)
        .sensoryFeedback(.impact(weight: .medium), trigger: p.phase)
        .accessibilityElement(children: .contain)
        .listRowSeparator(.hidden, edges: [.top, .bottom])
        .appRow()
    }

    @ViewBuilder private var durations: some View {
        @Bindable var stopwatch = stopwatch
        Stepper(value: $stopwatch.pomodoroSettings.focusMinutes, in: 5...90, step: 5) {
            LabeledContent("Fokus", value: "\(stopwatch.pomodoroSettings.focusMinutes) dəq")
        }
        .listRowSeparator(.hidden, edges: .top)
        .appRow()
        Stepper(value: $stopwatch.pomodoroSettings.breakMinutes, in: 1...30) {
            LabeledContent("Fasilə", value: "\(stopwatch.pomodoroSettings.breakMinutes) dəq")
        }
        .appRow()
        Stepper(value: $stopwatch.pomodoroSettings.longBreakMinutes, in: 5...60, step: 5) {
            LabeledContent("Uzun fasilə", value: "\(stopwatch.pomodoroSettings.longBreakMinutes) dəq")
        }
        .appRow()
        Stepper(value: $stopwatch.pomodoroSettings.roundsBeforeLongBreak, in: 2...8) {
            LabeledContent("Uzun fasiləyə qədər", value: "\(stopwatch.pomodoroSettings.roundsBeforeLongBreak) raund")
        }
        .appRow()
    }
}
