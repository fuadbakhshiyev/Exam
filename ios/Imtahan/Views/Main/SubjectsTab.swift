import SwiftUI

/// "Fənlər" tab: subjects, practice exams and tools as a native inset-grouped list.
/// Every row has the same anatomy: leading glyph, title (+ caption), optional trailing value.
struct SubjectsTab: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    /// "list" or "grid".
    @AppStorage("subjects_layout") private var layout = "list"
    /// "custom", "exam", "name", "progress".
    @AppStorage("subjects_sort") private var sort = "custom"
    /// The user's own order, subjects joined by "|".
    @AppStorage("subjects_order") private var orderRaw = ""
    @State private var reordering = false

    /// Subjects in the chosen order (new subjects go to the end of a custom order).
    private var subjects: [String] {
        switch sort {
        case "exam":
            let d = ExamDates.shared
            return Catalog.subjects.sorted { (d.isOver($0) ? 1 : 0, d.date(for: $0)) < (d.isOver($1) ? 1 : 0, d.date(for: $1)) }
        case "name":
            return Catalog.subjects.sorted { $0.localizedCompare($1) == .orderedAscending }
        case "progress":
            return Catalog.subjects.sorted { store.navProgress($0) > store.navProgress($1) }
        default:
            return SubjectOrder.apply(orderRaw)
        }
    }

    var body: some View {
        List {
            Section {
                if layout == "grid" {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Space.s12)], spacing: Theme.Space.s12) {
                        ForEach(subjects, id: \.self) { c in
                            // Buttons, not NavigationLinks: inside a List row a link adds its own disclosure arrow.
                            Button { router.push(.course(c)) } label: { SubjectGridCard(course: c) }.buttonStyle(.plain)
                        }
                        Button { router.push(.overall) } label: { SubjectGridCard(course: Catalog.overallKey) }
                            .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(subjects, id: \.self) { c in
                        NavigationLink(value: Route.course(c)) { subjectRow(c) }.appRow()
                    }
                    NavigationLink(value: Route.overall) { overallRow }.appRow()
                }
            } header: {
                Text("Fənlər")
            } footer: {
                Text("İmtahan rejimi: \(store.examModeLabel). Ayarlardan dəyişə bilərsiniz.")
            }

            Section {
                card { router.push(.pdfDashboard) } content: {
                    MetricCard(title: "Vize imtahanları", symbol: "doc.text.fill", tint: Theme.accent,
                               value: "\(QuestionBank.shared.pdfExamCount)", unit: "imtahan",
                               note: "Keçmiş illərin real sualları") { EmptyView() }
                }
                card { router.push(.mixed) } content: {
                    let m = store.subjectStatsRow(Catalog.mixedKey)
                    MetricCard(title: "Mixed", symbol: "shuffle", tint: .purple,
                               value: "\(store.scopedMixedParts.count)", unit: "hissə",
                               note: m.answered > 0 ? "\(min(m.answered, m.total))/\(m.total) işlənib · \(m.accuracy ?? 0)% düz" : "\(m.total) sual · başlanmayıb") { EmptyView() }
                }
                card { router.start(.mock) } content: {
                    MetricCard(title: "Böyük sınaq", symbol: "die.face.5.fill", tint: Theme.warning,
                               value: "\(Catalog.subjects.count * 20)", unit: "sual",
                               note: "Hər fəndən 20 · dərhal başlayır") {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34)).foregroundStyle(Theme.warning)
                    }
                }
            } header: {
                Text("Sınaq")
            }

            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Space.s12), GridItem(.flexible())],
                          spacing: Theme.Space.s12) {
                    ToolCard(title: "Səhvlərim", symbol: "xmark.octagon.fill", tint: Theme.danger,
                             value: "\(store.wrongTotal)", caption: "sual") { router.push(.wrong) }
                    ToolCard(title: "Ən çətinlər", symbol: "flame.fill", tint: Theme.warning,
                             value: "\(store.hardCount)", caption: "2+ səhv") { router.start(.hard) }
                    ToolCard(title: "Seçilmişlər", symbol: "star.fill", tint: .yellow,
                             value: "\(store.scopedMarks.count)", caption: "sual") { router.start(.bookmarks) }
                    ToolCard(title: "Ziddiyyətli", symbol: "arrow.triangle.branch", tint: .purple,
                             value: nil, caption: "suallar") { router.push(.conflicts) }
                    ToolCard(title: "Axtarış", symbol: "magnifyingglass", tint: Theme.accent,
                             value: nil, caption: "sual və cavab") { router.push(.search("")) }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Alətlər")
            }
        }
        .appListStyle()
        .navigationTitle("Fənlər")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Görünüş", selection: $layout.animation(.snappy)) {
                        Label("Siyahı", systemImage: "list.bullet").tag("list")
                        Label("Kartlar", systemImage: "square.grid.2x2").tag("grid")
                    }
                    Picker("Sıralama", selection: $sort.animation(.snappy)) {
                        Label("Öz sıram", systemImage: "hand.draw").tag("custom")
                        Label("Ən yaxın imtahan", systemImage: "calendar").tag("exam")
                        Label("İrəliləyiş", systemImage: "chart.bar.fill").tag("progress")
                        Label("Ad", systemImage: "textformat").tag("name")
                    }
                    Divider()
                    Button { reordering = true } label: { Label("Sıranı dəyiş…", systemImage: "arrow.up.arrow.down") }
                } label: {
                    Label("Görünüş", systemImage: layout == "grid" ? "square.grid.2x2" : "list.bullet")
                }
            }
        }
        .sheet(isPresented: $reordering) {
            SubjectOrderSheet(orderRaw: $orderRaw) { sort = "custom" }
                .appEnvironment()
        }
    }

    /// "12 imtahan" / "12" when > 0, nil otherwise (no zero counts on the page).
    private func count(_ n: Int, _ noun: String? = nil) -> String? {
        guard n > 0 else { return nil }
        return noun.map { "\(n) \($0)" } ?? "\(n)"
    }

    // MARK: Subject rows

    /// Subject glyph (single place to swap in a dedicated subject icon).
    private func subjectGlyph(_ c: String) -> some View {
        SubjectIcon(course: c, size: 36).accessibilityHidden(true)
    }

    private func subjectRow(_ c: String) -> some View {
        let units = store.scopedUnitCount(c)
        let questions = store.courseTotalQuestions(c)
        return HStack(spacing: Theme.Space.s12) {
            subjectGlyph(c)
            titleStack(c, caption: [count(units, "bölmə"), count(questions, "sual")].compactMap { $0 }.joined(separator: " · "))
            Spacer(minLength: 4)
            ProgressBadge(percent: store.navProgress(c))
        }
        .padding(.vertical, 2)
    }

    private var overallRow: some View {
        HStack(spacing: Theme.Space.s12) {
            subjectGlyph(Catalog.overallKey)
            titleStack(Catalog.overallKey, caption: "Bütün fənlər · \(store.scopedQuestionsTotal) sual")
            Spacer(minLength: 4)
        }
        .padding(.vertical, 2)
    }

    private func titleStack(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.body).foregroundStyle(Theme.text).lineLimit(1)
            if !caption.isEmpty {
                Text(caption).font(.caption).foregroundStyle(Theme.textMuted).monospacedDigit().lineLimit(1)
            }
        }
    }

    // MARK: Sınaq / Alətlər cards

    /// One Health-style card as its own clear list row (Button, so List adds no disclosure chevron).
    private func card<C: View>(_ action: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        Button(action: action, label: content)
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Theme.Space.s12, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

/// Half-width Health card for "Alətlər": tinted title ›, then a big count (or a short caption).
private struct ToolCard: View {
    let title: String
    let symbol: String
    let tint: Color
    let value: String?
    let caption: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.s10) {
                HStack(spacing: 6) {
                    Image(systemName: symbol).symbolVariant(.fill).foregroundStyle(tint)
                    Text(title)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Chevron()
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let value {
                        Text(value).font(.system(size: 26, weight: .semibold, design: .rounded))
                            .monospacedDigit().foregroundStyle(Theme.text)
                    }
                    Text(caption).font(value == nil ? .subheadline : .footnote).foregroundStyle(Theme.textMuted).lineLimit(1)
                }
                .frame(minHeight: 31, alignment: .bottomLeading)
            }
            .padding(Theme.Space.s14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// Small trailing progress indicator of a subject row: "42%" next to a mini ring. Hidden at 0%.
private struct ProgressBadge: View {
    let percent: Int
    @ScaledMetric(relativeTo: .caption) private var ring: CGFloat = 18

    var body: some View {
        if percent > 0 {
            HStack(spacing: 6) {
                Text("\(percent)%").font(.subheadline).monospacedDigit().foregroundStyle(Theme.textMuted)
                ZStack {
                    Circle().stroke(Theme.track, lineWidth: 2.5)
                    Circle().trim(from: 0, to: min(1, Double(percent) / 100))
                        .stroke(percent >= 100 ? Theme.success : Theme.accent,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: ring, height: ring)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(percent) faiz işlənib")
        }
    }
}

// MARK: - Order

enum SubjectOrder {
    static func apply(_ raw: String) -> [String] {
        let saved = raw.split(separator: "|").map(String.init).filter { Catalog.subjects.contains($0) }
        return saved + Catalog.subjects.filter { !saved.contains($0) }
    }
}

/// "Sıranı dəyiş": drag the subjects into the order the Fənlər page should use.
private struct SubjectOrderSheet: View {
    @Binding var orderRaw: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var items: [String] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items, id: \.self) { c in
                        HStack(spacing: Theme.Space.s12) {
                            SubjectIcon(course: c, size: 32)
                            Text(c).foregroundStyle(Theme.text).lineLimit(2)
                        }
                        .appRow()
                    }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Fənni sağdakı tutacaqdan sürüşdürün. Ən yuxarıdakı birinci görünəcək.")
                }
            }
            .appListStyle()
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Fənlərin sırası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sıfırla") { withAnimation { items = Catalog.subjects } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hazır") {
                        orderRaw = items.joined(separator: "|")
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { items = SubjectOrder.apply(orderRaw) }
    }
}

