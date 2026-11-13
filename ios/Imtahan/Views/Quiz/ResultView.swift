import SwiftUI

struct ResultView: View {
    let session: QuizSession
    let result: QuizSession.Result
    @Environment(AppRouter.self) private var router
    @State private var confetti = false

    var body: some View {
        NavigationStack {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.s16) {
                    if result.isMock { mockCard } else { scoreCard }
                    actions
                    if !result.missed.isEmpty {
                        HStack {
                            Text("Səhv cavablar").font(.sectionTitle).foregroundStyle(Theme.text)
                            Spacer()
                            Text("\(result.missed.count)").font(.sectionTitle).foregroundStyle(Theme.textMuted)
                        }
                        .padding(.top, 4)
                        ForEach(Array(result.missed.enumerated()), id: \.offset) { _, m in missedCard(m) }
                    }
                }
                .padding(.horizontal, Theme.Space.s20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            if confetti { ConfettiView().allowsHitTesting(false).ignoresSafeArea() }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Nəticə")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Bağla", systemImage: "checkmark") { close() }
            }
        }
        }
        .presentationBackground(Theme.bg)
                .onAppear { if result.confetti { confetti = true } }
        .sensoryFeedback(.success, trigger: confetti)
    }

    /// Exam-style sessions are graded in points (Bal): max 100, 4 wrong answers cancel 1 correct.
    private var isGraded: Bool { session.isGradedExam }

    private var scoreColor: Color {
        let v = isGraded ? result.score : Double(result.accuracy)
        return v >= 85 ? Theme.success : (v >= 50 ? Theme.warning : Theme.danger)
    }

    private var scoreCard: some View {
        VStack(spacing: 6) {
            Image(systemName: result.confetti ? "checkmark.seal.fill" : "flag.checkered")
                .font(.system(size: 40)).foregroundStyle(scoreColor).symbolEffect(.bounce, value: confetti)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if isGraded {
                    Text(Self.points(result.score)).font(.system(size: 56, weight: .bold)).foregroundStyle(scoreColor).monospacedDigit()
                    Text("/ 100 bal").font(.system(size: 20, weight: .medium)).foregroundStyle(Theme.textMuted)
                } else {
                    Text("\(result.correct)").font(.system(size: 56, weight: .bold)).foregroundStyle(scoreColor).monospacedDigit()
                    Text("/ \(result.total) düz").font(.system(size: 20, weight: .medium)).foregroundStyle(Theme.textMuted)
                }
            }
            Text("\(session.courseLabel) · \(session.title)").font(.system(size: 13)).foregroundStyle(Theme.textCaption)
                .multilineTextAlignment(.center)
            if isGraded {
                Text("\(result.correct) düz · \(result.wrong) səhv · \(max(0, result.total - result.correct - result.wrong)) boş — 4 səhv 1 düzü aparır")
                    .font(.footnote).monospacedDigit().foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 8) {
                if isGraded {
                    StatTile(label: "Düz", value: "\(result.correct)/\(result.total)")
                } else {
                    StatTile(label: "Dəqiqlik", value: "\(result.accuracy)%")
                }
                StatTile(label: "Vaxt", value: result.elapsed)
                StatTile(label: "Net", value: result.netText)
            }
            .padding(.top, 14)
        }
        .padding(Theme.Space.s20)
        .frame(maxWidth: .infinity)
        .card(radius: 32)
    }

    /// 85 → "85", 81.25 → "81.25", 82.5 → "82.5".
    static func points(_ v: Double) -> String {
        let r = (v * 100).rounded() / 100
        return r == r.rounded() ? String(Int(r)) : String(format: r * 10 == (r * 10).rounded() ? "%.1f" : "%.2f", r)
    }

    private var mockCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sınaq Nəticələri").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.accent)
            Text("Fənn üzrə ballar (Maks. 100):").font(.system(size: 13)).foregroundStyle(Theme.textMuted)
            HStack {
                Text("Fənn").frame(maxWidth: .infinity, alignment: .leading)
                Text("D").frame(width: 32); Text("Y").frame(width: 32); Text("Bal").frame(width: 48, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textMuted)
            ForEach(result.mockSubjects) { s in
                HStack {
                    Text(s.subject).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Theme.text)
                    Text("\(s.correct)").frame(width: 32).foregroundStyle(Theme.success)
                    Text("\(s.wrong)").frame(width: 32).foregroundStyle(Theme.danger)
                    Text(s.scoreText).frame(width: 48, alignment: .trailing).fontWeight(.bold).foregroundStyle(Theme.accent)
                }
                .font(.system(size: 14)).monospacedDigit()
                Rectangle().fill(Theme.border).frame(height: 1)
            }
        }
        .padding(Theme.Space.s20)
        .card(radius: 24)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if !result.missed.isEmpty {
                Button {
                    do { router.quiz = try session.reviewMissed() } catch { router.alert = error.localizedDescription }
                } label: {
                    Label("Səhvləri təkrarla (\(result.missed.count))", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .largeControl()
    }

    private func close() {
        session.close()
        router.quiz = nil
    }

    private func missedCard(_ m: QuizSession.MissedItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RichTextView(m.question.q, font: .system(size: 15, weight: .medium)).foregroundStyle(Theme.text)
            HStack(alignment: .top) {
                Text("Sizin cavab").font(.system(size: 13)).foregroundStyle(Theme.textMuted)
                Spacer(minLength: 12)
                if let c = m.chosenText { RichTextView(c, font: .system(size: 13, weight: .semibold)).foregroundStyle(Theme.danger).fixedSize(horizontal: false, vertical: true) }
                else { Text("—").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textMuted) }
            }
            HStack(alignment: .top) {
                Text("Düzgün cavab").font(.system(size: 13)).foregroundStyle(Theme.textMuted)
                Spacer(minLength: 12)
                RichTextView(m.correctText, font: .system(size: 13, weight: .semibold)).foregroundStyle(Theme.success).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Space.s16)
        .card()
    }
}

/// Lightweight confetti burst (fireConfetti).
struct ConfettiView: View {
    @State private var start = Date()
    private let pieces: [(x: Double, delay: Double, speed: Double, spin: Double, color: Color, w: Double)] = (0..<120).map { _ in
        (Double.random(in: 0...1), Double.random(in: 0...0.6), Double.random(in: 0.55...1.1), Double.random(in: -6...6),
         [Theme.accent, Theme.warning, Theme.success, Theme.danger, Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.93, green: 0.28, blue: 0.6)].randomElement()!,
         Double.random(in: 5...9))
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            Canvas { ctx, size in
                for p in pieces {
                    let tt = t - p.delay
                    guard tt > 0, tt < 3.2 else { continue }
                    let y = -20 + tt * p.speed * size.height * 0.6 + 0.5 * 300 * tt * tt * 0.25
                    let x = p.x * size.width + sin(tt * 3 + p.spin) * 18
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(tt * p.spin))
                    c.opacity = max(0, 1 - tt / 3.2)
                    c.fill(Path(CGRect(x: -p.w / 2, y: -p.w / 4, width: p.w, height: p.w / 2)), with: .color(p.color))
                }
            }
        }
    }
}
