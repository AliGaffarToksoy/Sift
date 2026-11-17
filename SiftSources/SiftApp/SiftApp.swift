import SwiftUI
import Observation
import SiftCore

@main
struct SiftApp: App {
    private let model = MailboxModel()

    var body: some Scene {
        WindowGroup("Sift", id: "mail") {
            MailWindow()
                .environment(model)
                .frame(minWidth: 1040, minHeight: 680)
                .task { model.start() }
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Eşitle") { Task { await model.sync() } }.keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Çentik önizlemesi") { model.previewNotch() }.keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
        Settings { SiftSettings().environment(model) }

        MenuBarExtra {
            MenuBarPeek().environment(model)
        } label: {
            Label("Sift", systemImage: "tray.full")
        }
        .menuBarExtraStyle(.window)
    }
}

enum SiftPalette {
    static func accent(for tier: PriorityTier) -> Color {
        switch tier {
        case .critical: .red
        case .important: .orange
        case .normal: .secondary
        case .low: .gray
        case .noise: .gray.opacity(0.6)
        }
    }
}

struct MailWindow: View {
    @Environment(MailboxModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 188, ideal: 210, max: 250)
        } content: {
            messageList
                .navigationSplitViewColumnWidth(min: 330, ideal: 410, max: 520)
        } detail: {
            if !model.demo && model.cache.accounts.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "tray.2.fill").font(.system(size: 56)).foregroundStyle(.orange.gradient)
                    Text("Gürültü azalsın. Önemli olan kalsın.").font(.title.weight(.semibold))
                    Text("Outlook hesabını bağla. Sift önemli postalarını bu Mac’te sıralasın,\nçentik yalnızca dikkatini hak edenler için açılsın.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Microsoft hesabı bağla") { model.showAccounts = true }.buttonStyle(.glassProminent)
                    Button("Örnek postalarla keşfet") { model.useDemo(true) }.buttonStyle(.plain)
                    Label("Yerel önbellek · Anahtar Zinciri · Takip görseli yok", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
                }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else if let message = model.selectedMessage { ReaderView(message: message) }
            else { ContentUnavailableView("Gelen kutun temiz", systemImage: "checkmark.circle", description: Text("Şu anda bekleyen bir posta yok.")) }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { Task { await model.sync() } } label: { Label("Eşitle", systemImage: "arrow.triangle.2.circlepath") }.disabled(model.syncing || model.demo)
                Button { model.showBrief = true } label: { Label("Günün özeti", systemImage: "sun.max") }
                Button { model.previewNotch() } label: { Label("Çentik önizlemesi", systemImage: "bell.badge") }
                SettingsLink { Image(systemName: "gearshape") }
                Button { model.showGallery.toggle() } label: { Image(systemName: "square.grid.2x2") }
                    .help("Design Gallery")
                Button { if let message = model.selectedMessage { model.archive(message) } } label: {
                    Label("Arşivle", systemImage: "archivebox")
                }.keyboardShortcut("e", modifiers: [.command]).disabled(model.selectedMessage == nil || model.syncing || !model.busy.isEmpty)
            }
        }
        .searchable(text: $model.query, placement: .toolbar, prompt: "Postalarda ara")
        .sheet(isPresented: $model.showGallery) { DesignGallery() }
        .sheet(isPresented: $model.showAccounts) {
            VStack { HStack { Text("Hesaplar").font(.title2.weight(.semibold)); Spacer(); Button("Bitti") { model.showAccounts = false } }.padding(); AccountSettings() }.frame(width: 640, height: 620)
        }
        .sheet(isPresented: $model.showBrief) { DailyBrief() }
        .sheet(item: $model.replyMessage) { ReplyComposer(message: $0) }
        .safeAreaInset(edge: .bottom) {
            if let error = model.error, !model.showAccounts {
                HStack { Image(systemName: "exclamationmark.triangle"); Text(error).font(.caption); Spacer(); Button("Kapat") { model.error = nil } }.padding(12).background(.orange.opacity(0.12))
            }
        }
        .onChange(of: model.activeMailbox) { _, _ in model.selectedID = model.visibleMessages.first?.id }
    }

    private var sidebar: some View {
        List {
            Section("Akıllı posta kutuları") {
                mailbox("All", symbol: "tray.full")
                mailbox("Priority", symbol: "sparkles", count: model.messages.filter { $0.tier >= .important }.count)
                mailbox("Today", symbol: "sun.max")
                mailbox("Needs Reply", symbol: "arrowshape.turn.up.left")
                mailbox("Newsletters", symbol: "newspaper")
                mailbox("Snoozed", symbol: "clock")
                mailbox("VIP", symbol: "star")
            }
            Section("Hesaplar") {
                if model.demo { Label("Örnek posta kutusu", systemImage: "tray.full") }
                ForEach(model.cache.accounts) { account in
                    Button { model.showAccounts = true } label: { Label(account.address, systemImage: model.accountErrors[account.id] == nil ? "envelope" : "exclamationmark.triangle") }.buttonStyle(.plain)
                }
                Button { model.showAccounts = true } label: { Label("Hesap ekle…", systemImage: "plus.circle") }.buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Circle().fill(model.accountErrors.isEmpty ? .green : .orange).frame(width: 7, height: 7)
                Text(model.demo ? "Demo · Örnek postalar" : model.syncing ? "Eşitleniyor…" : model.status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.tertiary)
            }.padding(16)
        }
    }

    private func mailbox(_ title: String, symbol: String, count: Int? = nil) -> some View {
        Button { model.activeMailbox = title } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol).foregroundStyle(title == "Priority" ? .orange : .secondary).frame(width: 18)
                Text(mailboxTitle(title))
                Spacer(minLength: 4)
                if let count, count > 0 { Text("\(count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).listRowBackground(model.activeMailbox == title ? Color.accentColor.opacity(0.12) : .clear)
    }

    private var messageList: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mailboxTitle(model.activeMailbox)).font(.title2.weight(.semibold))
                    Text(model.activeMailbox == "Snoozed" ? "Bu Mac’te ertelenenler" : "Önem sırasına göre").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(model.visibleMessages.count)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
            }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
            if model.visibleMessages.isEmpty {
                ContentUnavailableView("Her şey sakin", systemImage: "checkmark.circle", description: Text("Burada dikkatini bekleyen bir posta yok."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(model.visibleMessages) { message in
                            Button { model.select(message) } label: { MessageRow(message: message, selected: model.selectedID == message.id) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(message.sender), \(message.subject), \(message.tier.title)")
                        }
                    }.padding(.horizontal, 8).padding(.bottom, 24)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

struct MessageRow: View {
    let message: MailMessage
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(SiftPalette.accent(for: message.tier).opacity(0.14))
                Text(String(message.sender.prefix(1))).font(.headline).foregroundStyle(SiftPalette.accent(for: message.tier))
            }.frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(message.sender).font(.subheadline.weight(message.isUnread ? .semibold : .regular)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(message.receivedAt, style: .relative).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).lineLimit(1)
                }
                Text(message.subject).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(message.preview).font(.caption).foregroundStyle(.secondary).lineLimit(2).lineSpacing(2)
                HStack(spacing: 5) {
                    Image(systemName: message.tier >= .important ? "arrow.up.right" : "circle.fill").font(.system(size: 8, weight: .bold))
                    Text(message.tier.title).font(.caption2.weight(.medium))
                    Text("·").foregroundStyle(.tertiary)
                    Text(message.explanation).font(.caption2).lineLimit(1)
                }.foregroundStyle(SiftPalette.accent(for: message.tier))
            }
            if message.isUnread { Circle().fill(Color.accentColor).frame(width: 7, height: 7).padding(.top, 5) }
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(selected ? Color.accentColor.opacity(0.11) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ReaderView: View {
    let message: MailMessage
    @Environment(MailboxModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Label(message.tier.title, systemImage: message.tier >= .important ? "sparkle" : "circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(SiftPalette.accent(for: message.tier))
                Text(message.explanation).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { model.archive(message) } label: { Label("Arşivle", systemImage: "archivebox") }
                    .buttonStyle(.bordered).keyboardShortcut("e", modifiers: [.command])
                Menu {
                    Button("Göndereni VIP yap") { model.prefer(message) }
                    Button("Göndereni sessize al") { model.prefer(message, mute: true) }
                } label: { Image(systemName: "ellipsis") }
            }.padding(.horizontal, 28).padding(.vertical, 18)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(message.subject).font(.largeTitle.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        Text(String(message.sender.prefix(1))).font(.headline).frame(width: 40, height: 40)
                            .background(Color.accentColor.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.sender).font(.subheadline.weight(.semibold))
                            Text(message.address).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(message.receivedAt, format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkle").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Kısa önizleme · Bu Mac’te").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(message.summary).font(.callout)
                        }
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text(message.body).font(.body).lineSpacing(6).textSelection(.enabled)
                    Spacer(minLength: 40)
                    HStack {
                        Button { model.reply(message) } label: { Label("Yanıtla", systemImage: "arrowshape.turn.up.left") }.buttonStyle(.borderedProminent).keyboardShortcut("r", modifiers: [.command])
                        Button { model.snooze(message) } label: { Label(model.activeMailbox == "Snoozed" ? "Ertelemeyi kaldır" : "1 saat ertele", systemImage: "clock") }.buttonStyle(.bordered)
                        Button { model.prefer(message) } label: { Label("VIP yap", systemImage: "star") }.buttonStyle(.bordered)
                    }
                }.padding(32).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .topLeading)
            }.scrollEdgeEffectStyle(.soft, for: .top)
        }.background(Color(nsColor: .textBackgroundColor))
    }
}

