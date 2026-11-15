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
    /// List mode: question to scroll to (from the question grid).
    @State private var jump: Int?

    private var scale: CGFloat { CGFloat(store.fontScale) }

    var body: some View {
        if let sim = session.simulation {
            // Exam simulation: own screen (no feedback, changeable answers, countdown).
            SimulationQuizView(session: session, sim: sim)
        } else {
            standardBody
        }
    }

    private var standardBody: some View {
        NavigationStack {
            Group {
                if session.needsModeChoice { QuizModeChoice(session: session) }
                else if session.listMode { listContent } else { singleContent }
            }
            .safeAreaInset(edge: .top, spacing: 0) { if !session.needsModeChoice { progressStrip } }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if session.needsModeChoice { EmptyView() }
                else if session.listMode { listFooter } else { footer }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(session.title)
            .navigationSubtitle(session.courseLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu { titleMenu }
            .toolbar { toolbarContent }
        }
        .modifier(QuizChrome(session: session, finishPrompt: $finishPrompt, confirmReset: $confirmReset))
        .onDisappear { speech.stop() }
    }

    /// One question at a time.
    private var singleContent: some View {
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
    }

    /// "Siyahı rejimi": every question on one page; answer while scrolling.
    private var listContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if session.pagerOpen { pager }
                    ForEach(session.items) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            questionCard(item)
                            options(item)
                            if session.answers[item.id] == nil && !session.revealAtEnd {
                                Button("Bilmirəm") { withAnimation(.snappy) { session.dontKnow(at: item.id) } }
                                    .font(.subheadline.weight(.semibold))
                                    .tint(Theme.warning)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .padding(.bottom, 12)
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.visible)
            // The question at the top is the "current" one: star, İpucu and Səsləndir act on it.
            .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.4) { ids in
                if let first = ids.min(), first != session.index { session.index = first }
            }
            .onChange(of: jump) { _, j in
                guard let j else { return }
                withAnimation(.snappy) { proxy.scrollTo(j, anchor: .top) }
                jump = nil
            }
            .onAppear {
                let i = session.index
                if i > 0 { DispatchQueue.main.async { proxy.scrollTo(i, anchor: .top) } }
            }
        }
    }

    /// List mode bottom bar: answered count and Bitir.
    private var listFooter: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cavablandırılıb").font(.caption).foregroundStyle(Theme.textMuted)
                Text("\(session.answeredCount) / \(session.total)")
                    .font(.headline).monospacedDigit().foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 8)
            Button { finishFromList() } label: {
                Label("Bitir", systemImage: "flag.checkered").frame(minWidth: 110, minHeight: Self.barButtonHeight)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .largeControl()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        // Solid bar: the scrolling questions pass under it, not through it.
        .background {
            Theme.bg.ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Divider() }
        }
        .animation(.snappy, value: session.answeredCount)
    }

    private func finishFromList() {
        if case .needsConfirmation(let m) = session.requestFinish() { finishPrompt = m }
    }
}

/// Sheets, alerts and haptics shared by both layouts of the quiz.
private struct QuizChrome: ViewModifier {
    @Bindable var session: QuizSession
    @Binding var finishPrompt: String?
    @Binding var confirmReset: Bool
    @Environment(SurpriseEngine.self) private var surprise

