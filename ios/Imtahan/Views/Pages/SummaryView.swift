import SwiftUI

/// Fənn → Xülasə: the subject's study sheet, one card per unit, each with a button to test that unit.
struct SummaryView: View {
    let subject: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    private var scale: CGFloat { CGFloat(store.fontScale) }

    var body: some View {
        ScrollView {
            if let s = SubjectSummaries.summary(for: subject) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let intro = s.intro {
                        card {
                            blockView(intro, headingColor: Theme.accent)
                        }
                    }
                    ForEach(s.units) { u in unitCard(u) }
                    if !s.quick.isEmpty {
                        card {
                            Label("İmtahandan əvvəl", systemImage: "bolt.fill")
                                .font(.headline).foregroundStyle(Theme.warning)
                            ForEach(s.quick, id: \.self) { bullet($0) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView("Xülasə yoxdur", systemImage: "doc.text")
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .pageTitle("Xülasə", subtitle: subject)
    }

    private func unitCard(_ u: SubjectSummary.Unit) -> some View {
        card {
            HStack(spacing: 10) {
                Text("\(u.number)").font(.system(size: 15, weight: .bold)).monospacedDigit()
                    .foregroundStyle(Theme.onInverse)
                    .frame(width: 28, height: 28)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                Text(u.title).font(.system(size: 19 * scale, weight: .bold)).foregroundStyle(Theme.text)
                Spacer(minLength: 0)
            }
            ForEach(Array(u.blocks.enumerated()), id: \.offset) { _, b in blockView(b, headingColor: Theme.textMuted) }
            if !u.traps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Tələ suallar", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.danger)
                    ForEach(u.traps, id: \.self) { bullet($0) }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button { router.start(.unit(course: subject, index: u.number - 1)) } label: {
                Label("Unit \(u.number) testini başla", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    @ViewBuilder private func blockView(_ b: SubjectSummary.Block, headingColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let h = b.heading {
                Text(h).font(.subheadline.weight(.semibold)).foregroundStyle(headingColor)
            }
            ForEach(b.points, id: \.self) { bullet($0) }
        }
    }

    private func bullet(_ md: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(Theme.textCaption)
            Text(.init(md)).foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 15 * scale))
        .textSelection(.enabled)
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
    }
}