struct DesignGallery: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack { VStack(alignment: .leading, spacing: 4) { Text("Design Gallery").font(.largeTitle.weight(.semibold)); Text("Sift’s components, states, and priority language.").foregroundStyle(.secondary) }; Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
            Text("Priority").font(.title3.weight(.semibold))
            HStack(spacing: 10) {
                ForEach(PriorityTier.allCases.reversed(), id: \.self) { tier in
                    Label(tier.title, systemImage: tier >= .important ? "sparkle" : "circle.fill")
                        .font(.caption.weight(.medium)).foregroundStyle(SiftPalette.accent(for: tier))
                        .padding(.horizontal, 11).padding(.vertical, 7).background(SiftPalette.accent(for: tier).opacity(0.1), in: Capsule())
                }
            }
            Text("Message row").font(.title3.weight(.semibold))
            VStack(spacing: 4) { ForEach(DemoMailbox.messages().prefix(3)) { MessageRow(message: $0, selected: $0.tier == .critical) } }
                .padding(8).background(Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text("Floating controls").font(.title3.weight(.semibold))
            HStack(spacing: 10) {
                Button {} label: { Label("Arşivle", systemImage: "archivebox") }.buttonStyle(.glass)
                Button {} label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }.buttonStyle(.glassProminent)
                Label("⌘ E", systemImage: "keyboard").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(28).frame(width: 680, height: 610).background(Color(nsColor: .windowBackgroundColor))
    }
}

