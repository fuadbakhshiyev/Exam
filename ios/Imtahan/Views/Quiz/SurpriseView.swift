import SwiftUI

/// Sürpriz Sual: every 3 minutes, 30 seconds to answer; first tap selects, second tap confirms.
struct SurpriseView: View {
    @Environment(SurpriseEngine.self) private var engine

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let q = engine.question {
                        Text(engine.metaText.uppercased()).font(.caption.weight(.bold)).foregroundStyle(Theme.textMuted)
                        RichTextView(q.q, font: .system(size: 17, weight: .semibold)).foregroundStyle(Theme.text)
                        VStack(spacing: 10) {
                            ForEach(Array(q.o.enumerated()), id: \.offset) { i, o in
                                Button { withAnimation(.snappy) { engine.tap(i) } } label: { row(i, o, q) }
                                    .buttonStyle(PressStyle())
                                    .disabled(engine.isAnswered)
                            }
                        }
                        if !engine.isAnswered {
                            Text(engine.selected == nil ? "Cavabı seçin" : "Təsdiq üçün bir də toxunun")
                                .font(.caption).foregroundStyle(Theme.textMuted).frame(maxWidth: .infinity)
                        }
                        if let f = engine.feedback {
                            Label(f.text, systemImage: f.isPositive ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(f.isPositive ? Theme.success : Theme.danger)
                                .frame(maxWidth: .infinity).padding(12)
                                .glassEffect(.regular.tint((f.isPositive ? Theme.success : Theme.danger).opacity(0.15)), in: .rect(cornerRadius: 14))
                            Button { engine.close() } label: { Text("Davam Et").frame(maxWidth: .infinity, minHeight: QuizView.barButtonHeight) }
                                .buttonStyle(.glassProminent).largeControl()
                        }
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle("Sürpriz Sual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { engine.dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Bağla")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(engine.timeLeft)s").font(.headline).monospacedDigit().foregroundStyle(Theme.danger)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: engine.timeLeft)
                        .padding(.horizontal, 8)
                }
            }
        }
        .presentationDetents([.large])
        #if targetEnvironment(macCatalyst)
        // Mac sheets default to a small form size: make room for the question and all five options.
        .frame(minWidth: 560, idealWidth: 640, minHeight: 720, idealHeight: 780)
        .presentationSizing(.fitted)
        #endif
        .interactiveDismissDisabled(!engine.isAnswered)
        .sensoryFeedback(trigger: engine.feedback) { _, f in f.map { $0.isPositive ? .success : .error } }
    }

    private func row(_ i: Int, _ html: String, _ q: Question) -> some View {
        let answered = engine.isAnswered
        let isCorrect = answered && i == q.a
        let isWrong = answered && engine.chosen == i && i != q.a
        let isSel = !answered && engine.selected == i
        let stroke: Color = isCorrect ? Theme.success : isWrong ? Theme.danger : isSel ? Theme.accent : Theme.border
        return RichTextView(html, font: .system(size: 15))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isSel ? Theme.accent.opacity(0.08) : Theme.surfaceInner, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(stroke, lineWidth: isCorrect || isWrong || isSel ? 1.5 : 1))
    }
}

/// Milestone celebration (fireMotivationalCelebration), shown over whatever is on screen.
struct CelebrationOverlay: ViewModifier {
    @Environment(StudyStore.self) private var store
    func body(content: Content) -> some View {
        content.overlay {
            if let c = store.celebration {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ConfettiView().ignoresSafeArea().allowsHitTesting(false)
                    VStack(spacing: 12) {
                        Text(c.badge).font(.system(size: 54))
                        Text(c.title).font(.system(size: 13, weight: .bold)).tracking(2).foregroundStyle(Theme.accent)
                        Text(c.level.uppercased()).font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.text)
                        Text(c.milestoneText).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textCaption)
                        Text(c.quote).font(.system(size: 14)).italic().foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
                        Button { withAnimation { store.celebration = nil } } label: { Text("Davam et").frame(maxWidth: .infinity) }
                            .buttonStyle(.glassProminent).largeControl().padding(.top, 8)
                    }
                    .padding(28)
                    .card(radius: 32)
                    .padding(24)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                .sensoryFeedback(.success, trigger: c.milestone)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.3), value: store.celebration)
    }
}

extension View {
    func celebrationOverlay() -> some View { modifier(CelebrationOverlay()) }
}
