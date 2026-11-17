import SwiftUI
import AppKit
import Intents
import SiftCore

struct SiftSettings: View {
    @Environment(MailboxModel.self) private var model
    var body: some View {
        @Bindable var model = model
        TabView {
            Form {
                Section("Bildirimler") {
                    Toggle("Önemli postaları çentikte göster", isOn: $model.cache.preferences.notchEnabled)
                    Picker("En düşük önem", selection: $model.cache.preferences.minimumTier) {
                        Text("Kritik").tag(PriorityTier.critical)
                        Text("Önemli").tag(PriorityTier.important)
                        Text("Normal").tag(PriorityTier.normal)
                    }
                    Slider(value: $model.cache.preferences.alertDuration, in: 3...30, step: 1) { Text("Süre: \(Int(model.cache.preferences.alertDuration)) saniye") }
                    Toggle("İmleç üzerine gelince genişlet", isOn: $model.cache.preferences.expandOnHover)
                    Toggle("Bildirimde göndereni ve konuyu gizle", isOn: $model.cache.preferences.hidePreview)
                    Toggle("Bildirimleri duraklat", isOn: $model.cache.preferences.paused)
                    Button("Çentik bildirimini dene") { model.previewNotch() }
                    Text("Çentiği aç / kapat: ⌃⌥S. Sift açıkken yaklaşık her dakika eşitlenir.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Sessiz saatler") {
                    Toggle("Sessiz saatleri kullan", isOn: $model.cache.preferences.quietHours)
                    HStack {
                        Picker("Başlangıç", selection: $model.cache.preferences.quietStart) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                        Picker("Bitiş", selection: $model.cache.preferences.quietEnd) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                    }.disabled(!model.cache.preferences.quietHours)
                    Text("macOS Odak durumu paylaşıldığında bildirimler bastırılır. Durum paylaşılmıyorsa sessiz saatleri veya duraklatmayı kullan. Önizleme bu sınırları geçici olarak atlar.").font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("Çentik", systemImage: "bell.badge") }
            AccountSettings().tabItem { Label("Hesaplar", systemImage: "person.crop.circle") }
            Form {
                Section("Bu Mac’te") {
                    Label("E-posta içeriği harici yapay zekâya gönderilmez", systemImage: "lock.shield")
                    Label("Uzak görseller ve HTML yüklenmez", systemImage: "eye.slash")
                    Text("Özet, postanın metin önizlemesidir; yapay zekâ tarafından üretilmiş değildir. Önem sıralaması açıklanabilir yerel kurallarla hesaplanır. Posta önbelleği macOS uygulama klasöründe saklanır; erişim anahtarları yalnızca Anahtar Zinciri’ndedir.").font(.callout).foregroundStyle(.secondary)
                }
                Section("Gönderen tercihleri") {
                    Text("VIP: \(model.cache.preferences.vipAddresses.sorted().joined(separator: ", "))")
                    Text("Sessiz: \(model.cache.preferences.mutedAddresses.sorted().joined(separator: ", "))")
                    Button("Gönderen tercihlerini sıfırla") {
                        model.cache.preferences.vipAddresses = []; model.cache.preferences.mutedAddresses = []
                        for i in model.cache.mail.indices { model.cache.mail[i].message = PriorityScorer().score(model.cache.mail[i].message) }
                        model.save()
                    }
                }
                Text("Hesabı kaldırmak bu Mac’teki önbelleğini ve erişim anahtarını siler. Microsoft hesabındaki postalar silinmez. Microsoft hesabının uygulama izinleri sayfasından verilen izni ayrıca iptal edebilirsin.").font(.caption).foregroundStyle(.secondary)
            }.formStyle(.grouped).tabItem { Label("Gizlilik", systemImage: "hand.raised") }
            VStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 96, height: 96)
                Text("Sift").font(.largeTitle.weight(.semibold))
                Text("Sürüm \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") · Yapı \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")")
                    .foregroundStyle(.secondary)
                Text("Önemli postalar, tam çentiğinde.")
                Link("Yayınlanan sürümleri aç", destination: URL(string: "https://github.com/AliGaffarToksoy/Sift/releases")!)
                Link("Geliştirme ve hata bildirimleri", destination: URL(string: "https://github.com/AliGaffarToksoy/Sift/issues")!)
                Text("Güncellemeler GitHub’dan elle indirilir. Bu geliştirme sürümünde Outlook kurulumu ve gerçek cihaz kontrolleri devam ediyor.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(32).tabItem { Label("Hakkında", systemImage: "info.circle") }
        }.padding(12).frame(width: 640, height: 570)
            .onDisappear { model.save() }
            .onChange(of: model.cache.preferences.notchEnabled) { _, enabled in model.save(); if !enabled { model.notch?.hide() } }
            .onChange(of: model.cache.preferences.paused) { _, paused in model.save(); if paused { model.notch?.hide() } }
    }
}

struct AccountSettings: View {
    @Environment(MailboxModel.self) private var model
    var body: some View {
        @Bindable var model = model
        Form {
            Section("Outlook / Microsoft 365") {
                ForEach(model.cache.accounts) { account in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(account.address, systemImage: "envelope.badge.shield.half.filled")
                            Spacer()
                            Button("Kaldır", role: .destructive) { model.removingAccount = account }.disabled(model.syncing || !model.busy.isEmpty || model.sending)
                        }
                        if let error = model.accountErrors[account.id] { Text(error).font(.caption).foregroundStyle(.red) }
                        else if let date = account.lastSync { Text("Son eşitleme: \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if model.cache.accounts.isEmpty { Text("Henüz bağlı hesap yok.").foregroundStyle(.secondary) }
            }
            Section("Microsoft ile güvenli giriş") {
                Text("Şifren yalnızca Microsoft’un giriş sayfasına girilir. Sift kişisel Outlook ve Microsoft 365 hesaplarını destekler.").font(.callout)
                TextField("Application (client) ID", text: $model.cache.preferences.microsoftClientID).textFieldStyle(.roundedBorder).disabled(model.connecting)
                Text("Bu kimlik bir şifre değildir. Yayıncı Sift uygulama kaydını dağıtıma eklediğinde kullanıcıların bu alanı doldurması gerekmez.").font(.caption).foregroundStyle(.secondary)
                Link("Microsoft uygulama kaydı kurulum rehberi", destination: URL(string: "https://github.com/AliGaffarToksoy/Sift/blob/feature/outlook-notch/docs/OUTLOOK-SETUP.md") ?? URL(fileURLWithPath: "/"))
                if let authorization = model.authorization {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Microsoft sayfasına bu kodu gir").font(.headline)
                        HStack {
                            Text(authorization.user_code).font(.title2.monospaced().weight(.semibold)).textSelection(.enabled)
                            Button("Kopyala") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(authorization.user_code, forType: .string) }
                        }
                        ProgressView("Microsoft onayı bekleniyor…").controlSize(.small)
                        Button("İptal") { model.cancelLogin() }
                    }.padding(.vertical, 8)
                } else {
                    Button { model.connect() } label: { Label(model.connecting ? "Giriş hazırlanıyor…" : "Microsoft hesabı bağla", systemImage: "person.badge.plus") }
                        .buttonStyle(.borderedProminent).disabled(model.connecting || UUID(uuidString: model.cache.preferences.microsoftClientID.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                }
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            }
            Section {
                Toggle("Örnek postalarla demo modu", isOn: Binding(get: { model.demo }, set: { model.useDemo($0) }))
                Text("Demo, gerçek hesaplardan ayrı tutulur ve e-posta göndermez.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
        .confirmationDialog("Hesap bu Mac’ten kaldırılsın mı?", isPresented: Binding(get: { model.removingAccount != nil }, set: { if !$0 { model.removingAccount = nil } })) {
            Button("Hesabı ve yerel önbelleğini kaldır", role: .destructive) { if let account = model.removingAccount { model.disconnect(account) }; model.removingAccount = nil }
        } message: { Text("Microsoft’taki postaların korunur.") }
        .onDisappear { model.save() }
    }
}

struct ReplyComposer: View {
    @Environment(MailboxModel.self) private var model
    let message: MailMessage
    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 16) {
            Text("Yanıtla").font(.title2.weight(.semibold))
            Text("\(message.sender) · \(message.address)").foregroundStyle(.secondary)
            Text(message.subject).font(.headline)
            TextEditor(text: $model.replyText).font(.body).padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: 12)).disabled(model.sending)
            if model.sending {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(model.sendCountdown > 0 ? "\(model.sendCountdown) saniye içinde gönderilecek" : "Microsoft’a gönderiliyor…")
                    Spacer()
                    Button("Göndermeyi geri al") { model.undoSend() }.disabled(model.sendCountdown == 0)
                }
            } else {
                HStack {
                    Button("Vazgeç") { model.replyMessage = nil }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Gönder") { model.queueReply() }.buttonStyle(.borderedProminent)
                        .disabled(model.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.demo)
                }
            }
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
        }.padding(24).frame(width: 620, height: 470).interactiveDismissDisabled(model.sending)
    }
}

struct DailyBrief: View {
    @Environment(MailboxModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack { Text("Günün özeti").font(.largeTitle.weight(.semibold)); Spacer(); Button("Bitti") { dismiss() } }
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide)).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                metric("Önemli", count: model.messages.filter { $0.tier >= .important }.count, color: .orange)
                metric("Yanıt bekliyor olabilir", count: model.messages.filter(\.containsQuestion).count, color: .blue)
                metric("Bekleyebilir", count: model.messages.filter { $0.tier < .important }.count, color: .secondary)
            }
            ForEach(model.messages.filter { $0.tier >= .important }.prefix(4)) { message in
                Button { model.openMessage(message); dismiss() } label: { MessageRow(message: message, selected: false) }.buttonStyle(.plain)
            }
            Text("Yerel önem kurallarına göre · Bağlı hesapların gelen kutuları").font(.caption).foregroundStyle(.secondary)
        }.padding(32).frame(width: 680)
    }
    private func metric(_ title: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text("\(count)").font(.largeTitle.weight(.semibold)).foregroundStyle(color); Text(title).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }
}