    func body(content: Content) -> some View {
        content
        .sheet(item: Binding(get: { session.result.map(ResultBox.init) }, set: { _ in })) { box in
            ResultView(session: session, result: box.result)
                .interactiveDismissDisabled()
                .appEnvironment()
        }
        .sheet(isPresented: Binding(get: { surprise.isPresented }, set: { if !$0 { surprise.dismiss() } })) {
            SurpriseView()
                .appEnvironment()
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
        .appHaptic(.selection, trigger: session.picks)
        .appHaptic(trigger: session.answers.count) { _, _ in
            guard session.result == nil, let i = session.lastAnswered, let a = session.answers[i],
                  let q = session.items[studySafe: i]?.question, !a.hint else { return nil }
            return a.chosen == q.a ? .success : .error
        }
    }
}

extension QuizView {

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
            .appHaptic(.selection, trigger: session.isCurrentBookmarked)
            Menu {
                Button { speak() } label: { Label(speech.isSpeaking ? "Dayandır" : "Səsləndir", systemImage: "speaker.wave.2") }
                Toggle(isOn: Binding(get: { session.listMode }, set: { v in withAnimation(.snappy) { session.listMode = v } })) {
                    Label("Siyahı rejimi", systemImage: "list.bullet.rectangle")
                }
                if !session.listMode {
                    Toggle(isOn: Binding(get: { session.isFlashcard }, set: { _ in session.toggleFlashcard() })) {
                        Label("Flashcard rejimi", systemImage: "rectangle.on.rectangle")
                    }
                }
                if !session.revealAtEnd {
                    Button { session.hint() } label: { Label("İpucu", systemImage: "lightbulb") }.disabled(session.currentAnswer != nil)
                }
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
                    Text(session.listMode ? "\(session.answeredCount) / \(session.total)" : session.counterText).font(.footnote.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.textValue)
                    if session.showsTimer {
                        Label(session.timerText, systemImage: "timer").font(.footnote.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(Theme.text)
                    }
                    if session.isGradedExam && !session.isMockMode && !session.revealAtEnd {
                        // Points so far (100 max, 4 wrong cancel 1 correct).
                        Label("\(ResultView.points(session.liveScore)) bal", systemImage: "star.fill")
                            .font(.footnote.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(Theme.accent)
                            .contentTransition(.numericText())
                            .accessibilityLabel("Bal: \(ResultView.points(session.liveScore))")
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
                Button {
                    if session.listMode { jump = i } else { session.go(to: i) }
                    session.pagerOpen = false
                } label: {
                    Text("\(i + 1)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(segs[i] == .none ? (i == session.index ? Theme.onInverse : Theme.text) : Theme.onInverse)
                        .overlay {
                            if segs[i] != .none && i == session.index {
                                RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.text, lineWidth: 2)
                            }
                        }
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
        case .selected: Theme.accent
        case .none: current ? Theme.inverse : Theme.surfaceInner
        }
    }

    // MARK: Question

    private func questionCard(_ item: QuizSession.Item) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s12) {
            HStack(spacing: 6) {
                if let m = session.metaIfShown(item.question) {
                    Text(m.course).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.hex(m.accentHex))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hex(m.accentHex).opacity(0.35)))
                    if let u = m.unit {
                        Text(u).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.surfaceInner, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                if session.isRequeued(item) {
                    Label("Təkrar", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                }
                if let n = session.hardBadgeCount(for: item.question) {
                    let c = n >= 3 ? Theme.danger : Theme.warning
                    Text("\(n) dəfə səhv").font(.system(size: 11, weight: .semibold)).foregroundStyle(c)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c))
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(item.id + 1).").font(.system(size: 19 * scale, weight: .semibold)).foregroundStyle(Theme.textMuted)
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
                Text("Toxun və Gör").font(.system(size: 17 * scale, weight: .semibold)).foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40)
            .background(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 2, dash: [6])))
        }
        .buttonStyle(.plain)
    }

    private enum OptState { case normal, correct, wrong, dim, picked }

    private func options(_ item: QuizSession.Item) -> some View {
        let ans = session.answers[item.id]
        let picked = session.picks[item.id]
        return VStack(spacing: 10) {
            ForEach(Array(item.options.enumerated()), id: \.offset) { pos, opt in
                let st: OptState = {
                    guard let a = ans else { return picked == opt.originalIndex ? .picked : .normal }
                    if opt.originalIndex == item.question.a { return .correct }
                    if opt.originalIndex == a.chosen { return .wrong }
                    return .dim
                }()
                Button {
                    if session.revealAtEnd {
                        let first = picked == nil
                        withAnimation(.snappy(duration: 0.2)) { session.pick(opt.originalIndex, at: item.id) }
                        // One question at a time: a first pick moves on by itself (a change stays).
                        if first && !session.listMode && item.id == session.index && !session.isLast {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(350))
                                if session.index == item.id { withAnimation(.snappy) { session.nav(1) } }
                            }
                        }
                    } else {
                        withAnimation(.snappy(duration: 0.25)) { _ = session.choose(opt.originalIndex, at: item.id) }
                    }
                } label: { optionRow(QuizSession.letters[pos], opt.text, st) }
                .buttonStyle(PressStyle())
                .disabled(ans != nil)
            }
        }
        .id("opts-\(item.id)")
    }

    private func optionRow(_ letter: String, _ html: String, _ st: OptState) -> some View {
        let stroke: Color = st == .correct ? Theme.success : st == .wrong ? Theme.danger : st == .picked ? Theme.accent : Theme.border
        let badgeBg: Color = st == .correct ? Theme.success : st == .wrong ? Theme.danger : st == .picked ? Theme.accent : Theme.surfaceInner
        let fg: Color = st == .dim ? Theme.textMuted : Theme.text
        return HStack(spacing: 12) {
            Text(letter).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(st == .correct || st == .wrong || st == .picked ? Theme.onInverse : fg)
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
        .background(st == .dim ? Theme.bg : (st == .picked ? Theme.accent.opacity(0.1) : Theme.surface),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(stroke, lineWidth: st == .correct || st == .wrong || st == .picked ? 1.5 : 1))
        .contentShape(Rectangle())
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        let ans = session.currentAnswer
        let q = session.current?.question
        let isHint = ans?.hint == true
        let isDontKnow = ans?.chosen == QuizSession.dontKnowChoice
        let isRight = ans != nil && !isHint && ans?.chosen == q?.a
        let tint: Color = isHint ? Theme.warning : (isRight ? Theme.success : Theme.danger)
        VStack(spacing: 12) {
            if ans != nil, let title = session.feedbackTitle {
                HStack(spacing: 10) {
                    Image(systemName: isHint ? "lightbulb.fill" : (isRight ? "checkmark.circle.fill" : (isDontKnow ? "questionmark.circle.fill" : "xmark.circle.fill")))
                        .font(.title2).foregroundStyle(tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline).foregroundStyle(tint)
                        if !isRight, let line = session.correctLine {
                            Text("Düzgün cavab: " + RichText.plain(line)).font(.system(size: 13 * scale)).foregroundStyle(Theme.textCaption).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                Button { withAnimation(.snappy) { session.previous() } } label: {
                    Label("Geri", systemImage: "chevron.left").frame(maxWidth: 90, minHeight: Self.barButtonHeight)
                }
                .buttonStyle(.glass)
                .disabled(session.index == 0)
                if session.revealAtEnd {
                    // Cavablar sonda: no "Bilmirəm" (a blank stays blank), only move on / finish.
                    Button { next() } label: { Text(session.nextButtonTitle).frame(maxWidth: .infinity, minHeight: Self.barButtonHeight) }
                        .buttonStyle(.glassProminent)
                } else if ans == nil {
                    // "Bilmirəm": show the answer, count it as wrong (no lucky guesses).
                    Button { withAnimation(.snappy) { session.dontKnow() } } label: {
                        Text("Bilmirəm").frame(maxWidth: .infinity, minHeight: Self.barButtonHeight)
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.warning)
                    Button { next() } label: { Text(session.nextButtonTitle).frame(maxWidth: .infinity, minHeight: Self.barButtonHeight) }
                        .buttonStyle(.glass)
                } else {
                    Button { next() } label: { Text(session.nextButtonTitle).frame(maxWidth: .infinity, minHeight: Self.barButtonHeight) }
                        .buttonStyle(.glassProminent)
                }
            }
            .largeControl()
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

extension QuizView {
    /// Bottom bar buttons: the Mac's "large" control is much thinner than the iPhone's, so give it height.
    #if targetEnvironment(macCatalyst)
    static let barButtonHeight: CGFloat = 40
    #else
    static let barButtonHeight: CGFloat = 0
    #endif
}


/// Start of a test with 20+ questions: see each answer right away, or only at the end (like an exam).
private struct QuizModeChoice: View {
    let session: QuizSession
    @State private var lastWasEnd = UserDefaults.standard.bool(forKey: QuizSession.revealAtEndKey)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(session.total) sual").font(.largeTitle.weight(.bold)).monospacedDigit().foregroundStyle(Theme.text)
                    Text("Cavabları nə vaxt görmək istəyirsən?").font(.title3).foregroundStyle(Theme.textMuted)
                }
                .padding(.bottom, Theme.Space.s8)
                option(end: false, symbol: "checkmark.bubble.fill", tint: Theme.success,
                       title: "Hər sualdan sonra",
                       text: "Variantı seçən kimi düz və ya səhv olduğunu, düzgün cavabı görürsən. Öyrənmək üçün.")
                option(end: true, symbol: "flag.checkered", tint: Theme.accent,
                       title: "Testin sonunda",
                       text: "İmtahan kimi: variantları seçirsən, istəsən dəyişirsən. Düz və səhvlər yalnız Bitir-dən sonra görünür.")
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func option(end: Bool, symbol: String, tint: Color, title: String, text: String) -> some View {
        Button {
            withAnimation(.snappy) { session.chooseMode(revealAtEnd: end) }
        } label: {
            HStack(alignment: .top, spacing: Theme.Space.s12) {
                IconTile(symbol: symbol, color: tint, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title).font(.headline).foregroundStyle(Theme.text)
                        if end == lastWasEnd {
                            Text("Son seçim").font(.caption2.weight(.semibold)).foregroundStyle(tint)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(tint.opacity(0.14), in: Capsule())
                        }
                    }
                    Text(text).font(.subheadline).foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textCaption)
                    .padding(.top, 4)
            }
            .padding(Theme.Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}
