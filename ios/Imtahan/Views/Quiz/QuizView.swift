import SwiftUI
import AVFoundation

struct QuizView: View {
    @Bindable var session: QuizSession
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(SurpriseEngine.self) private var surprise
    @Environment(SidebarStopwatch.self) private var stopwatch
    @State private var finishPrompt: String?
    @State private var confirmReset = false
    @State private var speech = Speech()

    private var scale: CGFloat { CGFloat(store.fontScale) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if session.pagerOpen { pager }
                        if let item = session.current {
                            questionCard(item)
                            if session.optionsHidden { flashcardCover } else { options(item) }
                        } else {
                            ContentUnavailableView("Sual tapılmadı", systemImage: "questionmark.circle")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .id("top")
                }
                .scrollIndicators(.hidden)
                .onChange(of: session.index) { _, _ in withAnimation(.snappy) { proxy.scrollTo("top", anchor: .top) } }
            }
            .safeAreaInset(edge: .top, spacing: 0) { progressStrip }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(session.title)
            .navigationSubtitle(session.courseLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu { titleMenu }
            .toolbar { toolbarContent }
        }
        .sheet(item: Binding(get: { session.result.map(ResultBox.init) }, set: { _ in })) { box in
            ResultView(session: session, result: box.result)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: Binding(get: { surprise.isPresented }, set: { if !$0 { surprise.dismiss() } })) {
            SurpriseView()
        }
        .alert("Sınaq yarımçıqdır", isPresented: Binding(get: { finishPrompt != nil || session.pendingFinishConfirmation != nil },
                                                        set: { if !$0 { finishPrompt = nil; session.pendingFinishConfirmation = nil } })) {
            Button("Bitir", role: .destructive) { finishPrompt = nil; session.finish() }
            Button("Davam et", role: .cancel) { finishPrompt = nil; session.pendingFinishConfirmation = nil }
        } message: {
            Text(finishPrompt ?? session.pendingFinishConfirmation ?? "")
        }
        .confirmationDialog("Testi sıfırla?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Sıfırla", role: .destructive) { session.reset() }
        }
        .celebrationOverlay()
        .onDisappear { speech.stop() }
        .sensoryFeedback(trigger: session.answers.count) { _, _ in
            guard let a = session.currentAnswer, let q = session.current?.question, !a.hint else { return nil }
            return a.chosen == q.a ? .success : .error
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button { close() } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Bağla")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { session.toggleBookmark() } label: {
                Image(systemName: session.isCurrentBookmarked ? "star.fill" : "star")
            }
            .tint(session.isCurrentBookmarked ? Theme.warning : nil)
            .accessibilityLabel("İşarələ")
            .sensoryFeedback(.selection, trigger: session.isCurrentBookmarked)
            Menu {
                Button { speak() } label: { Label(speech.isSpeaking ? "Dayandır" : "Səsləndir", systemImage: "speaker.wave.2") }
                Toggle(isOn: Binding(get: { session.isFlashcard }, set: { _ in session.toggleFlashcard() })) {
                    Label("Flashcard rejimi", systemImage: "rectangle.on.rectangle")
                }
                Button { session.hint() } label: { Label("İpucu", systemImage: "lightbulb") }.disabled(session.currentAnswer != nil)
                Divider()
                Button(role: .destructive) { confirmReset = true } label: { Label("Testi sıfırla", systemImage: "arrow.counterclockwise") }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("Əlavə")
        }
    }

    /// Title menu: switch unit (unit sessions) or jump to a subject (mock).
    @ViewBuilder
    private var titleMenu: some View {
        if !session.unitPillLabels.isEmpty {
            Picker("Bölmə", selection: Binding(get: { session.selectionIndex }, set: { session.loadUnit($0) })) {
                ForEach(Array(session.unitPillLabels.enumerated()), id: \.offset) { i, l in Text(l).tag(i) }
            }
        }
        if !session.mockSubjects.isEmpty {
            ForEach(session.mockSubjects, id: \.self) { s in
                Button(s) { session.jumpToSubject(s) }
            }
        }
    }

    /// Native progress bar + counter + timer under the navigation bar; tap opens the question grid.
    private var progressStrip: some View {
        HStack(spacing: 10) {
            Button { withAnimation(.snappy) { session.pagerOpen.toggle() } } label: {
                HStack(spacing: 12) {
                    ProgressView(value: session.progress).tint(Theme.accent)
                    Text(session.counterText).font(.footnote.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.textValue)
                    if session.showsTimer {
                        Label(session.timerText, systemImage: "timer").font(.footnote.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(Theme.text)
                    }
                    Image(systemName: session.pagerOpen ? "chevron.up" : "square.grid.3x3").font(.footnote).foregroundStyle(Theme.textMuted)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sualların siyahısı, \(session.counterText)")
            // Free stopwatch (Profil → Xronometr): visible only while running / paused with time.
            QuizStopwatchCapsule()
        }
        .padding(.horizontal, 20)
        .animation(.snappy, value: stopwatch.isActive)
        .background(Theme.bg)
    }

    // MARK: Pager / pills

    private var pager: some View {
        let segs = session.segments
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(segs.indices, id: \.self) { i in
                Button { session.go(to: i); session.pagerOpen = false } label: {
                    Text("\(i + 1)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(segs[i] == .none ? (i == session.index ? Theme.onInverse : Theme.text) : Theme.onInverse)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(segColor(segs[i], current: i == session.index), in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Space.s12)
        .card()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func segColor(_ s: QuizSession.SegmentState, current: Bool) -> Color {
        switch s {
        case .done: Theme.success
        case .wrong: Theme.danger
        case .none: current ? Theme.inverse : Theme.surfaceInner
        }
    }

    // MARK: Question

    private func questionCard(_ item: QuizSession.Item) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s12) {
            HStack(spacing: 6) {
                if let m = session.currentMeta {
                    Text(m.course).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.hex(m.accentHex))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hex(m.accentHex).opacity(0.35)))
                    if let u = m.unit {
                        Text(u).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.surfaceInner, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                if let n = session.hardBadgeCount {
                    let c = n >= 3 ? Theme.danger : Theme.warning
                    Text("\(n) dəfə səhv").font(.system(size: 11, weight: .semibold)).foregroundStyle(c)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c))
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(session.index + 1).").font(.system(size: 19 * scale, weight: .semibold)).foregroundStyle(Theme.textMuted)
                RichTextView(item.question.q, font: .system(size: 19 * scale, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .card()
        .id(item.id)
        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 24)), removal: .opacity))
    }

    private var flashcardCover: some View {
        Button { withAnimation(.snappy) { session.revealFlashcard() } } label: {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.angled").font(.system(size: 28)).foregroundStyle(Theme.accent)
                Text("Toxun və Gör").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40)
            .background(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 2, dash: [6])))
        }
        .buttonStyle(.plain)
    }

    private enum OptState { case normal, correct, wrong, dim }

    private func options(_ item: QuizSession.Item) -> some View {
        let ans = session.currentAnswer
        return VStack(spacing: 10) {
            ForEach(Array(item.options.enumerated()), id: \.offset) { pos, opt in
                let st: OptState = {
                    guard let a = ans else { return .normal }
                    if opt.originalIndex == item.question.a { return .correct }
                    if opt.originalIndex == a.chosen { return .wrong }
                    return .dim
                }()
                Button {
                    withAnimation(.snappy(duration: 0.25)) { _ = session.chooseDisplayed(pos) }
                } label: { optionRow(QuizSession.letters[pos], opt.text, st) }
                .buttonStyle(PressStyle())
                .disabled(ans != nil)
            }
        }
        .id("opts-\(item.id)")
    }

    private func optionRow(_ letter: String, _ html: String, _ st: OptState) -> some View {
        let stroke: Color = st == .correct ? Theme.success : st == .wrong ? Theme.danger : Theme.border
        let badgeBg: Color = st == .correct ? Theme.success : st == .wrong ? Theme.danger : Theme.surfaceInner
        let fg: Color = st == .dim ? Theme.textMuted : Theme.text
        return HStack(spacing: 12) {
            Text(letter).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(st == .correct || st == .wrong ? Theme.onInverse : fg)
                .frame(width: 28, height: 28)
                .background(badgeBg, in: RoundedRectangle(cornerRadius: 9))
            RichTextView(html, font: .system(size: 15 * scale))
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            if st == .correct || st == .wrong {
                Image(systemName: st == .correct ? "checkmark" : "xmark").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(st == .correct ? Theme.success : Theme.danger)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(14)
        .frame(minHeight: 56)
        .background(st == .dim ? Theme.bg : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(stroke, lineWidth: st == .correct || st == .wrong ? 1.5 : 1))
        .contentShape(Rectangle())
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        let ans = session.currentAnswer
        let q = session.current?.question
        let isHint = ans?.hint == true
        let isRight = ans != nil && !isHint && ans?.chosen == q?.a
        let tint: Color = isHint ? Theme.warning : (isRight ? Theme.success : Theme.danger)
        VStack(spacing: 12) {
            if ans != nil, let title = session.feedbackTitle {
                HStack(spacing: 10) {
                    Image(systemName: isHint ? "lightbulb.fill" : (isRight ? "checkmark.circle.fill" : "xmark.circle.fill"))
                        .font(.title2).foregroundStyle(tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline).foregroundStyle(tint)
                        if !isRight, let line = session.correctLine {
                            Text("Düzgün cavab: " + RichText.plain(line)).font(.footnote).foregroundStyle(Theme.textCaption).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                Button { withAnimation(.snappy) { session.previous() } } label: {
                    Label("Geri", systemImage: "chevron.left").frame(maxWidth: 90)
                }
                .buttonStyle(.glass)
                .disabled(session.index == 0)
                if ans == nil {
                    Button { next() } label: { Text(session.nextButtonTitle).frame(maxWidth: .infinity) }
                        .buttonStyle(.glass)
                } else {
                    Button { next() } label: { Text(session.nextButtonTitle).frame(maxWidth: .infinity) }
                        .buttonStyle(.glassProminent)
                }
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Theme.bg.opacity(0.001))
        .animation(.snappy(duration: 0.25), value: ans)
    }

    private func next() {
        withAnimation(.snappy) {
            if let req = session.next(), case .needsConfirmation(let m) = req { finishPrompt = m }
        }
    }

    private func close() {
        speech.stop()
        session.close()
        router.quiz = nil
    }

    private func speak() {
        if speech.isSpeaking { speech.stop(); return }
        if let t = session.speechText { speech.speak(t) }
    }
}

private struct ResultBox: Identifiable {
    let result: QuizSession.Result
    var id: Int { result.hashValue }
}

/// Text-to-speech (tr-TR), like speakQuestion.
@MainActor
@Observable
final class Speech: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    var isSpeaking = false

    override init() { super.init(); synth.delegate = self }

    func speak(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "tr-TR")
        synth.speak(u)
        isSpeaking = true
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
