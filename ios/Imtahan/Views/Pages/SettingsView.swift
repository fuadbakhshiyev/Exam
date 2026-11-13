import SwiftUI
import UIKit

/// Tənzimləmələr, iOS Settings style: a short main page with coloured icon squares; notifications and
/// the backup tools live on their own pages.
struct SettingsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(SurpriseEngine.self) private var surprise

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker(selection: $store.examMode.animation()) {
                    ForEach(ExamMode.allCases) { Text($0.title).tag($0) }
                } label: {
                    SettingsLabel("Rejim", symbol: "graduationcap.fill", color: .blue)
                }
                .pickerStyle(.menu)
                .sensoryFeedback(.selection, trigger: store.examMode)
                .appRow()
                NavigationLink {
                    ExamDatesView()
                } label: {
                    LabeledContent {
                        Text(nextExamText)
                    } label: {
                        SettingsLabel("İmtahan tarixləri", symbol: "calendar", color: .red)
                    }
                }
                .appRow()
            } header: {
                Text("İmtahan")
            } footer: {
                Text(store.examMode == .vize
                     ? "Vize: yalnız 1–7-ci ünitələr. Geri sayım və gündəlik plan imtahan tarixinə görədir."
                     : "Final: bütün ünitələr. Geri sayım və gündəlik plan imtahan tarixinə görədir.")
            }

            Section {
                Toggle(isOn: Binding(get: { LearnSettings.shared.requeueWrong },
                                     set: { LearnSettings.shared.requeueWrong = $0 })) {
                    SettingsLabel("Səhvlər sonda qayıtsın", symbol: "arrow.uturn.backward", color: .orange)
                }
                .tint(Theme.accent)
                .appRow()
            } header: {
                Text("Öyrənmə")
            } footer: {
                Text("Testdə səhv etdiyin və ya \"Bilmirəm\" dediyin sual testin sonuna yenidən əlavə olunur və düz cavablayana qədər qayıdır. Balla qiymətləndirilən imtahanlarda, Böyük sınaqda və simulyasiyada işləmir.")
            }

            Section {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    LabeledContent {
                        Text(notificationSummary)
                    } label: {
                        SettingsLabel("Bildirişlər", symbol: "bell.badge.fill", color: .red)
                    }
                }
                .appRow()
            }

            Section {
                Picker(selection: $store.fontScale) {
                    ForEach(StudyStore.fontScales, id: \.value) { Text($0.label).tag($0.value) }
                } label: {
                    SettingsLabel("Şrift ölçüsü", symbol: "textformat.size", color: .indigo)
                }
                .pickerStyle(.menu)
                .appRow()
                Picker(selection: $store.theme) {
                    Text("Sistem").tag(ThemeMode.system)
                    Text("Qaranlıq").tag(ThemeMode.dark)
                    Text("İşıqlı").tag(ThemeMode.light)
                } label: {
                    SettingsLabel("Tema", symbol: "circle.lefthalf.filled", color: .gray)
                }
                .pickerStyle(.menu)
                .appRow()
            } header: {
                Text("Görünüş")
            }

            Section {
                NavigationLink {
                    BackupSettingsView()
                } label: {
                    SettingsLabel("Ehtiyat nüsxə", symbol: "externaldrive.fill", color: .green)
                }
                .appRow()
            } header: {
                Text("Məlumat")
            } footer: {
                Text("Datanı başqa cihaza keçirmək üçün ixrac və idxal.")
            }

            Section {
                ResetStatsButton()
            }
        }
        .appListStyle()
        .pageTitle("Tənzimləmələr")
    }

    /// "Grafik · 3 gün" — the nearest subject exam.
    private var nextExamText: String {
        ExamDates.shared.nextSummary ?? "Keçib"
    }

    private var notificationSummary: String {
        let r = StudyReminder.shared
        var parts: [String] = []
        if r.isEnabled { parts.append(r.time.formatted(date: .omitted, time: .shortened)) }
        if surprise.isEnabled { parts.append("Sürpriz") }
        return parts.isEmpty ? "Bağlı" : parts.joined(separator: " · ")
    }
}

/// İmtahan tarixləri: one exam day per subject (drives the Home countdown and the daily plan).
private struct ExamDatesView: View {
    private let dates = ExamDates.shared

