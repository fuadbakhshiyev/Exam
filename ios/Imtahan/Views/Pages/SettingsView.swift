import SwiftUI
import UIKit

/// Tənzimləmələr (showSettings): font size, theme, shortcuts, backup export / import, reset.
struct SettingsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(SurpriseEngine.self) private var surprise

    @State private var backup = ""
    @State private var copied = false
    @State private var importText = ""
    @State private var confirmImport = false
    @State private var importMessage: String?
    @FocusState private var editorFocused: Bool

    var body: some View {
        @Bindable var store = store
        @Bindable var surprise = surprise
        Form {
            Section {
                Picker("İmtahan rejimi", selection: $store.examMode.animation()) {
                    ForEach(ExamMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .sensoryFeedback(.selection, trigger: store.examMode)
                .appRow()
            } header: {
                Text("İmtahan rejimi")
            } footer: {
                Text("Vize: yalnız 1–7-ci ünitələr. Final: bütün ünitələr. Bütün bölmələr, saylar və testlər seçilmiş rejimə uyğun göstərilir; məlumatlarınız silinmir.")
            }

            ExamDateSection()

            Section {
                Toggle(isOn: $surprise.isEnabled.animation()) {
                    Label("Sürpriz sual", systemImage: "gift.fill")
                }
                .tint(Theme.accent)
                .appRow()
                if surprise.isEnabled {
                    Picker(selection: $surprise.intervalMinutes) {
                        ForEach(SurpriseEngine.intervalChoices, id: \.self) { m in
                            Text("Hər \(m) dəqiqədən bir").tag(m)
                        }
                    } label: {
                        Label("Gəlmə aralığı", systemImage: "clock")
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

            ReminderSection()

            Section("Görünüş") {
                Picker("Şrift ölçüsü", selection: $store.fontScale) {
                    ForEach(StudyStore.fontScales, id: \.value) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.menu)
                .appRow()
                Picker("Tema", selection: $store.theme) {
                    Text("Sistem").tag(ThemeMode.system)
                    Text("Qaranlıq").tag(ThemeMode.dark)
                    Text("İşıqlı").tag(ThemeMode.light)
                }
                .pickerStyle(.menu)
                .appRow()
            }

            Section("Məlumat") {
                NavigationLink(value: Route.conflicts) { Label("Ziddiyyətli suallar", systemImage: "exclamationmark.triangle.fill") }.appRow()
                NavigationLink(value: Route.wrong) { Label("Səhvlərim", systemImage: "xmark.circle.fill") }.appRow()
                NavigationLink(value: Route.search("")) { Label("Sual və cavab axtarışı", systemImage: "magnifyingglass") }.appRow()
                Button { router.start(.bookmarks) } label: { Label("Seçilmişlər", systemImage: "bookmark.fill") }
                    .tint(Theme.text)
                    .appRow()
            }

            Section {
                ShareLink(item: backup) { Label("Ehtiyat nüsxəni paylaş", systemImage: "square.and.arrow.up") }.appRow()
                Button {
                    UIPasteboard.general.string = backup
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(2)); copied = false }
                } label: {
                    Label(copied ? "Kopyalandı! ✓" : "Kopyala", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .sensoryFeedback(.success, trigger: copied) { _, new in new }
                .appRow()
                TextEditor(text: $importText)
                    .focused($editorFocused)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .frame(minHeight: 100)
                    .overlay(alignment: .topLeading) {
                        if importText.isEmpty {
                            Text("Bərpa etmək istədiyiniz JSON məlumatını bura yapışdırın...")
                                .font(.footnote).foregroundStyle(Theme.textMuted)
                                .padding(.horizontal, 5).padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .appRow()
                Button("İdxal Et", systemImage: "square.and.arrow.down") {
                    editorFocused = false
                    if importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        importMessage = BackupImportError.empty.errorDescription
                    } else {
                        confirmImport = true
                    }
                }
                .appRow()
                .confirmationDialog("⚠️ Mövcud lokal datanız silinəcək!", isPresented: $confirmImport, titleVisibility: .visible) {
                    Button("İdxal Et", role: .destructive) { runImport() }
                    Button("Ləğv et", role: .cancel) {}
                }
            } header: {
                Text("Ehtiyat nüsxə")
            } footer: {
                Text("Statistikalarınızı, səhvlərinizi və digər datalarınızı başqa bir cihaza/domenə keçirmək üçün istifadə edin.")
            }

            Section {
                ResetStatsButton()
            }
        }
        .appListStyle()
        .pageTitle("Tənzimləmələr")
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
                Label("Gündəlik xatırlatma", systemImage: "bell.badge.fill")
            }
            .tint(Theme.accent)
            .disabled(reminder.isDenied && !reminder.isEnabled)
            .appRow()
            if reminder.isEnabled {
                DatePicker(selection: Binding(get: { reminder.time }, set: { reminder.time = $0 }),
                           displayedComponents: .hourAndMinute) {
                    Label("Vaxt", systemImage: "clock")
                }
                .appRow()
                Picker(selection: Binding(get: { reminder.goal }, set: { reminder.goal = $0 })) {
                    ForEach(StudyReminder.goalChoices, id: \.count) { g in
                        Text("\(g.level) · \(g.count) sual").tag(g.count)
                    }
                } label: {
                    Label("Gündəlik hədəf", systemImage: "target")
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

/// İmtahan tarixi: drives the Home countdown and daily plan. Device-local (UserDefaults "exam_date").
private struct ExamDateSection: View {
    @AppStorage(StudyStore.examDateKey) private var raw: Double = 0

    var body: some View {
        let date = Binding<Date>(
            get: { raw > 0 ? Date(timeIntervalSince1970: raw) : StudyStore.defaultExamDate },
            set: { raw = $0.timeIntervalSince1970 })
        Section {
            DatePicker(selection: date, displayedComponents: .date) {
                Label("İmtahan tarixi", systemImage: "calendar")
            }
            .environment(\.locale, Locale(identifier: "az"))
            .appRow()
        } header: {
            Text("İmtahan tarixi")
        } footer: {
            Text("Ana səhifədəki geri sayım və gündəlik plan bu tarixə görə hesablanır.")
        }
    }
}
