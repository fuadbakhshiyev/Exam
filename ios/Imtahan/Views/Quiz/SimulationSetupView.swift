import SwiftUI

/// Card version of the entry for the İmtahan tab (same setup sheet).
struct SimulationEntryCard: View {
    @Environment(AppRouter.self) private var router
    @State private var showSetup = false
    @State private var pending: SimulationConfig?

    var body: some View {
        Button { showSetup = true } label: {
            CardShell(title: "Real imtahan simulyasiyası", symbol: "stopwatch.fill", tint: Theme.accent, chevron: false) {
                HStack(alignment: .center, spacing: Theme.Space.s12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bütün fənlər · vaxtla · nəticə sonda")
                            .font(.headline).foregroundStyle(Theme.text)
                        Text("ATA AÖF formatı: 4 səhv 1 düzü aparır.")
                            .font(.footnote).foregroundStyle(Theme.textMuted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "play.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent, in: .circle)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Simulyasiyanın ayarlarını açır")
        .sheet(isPresented: $showSetup, onDismiss: {
            if let c = pending { pending = nil; router.start(.simulation(c)) }
        }) {
            SimulationSetupView { pending = $0; showSetup = false }
                .appEnvironment()
        }
    }
}

/// Setup sheet: subjects, questions per subject, duration, question source.
struct SimulationSetupView: View {
    let onStart: (SimulationConfig) -> Void
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum TimingKind: Hashable { case standard, perSubject, total }

    @State private var selected = Set(Catalog.subjects)
    @State private var perSubject = 20
    @State private var timingKind: TimingKind = .standard
    @State private var perSubjectMinutes = 30
    @State private var totalMinutes = 150
    @State private var includePast = false
    @State private var poolSizes: [String: Int] = [:]

    private var config: SimulationConfig {
        var c = SimulationConfig()
        c.subjects = Catalog.subjects.filter { selected.contains($0) }
        c.questionsPerSubject = perSubject
        c.includePastExams = includePast
        switch timingKind {
        case .standard: c.timing = .standard
        case .perSubject: c.timing = .perSubject(minutes: perSubjectMinutes)
        case .total: c.timing = .total(minutes: totalMinutes)
        }
        return c
    }

    /// Questions the exam will actually have (a subject with a smaller pool gives all it has).
    private var questionCount: Int {
        config.subjects.reduce(0) { $0 + min(perSubject, poolSizes[$1] ?? perSubject) }
    }

    private var durationText: String {
        let s = config.durationSeconds(questionCount: questionCount, subjectCount: config.subjects.count)
        return CompactFormat.duration(s) ?? "1 dəq"
    }

    private var shortSubjects: [String] {
        config.subjects.filter { (poolSizes[$0] ?? perSubject) < perSubject }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Catalog.subjects, id: \.self) { s in
                        Toggle(isOn: Binding(get: { selected.contains(s) },
                                             set: { if $0 { selected.insert(s) } else { selected.remove(s) } })) {
                            HStack(spacing: Theme.Space.s12) {
                                SubjectIcon(course: s, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s).foregroundStyle(Theme.text).lineLimit(1)
                                    if let n = poolSizes[s] {
                                        Text("\(n) sual hovuzda").font(.caption).foregroundStyle(Theme.textMuted).monospacedDigit()
                                    }
                                }
                            }
                        }
                        .tint(Theme.accent)
                        .appRow()
                    }
                } header: {
                    Text("Fənlər")
                } footer: {
                    Text("Hər fənn ayrıca qiymətləndirilir (0–100 bal).")
                }

                Section {
                    Picker("Hər fəndən", selection: $perSubject) {
                        ForEach(SimulationConfig.questionChoices, id: \.self) { Text("\($0) sual").tag($0) }
                    }
                    .appRow()
                } header: {
                    Text("Suallar")
                } footer: {
                    if !shortSubjects.isEmpty {
                        Text("\(shortSubjects.map(ExamSimulation.shortName).joined(separator: ", ")): hovuzda daha az sual var, hamısı veriləcək.")
                    }
                }

                Section {
                    Picker("Vaxt", selection: $timingKind) {
                        Text("ATA AÖF standartı").tag(TimingKind.standard)
                        Text("Fənn başına").tag(TimingKind.perSubject)
                        Text("Ümumi").tag(TimingKind.total)
                    }
                    .appRow()
                    if timingKind == .perSubject {
                        Picker("Fənn başına", selection: $perSubjectMinutes) {
                            ForEach(SimulationConfig.perSubjectMinuteChoices, id: \.self) { Text("\($0) dəq").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .appRow()
                    } else if timingKind == .total {
                        Picker("Ümumi vaxt", selection: $totalMinutes) {
                            ForEach(SimulationConfig.totalMinuteChoices, id: \.self) { m in
                                Text(CompactFormat.duration(m * 60) ?? "\(m) dəq").tag(m)
                            }
                        }
                        .appRow()
                    }
                    LabeledContent("Cəmi vaxt", value: durationText).appRow()
                } header: {
                    Text("Vaxt")
                } footer: {
                    Text(timingKind == .standard ? "20 sual ≈ 30 dəqiqə (sual başına 1,5 dəqiqə). Vaxt bitəndə imtahan avtomatik təhvil verilir."
                                                 : "Vaxt bitəndə imtahan avtomatik təhvil verilir.")
                }

                Section {
                    LabeledContent("Rejim", value: store.examModeLabel).appRow()
                    Toggle("Keçmiş imtahan sualları", isOn: $includePast).tint(Theme.accent).appRow()
                } header: {
                    Text("Mənbə")
                } footer: {
                    Text(store.examMode == .final
                         ? "Ünitə sualları + istəsəniz Vize PDF imtahanları və keçmiş Final kitabçaları. Rejimi Ayarlarda dəyişə bilərsiniz."
                         : "Ünitə sualları + istəsəniz Vize PDF imtahanları. Rejimi Ayarlarda dəyişə bilərsiniz.")
                }

                Section {
                    SettingsLabel("Cavab verəndə düz/səhv göstərilmir", symbol: "eye.slash.fill", color: .gray)
                    SettingsLabel("Cavabı bitirənə qədər dəyişə bilərsiniz", symbol: "arrow.triangle.2.circlepath", color: .blue)
                    SettingsLabel("Şübhəli sualları işarələyin", symbol: "flag.fill", color: .orange)
                    SettingsLabel("Nəticə: 4 səhv 1 düzü aparır", symbol: "function", color: .red)
                } header: {
                    Text("Qaydalar")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textCaption)
                .listRowBackground(Theme.surface)
            }
            .appListStyle()
            .navigationTitle("İmtahan simulyasiyası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Bağla")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button { onStart(config) } label: {
                    VStack(spacing: 2) {
                        Text("Başla").font(.headline)
                        Text("\(questionCount) sual · \(durationText)").font(.caption).monospacedDigit().opacity(0.85)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .largeControl()
                .disabled(selected.isEmpty || questionCount == 0)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .presentationBackground(Theme.bg)
        .task(id: includePast) { computePools() }
    }

    private func computePools() {
        var d: [String: Int] = [:]
        for s in Catalog.subjects { d[s] = store.simulationPool(subject: s, includePastExams: includePast).count }
        poolSizes = d
    }
}
