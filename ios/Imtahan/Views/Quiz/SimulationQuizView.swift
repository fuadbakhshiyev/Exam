import SwiftUI

/// "Real imtahan simulyasiyası" exam screen: no right/wrong feedback, answers can be changed or cleared
/// until "Bitir", questions can be flagged, a countdown in the toolbar hands the exam in when it runs out.
struct SimulationQuizView: View {
    @Bindable var session: QuizSession
    let sim: ExamSimulation
    @Environment(AppRouter.self) private var router
    @Environment(StudyStore.self) private var store
    @Environment(SurpriseEngine.self) private var surprise
    @State private var confirmFinish = false
    @State private var confirmExit = false

    private var scale: CGFloat { CGFloat(store.fontScale) }
    private var currentSubject: String { sim.itemSubjects[studySafe: session.index] ?? "" }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if session.pagerOpen { grid }
                        if let item = session.current {
                            questionCard(item)
                            options(item)
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
            .safeAreaInset(edge: .top, spacing: 0) { subjectStrip }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .background(Theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .sheet(item: Binding(get: { sim.result.map(SimulationResultBox.init) }, set: { _ in })) { box in
            SimulationResultView(session: session, sim: sim, result: box.result)
                .interactiveDismissDisabled()
                .appEnvironment()
        }
        .alert("İmtahan bitirilsin?", isPresented: $confirmFinish) {
            Button("Bitir", role: .destructive) { submit() }
            Button("Davam et", role: .cancel) {}
        } message: {
            Text(finishMessage)
        }
        .alert("İmtahandan çıxılsın?", isPresented: $confirmExit) {
            Button("Çıx", role: .destructive) { close() }
            Button("Davam et", role: .cancel) {}
        } message: {
            Text("Cavablar yadda saxlanmayacaq və nəticə hesablanmayacaq.")
        }
        .onAppear {
            // No surprise questions in the middle of an exam.
            surprise.stop()
            if surprise.isPresented { surprise.dismiss() }
        }
        .onDisappear {
            sim.stop()
            surprise.start()
        }
        .sensoryFeedback(.selection, trigger: sim.selections)
        .sensoryFeedback(.warning, trigger: sim.isLowTime) { _, low in low && sim.result == nil }
    }

    private var finishMessage: String {
        var parts: [String] = []
        if sim.unansweredCount > 0 { parts.append("\(sim.unansweredCount) sual cavabsızdır.") }
        if !sim.flagged.isEmpty { parts.append("\(sim.flagged.count) sual işarələnib.") }
        parts.append("Təhvil verdikdən sonra cavabları dəyişmək olmaz.")
        return parts.joined(separator: " ")
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button { confirmExit = true } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Çıx")
        }
        ToolbarItem(placement: .principal) {
            SimulationCountdown(sim: sim)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Bitir") { requestFinish() }
        }
    }

    // MARK: Subject strip

