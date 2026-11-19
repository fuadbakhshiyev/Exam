import SwiftUI

/// Fənn → Sualları çeşidlə: every question of the subject, one at a time, with its answer;
/// the user marks each one Asan or Çətin and moves on. The hard ones become "Çətinləri öyrən".
/// Keyboard: 1 = Asan, 2 = Çətin, ← back, → skip, Space shows the answer.
struct SortQuestionsView: View {
    let subject: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    enum Filter: Hashable { case unmarked, hard, easy, all }

    @State private var filter: Filter = .unmarked
    /// The filtered list as it was when the filter was chosen (marking doesn't reshuffle it under the user).
    @State private var list: [Question] = []
    @State private var pos = 0
    @State private var loaded = false
    @State private var revealed = false
    /// Horizontal finger travel while swiping between questions.
    @State private var drag: CGFloat = 0
    @AppStorage("sort_show_answer") private var showAnswer = true

    private var difficulty: DifficultyStore { .shared }
    private var scale: CGFloat { CGFloat(store.fontScale) }
    private var current: Question? { list.indices.contains(pos) ? list[pos] : nil }

    var body: some View {
        let all = store.sortableQuestions(subject)
        let c = difficulty.counts(all)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let q = current {
                    card(q)
                        .offset(x: drag)
                        .opacity(1 - min(abs(drag) / 600, 0.4))
                } else {
                    done(hard: c.hard)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        // Swipe left = next question, right = previous (no arrow buttons).
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { v in
                    guard abs(v.translation.width) > abs(v.translation.height) * 1.5, current != nil else { return }
                    let w = v.translation.width
                    drag = (w > 0 && pos == 0) ? w / 4 : w   // resists at the first question
                }
                .onEnded { v in
                    let w = v.translation.width, predicted = v.predictedEndTranslation.width
                    let horizontal = abs(w) > abs(v.translation.height) * 1.5
                    if horizontal && (w < -80 || predicted < -200) && current != nil { skip() }
                    else if horizontal && (w > 80 || predicted > 200) && pos > 0 { back() }
                    withAnimation(.snappy) { drag = 0 }
                })
        .safeAreaInset(edge: .top, spacing: 0) { header(total: all.count, easy: c.easy, hard: c.hard) }
        .safeAreaInset(edge: .bottom, spacing: 0) { if current != nil { footer } }
        .background(Theme.bg.ignoresSafeArea())
        .pageTitle("Sualları çeşidlə", subtitle: subject)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAnswer.toggle(); revealed = false } label: {
                    Image(systemName: showAnswer ? "eye" : "eye.slash")
                }
                .accessibilityLabel(showAnswer ? "Cavabı gizlət" : "Cavabı göstər")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Çətinləri öyrən", systemImage: "flame.fill") { router.start(.hardQuestions(subject)) }
                    .disabled(c.hard == 0)
            }
        }
        .background { keys }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let unmarked = all.filter { difficulty.level($0) == .none }
            if unmarked.isEmpty && c.hard > 0 { filter = .hard }
            reload()
        }
        .onChange(of: filter) { _, _ in reload() }
    }

    private func reload() {
        let all = store.sortableQuestions(subject)
        list = switch filter {
        case .unmarked: all.filter { difficulty.level($0) == .none }
        case .hard: all.filter { difficulty.level($0) == .hard }
        case .easy: all.filter { difficulty.level($0) == .easy }
        case .all: all
        }
        pos = 0
        revealed = false
    }

    // MARK: Header

    private func header(total: Int, easy: Int, hard: Int) -> some View {
        let marked = easy + hard
        return VStack(alignment: .leading, spacing: 10) {
            Picker("Göstər", selection: $filter) {
                Text("Qeydsiz \(total - marked)").tag(Filter.unmarked)
                Text("Çətin \(hard)").tag(Filter.hard)
                Text("Asan \(easy)").tag(Filter.easy)
                Text("Hamısı").tag(Filter.all)
            }
            .pickerStyle(.segmented)
            HStack(spacing: 10) {
                ProgressLine(fraction: total > 0 ? Double(marked) / Double(total) : 0, height: 4)
                Text("\(marked) / \(total) qeyd olunub").font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Theme.textMuted)
                if !list.isEmpty {
                    Text("· \(min(pos + 1, list.count))/\(list.count)").font(.caption).monospacedDigit()
                        .foregroundStyle(Theme.textCaption)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
    }

    // MARK: Question

    private func card(_ q: Question) -> some View {
        let level = difficulty.level(q)
        let answerVisible = showAnswer || revealed
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    chip(q.u > 0 ? "Unit \(q.u)" : "Köhnə imtahan", color: Theme.text, filled: true)
                    if level != .none {
                        chip(level == .hard ? "Çətin" : "Asan", color: level == .hard ? Theme.danger : Theme.success, filled: false)
                    }
                    AnswerFixedBadge(question: q)
                    if MasteryStore.shared.isLearned(q) {
                        chip("Öyrənilib", color: Theme.success, filled: false)
                    }
                }
                RichTextView(q.q, font: .system(size: 19 * scale, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .card()
            VStack(spacing: 10) {
                ForEach(Array(q.o.enumerated()), id: \.offset) { i, o in
                    option(QuizSession.letters[i], o, correct: answerVisible && i == q.a)
                }
            }
            if !answerVisible {
                Button { withAnimation(.snappy) { revealed = true } } label: {
                    Label("Cavabı göstər", systemImage: "eye").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .largeControl()
            }
        }
        .id(pos)
        .transition(.opacity)
    }

    private func chip(_ text: String, color: Color, filled: Bool) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(filled ? Theme.surfaceInner : .clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay { if !filled { RoundedRectangle(cornerRadius: 6).strokeBorder(color.opacity(0.6)) } }
    }

    private func option(_ letter: String, _ html: String, correct: Bool) -> some View {
        HStack(spacing: 12) {
            Text(letter).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(correct ? Theme.onInverse : Theme.text)
                .frame(width: 28, height: 28)
                .background(correct ? Theme.success : Theme.surfaceInner, in: RoundedRectangle(cornerRadius: 9))
            RichTextView(html, font: .system(size: 15 * scale, weight: correct ? .semibold : .regular))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            if correct {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.success)
            }
        }
        .padding(14)
        .frame(minHeight: 52)
        .background(correct ? Theme.success.opacity(0.1) : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(correct ? Theme.success : Theme.border, lineWidth: correct ? 1.5 : 1))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button { mark(.easy) } label: {
                Label("Asan", systemImage: "hand.thumbsup.fill").lineLimit(1).fixedSize()
                    .frame(maxWidth: .infinity, minHeight: QuizView.barButtonHeight)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.success)
            Button { mark(.hard) } label: {
                Label("Çətin", systemImage: "flame.fill").lineLimit(1).fixedSize()
                    .frame(maxWidth: .infinity, minHeight: QuizView.barButtonHeight)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.danger)
        }
        .largeControl()
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(Theme.bg.opacity(0.001))
        .sensoryFeedback(.selection, trigger: pos)
    }

    private func mark(_ level: DifficultyStore.Level) {
        guard let q = current else { return }
        difficulty.set(level, for: q)
        skip()
    }

    private func skip() {
        guard current != nil else { return }
        withAnimation(.snappy) { pos += 1; revealed = false }
    }

    private func back() {
        guard pos > 0 else { return }
        withAnimation(.snappy) { pos -= 1; revealed = false }
    }

    // MARK: Done

    private func done(hard: Int) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label(list.isEmpty ? "Burada sual yoxdur" : "Siyahının sonu", systemImage: list.isEmpty ? "tray" : "checkmark.seal.fill")
            } description: {
                Text(filter == .unmarked && !list.isEmpty
                     ? "Bu siyahıdakı bütün sualları qeyd etdin. \(hard) sual çətin kimi qeyd olunub."
                     : "Yuxarıdan başqa siyahı seç.")
            }
            if hard > 0 {
                Button { router.start(.hardQuestions(subject)) } label: {
                    Label("Çətinləri öyrən · \(hard) sual", systemImage: "flame.fill").frame(maxWidth: .infinity, minHeight: QuizView.barButtonHeight)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.danger)
                .largeControl()
            }
            if !list.isEmpty {
                Button("Yenidən başla") { withAnimation(.snappy) { reload() } }
                    .buttonStyle(.glass)
            }
        }
        .padding(.top, 40)
    }

    // MARK: Keyboard

    private var keys: some View {
        ZStack {
            key("1") { mark(.easy) }
            key("2") { mark(.hard) }
            key(.leftArrow) { back() }
            key(.rightArrow) { skip() }
            key(.space) { withAnimation(.snappy) { revealed = true } }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func key(_ k: KeyEquivalent, _ action: @escaping () -> Void) -> some View {
        Button("", action: action).keyboardShortcut(k, modifiers: [])
    }
}
