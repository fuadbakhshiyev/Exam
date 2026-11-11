import SwiftUI

/// İmtahan dashboard (showPdfExamsDashboard). Also the root of the "İmtahan" tab (isRoot).
/// Health-style cards: simulation, the vize summary, subjects, Final booklets.
struct PdfDashboardView: View {
    var isRoot: Bool = false
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    init(isRoot: Bool = false) { self.isRoot = isRoot }

    var body: some View {
        let page = store.pdfDashboard()
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s12) {
                SimulationEntryCard()

                HomeSectionHeader(title: "Vize imtahanları")
                summaryCard(page)
                subjectsCard(page.rows)

                HomeSectionHeader(title: "Final, Bütünləmə, Yaz Okulu")
                finalCard
            }
            .padding(.horizontal, Theme.Space.s16)
            .padding(.bottom, Theme.Space.s24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .pageTitle("İmtahan", subtitle: page.subtitle, displayMode: isRoot ? .large : .inline)
    }

    /// Answered / total over every vize exam, accuracy ring.
    private func summaryCard(_ page: PdfDashboard) -> some View {
        let s = page.strip
        let denom = Double(max(s.answered, 1))
        return CardShell(title: "Ümumi nəticə", symbol: "doc.text.fill", tint: Theme.accent,
                         caption: s.extraValue.isEmpty ? nil : "Vaxt: \(s.extraValue)", chevron: false) {
            HStack(alignment: .bottom, spacing: Theme.Space.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(s.answered)")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit().foregroundStyle(Theme.text)
                        Text("/ \(s.totalQ) sual").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textMuted)
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    Text(s.answered > 0 ? "\(s.correct) düz · \(s.wrong) səhv" : "Hələ imtahan işlənməyib")
                        .font(.footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
                }
                Spacer(minLength: 0)
                RingDial(accent: Double(s.correct) / denom, danger: Double(s.wrong) / denom, lineWidth: 7) {
                    Text(s.answered > 0 ? "\(s.accuracy)%" : "—")
                        .font(.caption2.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.text)
                }
                .frame(width: 52, height: 52)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// One card, a row per subject (opens its exam list).
    @ViewBuilder private func subjectsCard(_ rows: [StudyListRow]) -> some View {
        if rows.isEmpty {
            CardShell(title: "İmtahan tapılmadı", symbol: "doc.text.magnifyingglass", tint: Theme.textMuted, chevron: false) { EmptyView() }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    Button { router.open(r.target) } label: {
                        HStack(spacing: Theme.Space.s12) {
                            SubjectIcon(course: r.name, size: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(r.name).font(.body).foregroundStyle(Theme.text).lineLimit(1)
                                    Spacer(minLength: 4)
                                    if let acc = r.accuracy {
                                        Text("\(acc)%").font(.subheadline.weight(.semibold)).monospacedDigit()
                                            .foregroundStyle(StatsFormat.tone(acc))
                                    }
                                }
                                Text([r.extra, r.done > 0 ? r.lastStr : nil].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted).lineLimit(1)
                                if r.done > 0 {
                                    SplitBar(total: max(r.total, r.done), ok: r.ok, bad: r.bad, height: 3).padding(.top, 2)
                                }
                            }
                            Chevron()
                        }
                        .padding(.vertical, Theme.Space.s10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    if i < rows.count - 1 { Divider().padding(.leading, 48) }
                }
            }
            .padding(.horizontal, Theme.Space.s16)
            .padding(.vertical, Theme.Space.s4)
            .card()
        }
    }

    /// Final booklets in Final mode; otherwise a locked card that opens Ayarlar.
    @ViewBuilder private var finalCard: some View {
        if store.examMode == .final {
            NavigationLink(value: Route.finalExams(nil)) {
                CardShell(title: "Final imtahanları", symbol: "graduationcap.fill", tint: .purple) {
                    Text("Keçmiş Final, Bütünləmə və Üç Ders imtahanları — bütün ünitələr.")
                        .font(.subheadline).foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: Route.settings) {
                CardShell(title: "Final imtahanları", symbol: "lock.fill", tint: Theme.textMuted) {
                    Text("Final rejimində görünür. Rejimi Ayarlarda dəyişə bilərsiniz.")
                        .font(.subheadline).foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

/// Exams of one subject (showPdfExamsList).
struct PdfSubjectView: View {
    let subject: String
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let page = store.pdfExamListPage(subject)
        List {
            PdfExamsSection(subject: subject)
        }
        .appListStyle()
        .pageTitle(subject, subtitle: page.subtitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Statistika", systemImage: "chart.bar.xaxis") { router.openStats(subject) }
            }
        }
    }
}