/// Grid card of a subject: icon, full name, progress and the exam countdown.
private struct SubjectGridCard: View {
    let course: String
    @Environment(StudyStore.self) private var store

    var body: some View {
        let isOverall = course == Catalog.overallKey
        let p = isOverall ? 0 : store.navProgress(course)
        VStack(alignment: .leading, spacing: Theme.Space.s8) {
            HStack(alignment: .top) {
                SubjectIcon(course: course, size: 40)
                Spacer(minLength: 4)
            }
            Text(course).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                .lineLimit(2, reservesSpace: true)
                .fixedSize(horizontal: false, vertical: true)
            // Same bottom block on every card (the overall card keeps its height with a hidden bar).
            VStack(alignment: .leading, spacing: Theme.Space.s8) {
                ProgressView(value: Double(p), total: 100).tint(Theme.accent)
                    .opacity(isOverall ? 0 : 1)
                HStack {
                    if isOverall {
                        Text("Bütün fənlər · \(store.scopedQuestionsTotal) sual").font(.caption).foregroundStyle(Theme.textMuted)
                            .lineLimit(1)
                    } else {
                        Text("\(p)% işlənib").font(.caption).monospacedDigit().foregroundStyle(Theme.textMuted)
                        Spacer(minLength: 4)
                        let d = ExamDates.shared
                        Text(d.isOver(course) ? "bitib" : "\(d.daysLeft(course)) gün")
                            .font(.caption.weight(.medium)).monospacedDigit()
                            .foregroundStyle(!d.isOver(course) && d.daysLeft(course) <= 3 ? Theme.warning : Theme.textMuted)
                    }
                }
            }
        }
        .padding(Theme.Space.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Theme.Radius.md, fill: Theme.surface)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
