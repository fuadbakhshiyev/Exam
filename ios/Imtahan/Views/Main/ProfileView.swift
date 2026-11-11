import SwiftUI
import UIKit

/// "Profil": account and cloud sync, the stopwatch and the Ayarlar link. Statistics live in their own tab.
struct ProfileView: View {
    @Environment(StudyStore.self) private var store
    @Environment(SyncService.self) private var sync

    var body: some View {
        List {
            account

            TimerSection()

            Section {
                NavigationLink(value: Route.settings) {
                    LabeledContent {
                        Text(store.examMode.title).foregroundStyle(Theme.textMuted)
                    } label: {
                        link("Ayarlar", "gearshape.fill", .gray)
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
            IconTile(symbol: symbol, color: tint)
        }
    }

    @ViewBuilder private var account: some View {
        if let u = sync.user {
            Section("Hesab") {
                NavigationLink {
                    AccountView()
                } label: {
                    HStack(spacing: 12) {
                        Avatar(user: u, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(u.title).font(.title3.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                            Text(sync.statusText).font(.caption).foregroundStyle(sync.isError ? Theme.danger : Theme.success).lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
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

/// Round profile photo, or the first letter on the accent colour.
private struct Avatar: View {
    let user: SyncService.CloudUser
    let size: CGFloat
    var body: some View {
        AsyncImage(url: user.photoURL) { img in img.resizable().scaledToFill() } placeholder: {
            Text(String(user.title.prefix(1)).uppercased())
                .font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.accent.gradient)
        }
        .frame(width: size, height: size).clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Profil → Hesab: who is signed in, sync status / sync now, sign out.
private struct AccountView: View {
    @Environment(SyncService.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var showSyncError = false
    @State private var confirmSignOut = false

    var body: some View {
        Form {
            if let u = sync.user {
                Section {
                    VStack(spacing: 8) {
                        Avatar(user: u, size: 88)
                        Text(u.title).font(.title2.weight(.semibold)).foregroundStyle(Theme.text)
                        if let email = u.email, email != u.title {
                            Text(email).font(.subheadline).foregroundStyle(Theme.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Button { if sync.isError { showSyncError = true } } label: {
                        LabeledContent {
                            Text(sync.statusText).foregroundStyle(sync.isError ? Theme.danger : Theme.success).lineLimit(1)
                        } label: {
                            Label { Text("Vəziyyət").foregroundStyle(Theme.text) } icon: {
                                IconTile(symbol: sync.isError ? "exclamationmark.icloud.fill" : "checkmark.icloud.fill",
                                         color: sync.isError ? Theme.danger : Theme.success)
                            }
                        }
                    }
                    .disabled(!sync.isError)
                    .appRow()
                    Button { sync.syncNow() } label: {
                        Label { Text("İndi sinxronlaşdır").foregroundStyle(Theme.text) } icon: {
                            IconTile(symbol: "arrow.triangle.2.circlepath", color: Theme.accent)
                        }
                    }
                    .appRow()
                } header: {
                    Text("Bulud sinxronizasiyası")
                } footer: {
                    Text("Nəticələr sayt və telefon arasında avtomatik birləşdirilir.")
                }

                Section {
                    Button(role: .destructive) { confirmSignOut = true } label: {
                        Text("Çıxış").frame(maxWidth: .infinity)
                    }
                    .appRow()
                }
            }
        }
        .appListStyle()
        .navigationTitle("Hesab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .alert("Sinxronizasiya xətası", isPresented: $showSyncError) {
            Button("Kopyala") { UIPasteboard.general.string = sync.statusText }
            Button("Oldu", role: .cancel) {}
        } message: {
            Text(sync.statusText)
        }
        .confirmationDialog("Hesabdan çıxılsın?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Çıxış", role: .destructive) {
                Task { await sync.signOut(); dismiss() }
            }
            Button("Ləğv et", role: .cancel) {}
        } message: {
            Text("Telefondakı nəticələr qalır.")
        }
    }
}