    var body: some View {
        Form {
            Section {
                // Nearest exam first, finished ones last (re-sorts as soon as a date changes).
                ForEach(sortedSubjects, id: \.self) { s in
                    // Two lines: the full subject name on top, the countdown and the date / time pickers below.
                    VStack(alignment: .leading, spacing: Theme.Space.s10) {
                        HStack(spacing: Theme.Space.s12) {
                            SubjectIcon(course: s, size: 29)
                            Text(s).font(.body.weight(.medium)).foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: Theme.Space.s8) {
                            Text(daysText(s)).font(.subheadline).monospacedDigit()
                                .foregroundStyle(dates.daysLeft(s) <= 2 && !dates.isOver(s) ? Theme.warning : Theme.textMuted)
                            Spacer(minLength: 4)
                            DatePicker("\(s) imtahanı", selection: Binding(get: { dates.date(for: s) },
                                                          set: { d in withAnimation(.snappy) { dates.set(d, for: s) } }),
                                       displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .fixedSize()
                                .environment(\.locale, Locale(identifier: "az"))
                        }
                        .padding(.leading, 29 + Theme.Space.s12)
                    }
                    .padding(.vertical, Theme.Space.s4)
                    .appRow()
                }
            } footer: {
                Text("Tarix və saatı seçin. Ana səhifədəki geri sayım ən yaxın imtahanı göstərir. Gündəlik plan hər fənnin qalan suallarını öz imtahan gününə qədər bölür.")
            }
        }
        .appListStyle()
        .pageTitle("İmtahan tarixləri")
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var sortedSubjects: [String] {
        Catalog.subjects.sorted { a, b in
            let oa = dates.isOver(a), ob = dates.isOver(b)
            if oa != ob { return !oa }
            let da = dates.date(for: a), db = dates.date(for: b)
            return da != db ? da < db : Catalog.subjects.firstIndex(of: a)! < Catalog.subjects.firstIndex(of: b)!
        }
    }

    private func daysText(_ s: String) -> String {
        if dates.isOver(s) { return "Keçib" }
        let d = dates.daysLeft(s), t = dates.timeText(s)
        return d == 0 ? "Bu gün, \(t)" : (d == 1 ? "Sabah, \(t)" : "\(d) gün qalıb")
    }
}

/// iOS Settings row label: white symbol on a coloured rounded square + title.
struct SettingsLabel: View {
    let title: String
    let symbol: String
    let color: Color
    init(_ title: String, symbol: String, color: Color) {
        self.title = title; self.symbol = symbol; self.color = color
    }

    var body: some View {
        Label {
            Text(title).foregroundStyle(Theme.text)
        } icon: {
            IconTile(symbol: symbol, color: color)
        }
    }
}

/// Bildirişlər: the daily reminder and the surprise question.
private struct NotificationSettingsView: View {
    @Environment(SurpriseEngine.self) private var surprise

    var body: some View {
        @Bindable var surprise = surprise
        Form {
            ReminderSection()

            Section {
                Toggle(isOn: $surprise.isEnabled.animation()) {
                    SettingsLabel("Sürpriz sual", symbol: "gift.fill", color: .pink)
                }
                .tint(Theme.accent)
                .appRow()
                if surprise.isEnabled {
                    Picker(selection: $surprise.intervalMinutes) {
                        ForEach(SurpriseEngine.intervalChoices, id: \.self) { m in
                            Text("Hər \(m) dəqiqədən bir").tag(m)
                        }
                    } label: {
                        SettingsLabel("Gəlmə aralığı", symbol: "clock.fill", color: .orange)
                    }
                    .pickerStyle(.menu)
                    .appRow()
                }
            } header: {
                Text("Sürpriz sual")
            } footer: {
                Text(surprise.isEnabled
                     ? "Hər \(surprise.intervalMinutes) dəqiqədən bir təsadüfi sual çıxır, cavab üçün 30 saniyə verilir."
                     : "Sürpriz suallar bağlıdır.")
            }
        }
        .appListStyle()
        .pageTitle("Bildirişlər")
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

/// Ehtiyat nüsxə: share / copy the JSON backup, paste one to import.
private struct BackupSettingsView: View {
    @Environment(StudyStore.self) private var store
    @State private var backup = ""
    @State private var copied = false
    @State private var importText = ""
    @State private var confirmImport = false
    @State private var importMessage: String?
    @FocusState private var editorFocused: Bool

    var body: some View {
        Form {
            Section {
                ShareLink(item: backup) {
                    SettingsLabel("Paylaş", symbol: "square.and.arrow.up", color: .blue)
                }
                .appRow()
                Button {
                    UIPasteboard.general.string = backup
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(2)); copied = false }
                } label: {
                    SettingsLabel(copied ? "Kopyalandı ✓" : "Kopyala", symbol: copied ? "checkmark" : "doc.on.doc.fill", color: .gray)
                }
                .sensoryFeedback(.success, trigger: copied) { _, new in new }
                .appRow()
            } header: {
                Text("İxrac")
            } footer: {
                Text("Statistika, səhvlər və digər datalar JSON kimi.")
            }

            Section {
                TextEditor(text: $importText)
                    .focused($editorFocused)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if importText.isEmpty {
                            Text("JSON məlumatını bura yapışdırın...")
                                .font(.footnote).foregroundStyle(Theme.textMuted)
                                .padding(.horizontal, 5).padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .appRow()
                Button {
                    editorFocused = false
                    if importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        importMessage = BackupImportError.empty.errorDescription
                    } else {
                        confirmImport = true
                    }
                } label: {
                    SettingsLabel("İdxal et", symbol: "square.and.arrow.down", color: .orange)
                }
                .appRow()
                .confirmationDialog("⚠️ Mövcud lokal datanız silinəcək!", isPresented: $confirmImport, titleVisibility: .visible) {
                    Button("İdxal et", role: .destructive) { runImport() }
                    Button("Ləğv et", role: .cancel) {}
                }
            } header: {
                Text("İdxal")
            } footer: {
                Text("İdxal mövcud lokal datanı əvəz edir.")
            }
        }
        .appListStyle()
        .pageTitle("Ehtiyat nüsxə")
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { backup = store.exportBackup() }
        .alert(importMessage ?? "", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func runImport() {
        do {
            try store.importBackup(importText)
            importText = ""
            backup = store.exportBackup()
            importMessage = "Məlumatlar uğurla idxal edildi!"
        } catch {
            importMessage = error.localizedDescription
        }
    }
}

/// Xatırlatma: daily local notification at a chosen time, skipped once today's goal is reached.
private struct ReminderSection: View {
    @State private var reminder = StudyReminder.shared
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { reminder.isEnabled },
                                 set: { on in Task { await reminder.setEnabled(on) } })) {
                SettingsLabel("Gündəlik xatırlatma", symbol: "bell.fill", color: .red)
            }
            .tint(Theme.accent)
            .disabled(reminder.isDenied && !reminder.isEnabled)
            .appRow()
            if reminder.isEnabled {
                DatePicker(selection: Binding(get: { reminder.time }, set: { reminder.time = $0 }),
                           displayedComponents: .hourAndMinute) {
                    SettingsLabel("Vaxt", symbol: "clock.fill", color: .orange)
                }
                .appRow()
                Picker(selection: Binding(get: { reminder.goal }, set: { reminder.goal = $0 })) {
                    ForEach(StudyReminder.goalChoices, id: \.count) { g in
                        Text("\(g.level) · \(g.count) sual").tag(g.count)
                    }
                } label: {
                    SettingsLabel("Gündəlik hədəf", symbol: "target", color: .blue)
                }
                .pickerStyle(.menu)
                .appRow()
            }
            if reminder.isDenied {
                Button("Bildiriş icazəsini aç", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .appRow()
            }
        } header: {
            Text("Xatırlatma")
        } footer: {
            Text(footer)
        }
        .task { await reminder.refreshAuthorization() }
        .onChange(of: phase) { _, p in
            if p == .active { Task { await reminder.refreshAuthorization() } }
        }
    }

    private var footer: String {
        if reminder.isDenied {
            return "Bildirişlərə icazə verilməyib. Xatırlatma üçün Ayarlar → İmtahan → Bildirişlər bölməsində icazəni aktiv edin."
        }
        if reminder.isEnabled {
            return "Bildiriş vaxtı: hər gün \(reminder.time.formatted(date: .omitted, time: .shortened)). Bu gün \(reminder.goal) sual həll etmisənsə, həmin günün xatırlatması göndərilmir."
        }
        return "Gündəlik hədəfə çatmamısansa, seçdiyin vaxtda xatırladırıq."
    }
}