struct MenuBarPeek: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(MailboxModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Sift").font(.headline); Spacer(); Text("\(model.messages.count) messages").font(.caption).foregroundStyle(.secondary) }
            ForEach(model.messages.prefix(3)) { message in
                HStack(spacing: 8) {
                    Circle().fill(SiftPalette.accent(for: message.tier)).frame(width: 7, height: 7)
                    VStack(alignment: .leading) { Text(message.sender).font(.caption.weight(.semibold)); Text(message.subject).font(.caption).lineLimit(1).foregroundStyle(.secondary) }
                }
            }
            Divider()
            Text(model.demo ? "Demo · Örnek postalar" : "Outlook · Yerel önbellek").font(.caption2).foregroundStyle(.tertiary)
            Button("Sift’i aç") { openWindow(id: "mail"); NSApp.activate(ignoringOtherApps: true) }.buttonStyle(.glassProminent)
            Button(model.cache.preferences.paused ? "Bildirimleri sürdür" : "Bildirimleri duraklat") {
                model.cache.preferences.paused.toggle(); model.save()
                if model.cache.preferences.paused { model.notch?.hide() }
            }.font(.caption)
        }.padding(14).frame(width: 270)
    }
}

func mailboxTitle(_ key: String) -> String {
    switch key {
    case "All": "Gelen kutusu"
    case "Priority": "Önemli"
    case "Today": "Bugün"
    case "Needs Reply": "Yanıt bekleyenler"
    case "Newsletters": "Bültenler"
    case "Snoozed": "Ertelenenler"
    default: key
    }
}