    private var subjectStrip: some View {
        VStack(spacing: 8) {
            if sim.subjects.count > 1 {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(sim.subjects, id: \.self) { s in
                                let active = s == currentSubject
                                Button {
                                    if let i = sim.indices(of: s).first { withAnimation(.snappy) { session.go(to: i) } }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(ExamSimulation.shortName(s)).lineLimit(1)
                                        Text("\(sim.answered(in: s))/\(sim.indices(of: s).count)")
                                            .monospacedDigit()
                                            .foregroundStyle(active ? Color.white.opacity(0.8) : Theme.textMuted)
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(active ? Color.white : Theme.text)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(active ? Theme.accent : Theme.surfaceInner, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .id(s)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: currentSubject) { _, s in withAnimation(.snappy) { proxy.scrollTo(s, anchor: .center) } }
                }
            }
            Button { withAnimation(.snappy) { session.pagerOpen.toggle() } } label: {
                HStack(spacing: 12) {
                    ProgressView(value: sim.items.isEmpty ? 0 : Double(sim.answeredCount) / Double(sim.items.count)).tint(Theme.accent)
                    Text("\(sim.answeredCount)/\(sim.items.count) cavab").font(.footnote.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Theme.textValue)
                    if !sim.flagged.isEmpty {
                        Label("\(sim.flagged.count)", systemImage: "flag.fill").font(.footnote.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(Theme.warning)
                    }
                    Image(systemName: session.pagerOpen ? "chevron.up" : "square.grid.3x3").font(.footnote).foregroundStyle(Theme.textMuted)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .accessibilityLabel("Sualların siyahısı, \(sim.answeredCount) cavab")
        }
        .padding(.top, 4)
        .background(Theme.bg)
    }

    // MARK: Grid

    private var grid: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(sim.subjects, id: \.self) { s in
                VStack(alignment: .leading, spacing: 8) {
                    if sim.subjects.count > 1 {
                        Text(s).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textMuted).lineLimit(1)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 10), spacing: 6) {
                        ForEach(sim.indices(of: s), id: \.self) { i in gridCell(i) }
                    }
                }
            }
            HStack(spacing: 14) {
                legend(Theme.accent, "Cavablı")
                legend(Theme.surfaceInner, "Boş")
                Label("İşarəli", systemImage: "flag.fill").foregroundStyle(Theme.warning)
            }
            .font(.caption)
            .foregroundStyle(Theme.textMuted)
        }
        .padding(Theme.Space.s12)
        .card()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.border))
            Text(t)
        }
    }

    private func gridCell(_ i: Int) -> some View {
        let answered = sim.selections[i] != nil
        let current = i == session.index
        return Button { session.go(to: i); withAnimation(.snappy) { session.pagerOpen = false } } label: {
            Text("\(sim.number(of: i))").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .foregroundStyle(answered ? Color.white : Theme.text)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(answered ? Theme.accent : Theme.surfaceInner, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(current ? Theme.inverse : .clear, lineWidth: 2))
                .overlay(alignment: .topTrailing) {
                    if sim.flagged.contains(i) {
                        Image(systemName: "flag.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.warning)
                            .padding(3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sual \(sim.number(of: i)), \(answered ? "cavablı" : "boş")\(sim.flagged.contains(i) ? ", işarəli" : "")")
    }

    // MARK: Question

    private func questionCard(_ item: QuizSession.Item) -> some View {
        let subj = currentSubject
        let accent = Theme.hex(Catalog.styles[subj]?.accent ?? "#8b5cf6")
        let total = sim.indices(of: subj).count
        return VStack(alignment: .leading, spacing: Theme.Space.s12) {
            HStack(spacing: 6) {
                Text(subj).font(.system(size: 11, weight: .bold)).foregroundStyle(accent).lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(accent.opacity(0.35)))
                Spacer(minLength: 4)
                Text("\(sim.number(of: session.index)) / \(total)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(Theme.textMuted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(sim.number(of: session.index)).").font(.system(size: 19 * scale, weight: .semibold)).foregroundStyle(Theme.textMuted)
                RichTextView(item.question.q, font: .system(size: 19 * scale, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .card()
        .id(item.id)
    }

    private func options(_ item: QuizSession.Item) -> some View {
        let chosen = sim.selections[session.index]
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(item.options.enumerated()), id: \.offset) { pos, opt in
                let selected = chosen == opt.originalIndex
                Button {
                    withAnimation(.snappy(duration: 0.2)) { sim.select(item: session.index, originalIndex: opt.originalIndex) }
                } label: { optionRow(QuizSession.letters[pos], opt.text, selected) }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            if chosen != nil {
                Text("Cavabı silmək üçün seçilmiş variantə yenidən toxunun.")
                    .font(.caption).foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 4)
            }
        }
        .id("opts-\(item.id)")
    }

    private func optionRow(_ letter: String, _ html: String, _ selected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(letter).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Theme.text)
                .frame(width: 28, height: 28)
                .background(selected ? Theme.accent : Theme.surfaceInner, in: RoundedRectangle(cornerRadius: 9))
            RichTextView(html, font: .system(size: 15 * scale, weight: selected ? .semibold : .regular))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(minHeight: 56)
        .background(selected ? Theme.accent.opacity(0.1) : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? Theme.accent : Theme.border, lineWidth: selected ? 1.5 : 1))
        .contentShape(Rectangle())
    }

    // MARK: Footer

    private var footer: some View {
        let flagged = sim.flagged.contains(session.index)
        return HStack(spacing: 10) {
            Button { withAnimation(.snappy) { session.previous() } } label: {
                Image(systemName: "chevron.left").frame(width: 28)
            }
            .buttonStyle(.glass)
            .disabled(session.index == 0)
            .accessibilityLabel("Əvvəlki")
            Button { sim.toggleFlag(session.index) } label: {
                Label(flagged ? "İşarəli" : "İşarələ", systemImage: flagged ? "flag.fill" : "flag")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .tint(flagged ? Theme.warning : nil)
            .sensoryFeedback(.selection, trigger: flagged)
            if session.isLast {
                Button { requestFinish() } label: { Text("Bitir").frame(maxWidth: .infinity) }
                    .buttonStyle(.glassProminent)
            } else {
                Button { withAnimation(.snappy) { session.nav(1) } } label: {
                    Label("Növbəti", systemImage: "chevron.right").labelStyle(TrailingIconLabelStyle()).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Theme.bg.opacity(0.001))
    }

    // MARK: Actions

    private func requestFinish() {
        if sim.unansweredCount > 0 { confirmFinish = true } else { submit() }
    }

    private func submit() {
        sim.submit()
        session.close()   // stops the session timer; the result sheet stays until "Bağla"
    }

    private func close() {
        sim.stop()
        session.close()
        router.quiz = nil
    }
}

/// Countdown in the toolbar (its own view so only it redraws every second).
private struct SimulationCountdown: View {
    let sim: ExamSimulation

    var body: some View {
        let low = sim.isLowTime
        HStack(spacing: 5) {
            Image(systemName: "timer")
            Text(ExamSimulation.clock(sim.remainingSeconds)).monospacedDigit().contentTransition(.numericText(countsDown: true))
        }
        .font(.headline)
        .foregroundStyle(low ? Theme.warning : Theme.text)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(low ? Theme.warning.opacity(0.15) : Theme.surfaceInner, in: Capsule())
        .animation(.snappy, value: sim.remainingSeconds)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Qalan vaxt \(ExamSimulation.clock(sim.remainingSeconds))")
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.title; configuration.icon }
    }
}

private struct SimulationResultBox: Identifiable {
    let result: SimulationResult
    var id: Int { result.hashValue }
}
