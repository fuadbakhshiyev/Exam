import SwiftUI
import UIKit

/// Tənzimləmələr, iOS Settings style: a short main page with coloured icon squares; notifications and
/// the backup tools live on their own pages.
struct SettingsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(SurpriseEngine.self) private var surprise
    @AppStorage(StudyStore.examDateKey) private var examDateRaw: Double = 0

    var body: some View {
        @Bindable var store = store
        let examDate = Binding<Date>(
            get: { examDateRaw > 0 ? Date(timeIntervalSince1970: examDateRaw) : StudyStore.defaultExamDate },
            set: { examDateRaw = $0.timeIntervalSince1970 })
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
                DatePicker(selection: examDate, displayedComponents: .date) {
                    SettingsLabel("İmtahan tarixi", symbol: "calendar", color: .red)
                }
                .environment(\.locale, Locale(identifier: "az"))
                .appRow()
            } header: {
                Text("İmtahan")
            } footer: {
                Text(store.examMode == .vize
                     ? "Vize: yalnız 1–7-ci ünitələr. Geri sayım və gündəlik plan imtahan tarixinə görədir."
                     : "Final: bütün ünitələr. Geri sayım və gündəlik plan imtahan tarixinə görədir.")
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

    private var notificationSummary: String {
        let r = StudyReminder.shared
        var parts: [String] = []
        if r.isEnabled { parts.append(r.time.formatted(date: .omitted, time: .shortened)) }
        if surprise.isEnabled { parts.append("Sürpriz") }
        return parts.isEmpty ? "Bağlı" : parts.joined(separator: " · ")
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
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
