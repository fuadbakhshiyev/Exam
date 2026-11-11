import SwiftUI
import UIKit

/// "Profil": account and cloud sync, the stopwatch and the Ayarlar link. Statistics live in their own tab.
struct ProfileView: View {
    @Environment(StudyStore.self) private var store
    @Environment(SyncService.self) private var sync

    @State private var showSyncError = false

    var body: some View {
        List {
            account

            TimerSection()

            Section {
                NavigationLink(value: Route.settings) {
                    LabeledContent {
                        Text(store.examMode.title).foregroundStyle(Theme.textMuted)
                    } label: {
                        link("Ayarlar", "gearshape.fill", Theme.textCaption)
                    }
                }
                .appRow()
            }
        }
        .appListStyle()
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.large)
        .alert("Giriş alınmadı", isPresented: Binding(get: { sync.signInError != nil }, set: { if !$0 { sync.signInError = nil } })) {
            Button("Oldu", role: .cancel) {}
        } message: { Text(sync.signInError ?? "") }
    }

    private func link(_ title: String, _ symbol: String, _ tint: Color) -> some View {
        Label {
            Text(title).foregroundStyle(Theme.text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
    }

    @ViewBuilder private var account: some View {
        if let u = sync.user {
            Section("Hesab") {
                HStack(spacing: 12) {
                    AsyncImage(url: u.photoURL) { img in img.resizable().scaledToFill() } placeholder: {
                        Text(String(u.title.prefix(1)).uppercased()).font(.headline).foregroundStyle(Theme.onInverse)
                            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.accent)
                    }
                    .frame(width: 44, height: 44).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(u.title).font(.body.weight(.medium)).foregroundStyle(Theme.text).lineLimit(1)
                        Text(sync.statusText).font(.caption).foregroundStyle(sync.isError ? Theme.danger : Theme.success).lineLimit(1)
                    }
                    Spacer()
                    if sync.isError {
                        Image(systemName: "info.circle").foregroundStyle(Theme.danger)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { if sync.isError { showSyncError = true } }
                .alert("Sinxronizasiya xətası", isPresented: $showSyncError) {
                    Button("Kopyala") { UIPasteboard.general.string = sync.statusText }
                    Button("Oldu", role: .cancel) {}
                } message: {
                    Text(sync.statusText)
                }
                .appRow()
                Button { sync.syncNow() } label: { link("İndi sinxronlaşdır", "arrow.triangle.2.circlepath", Theme.accent) }
                    .appRow()
                Button(role: .destructive) { Task { await sync.signOut() } } label: { Label("Çıxış", systemImage: "rectangle.portrait.and.arrow.right") }
                    .appRow()
            }
        } else {
            Section {
                Button { Task { await sync.signIn() } } label: {
                    Label("Google ilə daxil ol", systemImage: "person.crop.circle.badge.checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!SyncService.isConfigured)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("Bulud sinxronizasiyası")
            } footer: {
                Text(SyncService.isConfigured
                     ? "Google hesabınızla daxil olun — nəticələriniz sayt və telefon arasında birləşdirilir."
                     : "Firebase konfiqurasiya olunmayıb. GoogleService-Info.plist əlavə edildikdən sonra giriş aktiv olacaq.")
            }
        }
    }
}
