import SwiftUI

/// Result of an exam simulation: per-subject table (D / S / B / Net / Bal), average, time used and a review
/// of every question (Hamısı / Səhvlər / Boş).
struct SimulationResultView: View {
    let session: QuizSession
    let sim: ExamSimulation
    let result: SimulationResult
    @Environment(AppRouter.self) private var router
    @Environment(StudyStore.self) private var store
    @State private var filter: Filter = .all

    enum Filter: Hashable { case all, wrong, blank }

    private var filtered: [SimulationResult.ReviewItem] {
        switch filter {
        case .all: result.review
        case .wrong: result.review.filter { $0.status == .wrong }
        case .blank: result.review.filter { $0.status == .blank }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.s16) {
                    summaryCard
                    table
                    actions
                    reviewHeader
                    if filtered.isEmpty {
                        Text(filter == .wrong ? "Səhv cavab yoxdur." : "Boş sual yoxdur.")
                            .font(.subheadline).foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                    }
                    ForEach(filtered) { reviewCard($0) }
                }
                .padding(.horizontal, Theme.Space.s20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
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
        .sensoryFeedback(.success, trigger: result.average >= 50)
    }

    // MARK: Summary

    private var scoreColor: Color { result.average >= 50 ? Theme.success : Theme.danger }

    private var summaryCard: some View {
        VStack(spacing: 6) {
            if result.autoSubmitted {
                Label("Vaxt bitdi — imtahan avtomatik təhvil verildi", systemImage: "timer")
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.warning)
                    .padding(.bottom, 6)
            }
            Text("Ortalama bal").font(.subheadline).foregroundStyle(Theme.textMuted)
            Text(String(format: "%.1f", result.average))
                .font(.system(size: 56, weight: .bold)).foregroundStyle(scoreColor).monospacedDigit()
            Text("\(result.subjects.count) fənn · \(result.total) sual · 4 səhv 1 düzü aparır")
                .font(.footnote).foregroundStyle(Theme.textCaption).multilineTextAlignment(.center)
            HStack(spacing: 8) {
                StatTile(label: "Düz", value: "\(result.correct)", tone: Theme.success)
                StatTile(label: "Səhv", value: "\(result.wrong)", tone: Theme.danger)
                StatTile(label: "Boş", value: "\(result.blank)", tone: Theme.textMuted)
            }
            .padding(.top, 12)
            HStack(spacing: 8) {
                StatTile(label: "Net", value: String(format: "%.2f", result.net))
                StatTile(label: "Vaxt", value: "\(ExamSimulation.clock(result.elapsedSeconds)) / \(ExamSimulation.clock(result.allowedSeconds))")
            }
        }
        .padding(Theme.Space.s20)
        .frame(maxWidth: .infinity)
        .card(radius: 32)
    }

    // MARK: Table

    private var table: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fənlər üzrə").font(.sectionTitle).foregroundStyle(Theme.text)
            HStack(spacing: 4) {
                Text("Fənn").frame(maxWidth: .infinity, alignment: .leading)
                Text("D").frame(width: 26); Text("S").frame(width: 26); Text("B").frame(width: 26)
                Text("Net").frame(width: 44, alignment: .trailing); Text("Bal").frame(width: 44, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textMuted)
            ForEach(result.subjects) { s in
                row(ExamSimulation.shortName(s.subject), s.correct, s.wrong, s.blank, s.net, s.score, bold: false)
                Rectangle().fill(Theme.border).frame(height: 1)
            }
            if result.subjects.count > 1 {
                row("Ortalama", result.correct, result.wrong, result.blank, result.net, result.average, bold: true)
            }
        }
        .padding(Theme.Space.s20)
        .card(radius: 24)
    }

    private func row(_ name: String, _ c: Int, _ w: Int, _ b: Int, _ net: Double, _ score: Double, bold: Bool) -> some View {
        HStack(spacing: 4) {
            Text(name).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Theme.text)
            Text("\(c)").frame(width: 26).foregroundStyle(Theme.success)
            Text("\(w)").frame(width: 26).foregroundStyle(Theme.danger)
            Text("\(b)").frame(width: 26).foregroundStyle(Theme.textMuted)
            Text(String(format: "%.2f", net)).frame(width: 44, alignment: .trailing).foregroundStyle(Theme.textValue)
            Text(String(format: "%.1f", score)).frame(width: 44, alignment: .trailing).fontWeight(.bold).foregroundStyle(Theme.accent)
        }
        .font(.system(size: 14, weight: bold ? .semibold : .regular)).monospacedDigit()
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        let wrong = result.review.filter { $0.status == .wrong }.map(\.question)
        let blank = result.review.filter { $0.status == .blank }.map(\.question)
        if !wrong.isEmpty || !blank.isEmpty {
            VStack(spacing: 10) {
                if !wrong.isEmpty {
                    Button { repeatQuestions(wrong) } label: {
                        Label("Səhvləri təkrarla (\(wrong.count))", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                if !blank.isEmpty {
                    Button { repeatQuestions(wrong + blank) } label: {
                        Text(wrong.isEmpty ? "Boşları işlə (\(blank.count))" : "Səhv + boş (\(wrong.count + blank.count))").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
            .largeControl()
        }
    }

    // MARK: Review

    private var reviewHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cavablar").font(.sectionTitle).foregroundStyle(Theme.text)
            Picker("Filtr", selection: $filter) {
                Text("Hamısı (\(result.total))").tag(Filter.all)
                Text("Səhvlər (\(result.wrong))").tag(Filter.wrong)
                Text("Boş (\(result.blank))").tag(Filter.blank)
            }
            .pickerStyle(.segmented)
        }
        .padding(.top, 4)
    }

    private func reviewCard(_ r: SimulationResult.ReviewItem) -> some View {
        let (icon, tint): (String, Color) = switch r.status {
        case .correct: ("checkmark.circle.fill", Theme.success)
        case .wrong: ("xmark.circle.fill", Theme.danger)
        case .blank: ("minus.circle.fill", Theme.textMuted)
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text("\(ExamSimulation.shortName(r.subject)) · \(r.number)")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textMuted)
                Spacer(minLength: 4)
                if r.flagged { Image(systemName: "flag.fill").font(.caption).foregroundStyle(Theme.warning) }
            }
            RichTextView(r.question.q, font: .system(size: 15, weight: .medium)).foregroundStyle(Theme.text)
            answerLine("Sizin cavab", r.chosenLine, tint: r.status == .correct ? Theme.success : Theme.danger)
            if r.status != .correct {
                answerLine("Düzgün cavab", r.correctLine, tint: Theme.success)
            }
        }
        .padding(Theme.Space.s16)
        .card()
    }

    private func answerLine(_ label: String, _ html: String?, tint: Color) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.textMuted)
            Spacer(minLength: 12)
            if let html {
                RichTextView(html, font: .system(size: 13, weight: .semibold)).foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Boş").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textMuted)
            }
        }
    }

    // MARK: Navigation

    private func repeatQuestions(_ qs: [Question]) {
        session.close()
        let course = result.subjects.count == 1 ? result.subjects[0].subject : ""
        do { router.quiz = try QuizSession(.reviewMissed(questions: qs, course: course), store: store) }
        catch { router.alert = error.localizedDescription }
    }

    private func close() {
        sim.stop()
        session.close()
        router.quiz = nil
    }
}
