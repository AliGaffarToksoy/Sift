import AppKit
import SwiftUI
import Observation
import SiftCore

@Observable @MainActor
final class MailboxModel {
    var cache = MailCache()
    var demo = false
    var demoMessages = DemoMailbox.messages()
    var selectedID: UUID?
    var query = ""
    var activeMailbox = "Priority"
    var showGallery = false
    var showAccounts = false
    var removingAccount: MailAccount?
    var showBrief = false
    var error: String?
    var accountErrors: [String: String] = [:]
    var syncing = false
    var busy: Set<UUID> = []
    var authorization: DeviceAuthorization?
    var connecting = false
    var replyMessage: MailMessage?
    var replyText = ""
    var sendCountdown = 0
    var sending = false
    var status = "Hesabını bağla veya demoyu keşfet"
    @ObservationIgnored private let provider = MicrosoftMail()
    @ObservationIgnored private var store: LocalStore?
    @ObservationIgnored private var polling: Task<Void, Never>?
    @ObservationIgnored private var login: Task<Void, Never>?
    @ObservationIgnored private var sendTask: Task<Void, Never>?
    @ObservationIgnored var notch: NotchController?
    @ObservationIgnored private var started = false

    init() {
        do {
            let store = try LocalStore()
            cache = try store.load(); self.store = store
            if cache.preferences.microsoftClientID.isEmpty {
                cache.preferences.microsoftClientID = Bundle.main.object(forInfoDictionaryKey: "SiftMicrosoftClientID") as? String ?? ""
            }
            selectedID = messages.first?.id
        } catch { self.error = "Yerel veriler okunamadı; üzerine yazılmayacak. \(error.localizedDescription)" }
    }
    var messages: [MailMessage] {
        let list = demo ? demoMessages : cache.mail.filter { $0.snoozedUntil == nil || ($0.snoozedUntil ?? .distantPast) <= .now }.map(\.message)
        return list.sorted { $0.score == $1.score ? $0.receivedAt > $1.receivedAt : $0.score > $1.score }
    }
    var selectedMessage: MailMessage? { visibleMessages.first { $0.id == selectedID } }
    var visibleMessages: [MailMessage] {
        var list = messages
        switch activeMailbox {
        case "Priority": list = list.filter { $0.tier >= .important }
        case "Needs Reply": list = list.filter { $0.containsQuestion || $0.isReplyToMe }
        case "Newsletters": list = list.filter(\.isMailingList)
        case "Today": list = list.filter { Calendar.current.isDateInToday($0.receivedAt) }
        case "VIP": list = list.filter { cache.preferences.vipAddresses.contains($0.address.lowercased()) }
        case "Snoozed": list = demo ? [] : cache.mail.filter { ($0.snoozedUntil ?? .distantPast) > .now }.map(\.message)
        default: break
        }
        return list.filter { query.isEmpty || ($0.sender + " " + $0.subject + " " + $0.preview).localizedCaseInsensitiveContains(query) }
    }
    func start() {
        guard !started else { return }; started = true
        notch = NotchController(model: self)
        polling = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync()
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
            }
        }
    }
    func save() {
        guard let store else { return }
        do { try store.save(cache) } catch { self.error = "Yerel değişiklik kaydedilemedi: \(error.localizedDescription)" }
    }
    func useDemo(_ enabled: Bool) {
        demo = enabled; activeMailbox = "Priority"; selectedID = visibleMessages.first?.id
        notch?.hide()
    }
    func connect() {
        guard !connecting, store != nil else { return }
        let clientID = cache.preferences.microsoftClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        connecting = true; authorization = nil; error = nil
        login = Task { [weak self] in
            guard let self else { return }
            defer { connecting = false; authorization = nil }
            do {
                let auth = try await provider.begin(clientID: clientID)
                try Task.checkCancellation()
                authorization = auth
                if let url = URL(string: auth.verification_uri), url.scheme == "https", ["microsoft.com", "www.microsoft.com", "login.microsoftonline.com"].contains(url.host ?? "") {
                    NSWorkspace.shared.open(url)
                }
                let account = try await provider.finish(auth, clientID: clientID)
                if let index = cache.accounts.firstIndex(where: { $0.id == account.id }) {
                    var replacement = account
                    replacement.deltaLink = cache.accounts[index].deltaLink
                    replacement.lastSync = cache.accounts[index].lastSync
                    cache.accounts[index] = replacement
                } else { cache.accounts.append(account) }
                cache.preferences.microsoftClientID = clientID
                demo = false; save(); showAccounts = false
                await sync()
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
    func cancelLogin() { login?.cancel() }
    func disconnect(_ account: MailAccount) {
        guard !syncing, busy.isEmpty, !sending else { return }
        Task {
            do {
                try await provider.disconnect(account)
                cache.accounts.removeAll { $0.id == account.id }; cache.mail.removeAll { $0.accountID == account.id }
                accountErrors[account.id] = nil; notch?.hide(); save()
                selectedID = visibleMessages.first?.id
            } catch { self.error = error.localizedDescription }
        }
    }
    func sync() async {
        guard !syncing, busy.isEmpty, !demo, !cache.accounts.isEmpty, let store else { return }
        syncing = true
        defer { syncing = false }
        for account in cache.accounts {
            do {
                let previous = Set(cache.mail.filter { $0.accountID == account.id }.map(\.remoteID))
                let syncBegan = Date.now
                let result = try await provider.sync(account, vip: cache.preferences.vipAddresses)
                var next = cache
                next.apply(result.updates, removed: result.removed, accountID: account.id, reset: result.reset)
                guard let index = next.accounts.firstIndex(where: { $0.id == account.id }) else { continue }
                next.accounts[index].deltaLink = result.cursor; next.accounts[index].lastSync = .now
                for i in next.mail.indices where next.preferences.mutedAddresses.contains(next.mail[i].message.address.lowercased()) {
                    next.mail[i].message.tier = .noise; next.mail[i].message.score = 0; next.mail[i].message.explanation = "Bu gönderen sessize alındı"
                }
                try store.save(next); cache = next; accountErrors[account.id] = nil
                if !demo, !result.reset, let last = account.lastSync {
                    let fresh = result.updates.filter {
                        !previous.contains($0.remoteID) && $0.message.isUnread && $0.message.receivedAt >= last.addingTimeInterval(-120)
                        && $0.message.receivedAt <= syncBegan.addingTimeInterval(120)
                        && $0.message.tier >= cache.preferences.minimumTier
                        && !cache.preferences.mutedAddresses.contains($0.message.address.lowercased())
                    }.map(\.message).sorted { $0.score > $1.score }
                    notch?.notify(fresh)
                }
            } catch is CancellationError { return }
            catch { accountErrors[account.id] = error.localizedDescription }
        }
        if selectedID == nil { selectedID = visibleMessages.first?.id }
        status = accountErrors.isEmpty ? "Güncel · Veriler bu Mac’te" : "Bağlantıyı kontrol et · Hesaplar"
    }
    func select(_ message: MailMessage) {
        selectedID = message.id
        guard message.isUnread else { return }
        if demo { if let i = demoMessages.firstIndex(where: { $0.id == message.id }) { demoMessages[i].isUnread = false }; return }
        perform(message, action: "read")
    }
    func archive(_ message: MailMessage) {
        if demo { demoMessages.removeAll { $0.id == message.id }; selectedID = visibleMessages.first?.id; return }
        perform(message, action: "archive")
    }
    private func perform(_ message: MailMessage, action: String) {
        guard !busy.contains(message.id), !syncing,
              let mail = cache.mail.first(where: { $0.id == message.id }),
              let account = cache.accounts.first(where: { $0.id == mail.accountID }) else { return }
        busy.insert(message.id)
        Task {
            defer { busy.remove(message.id) }
            do {
                try await provider.mutate(mail, account: account, action: action)
                if action == "archive" { cache.mail.removeAll { $0.id == message.id }; notch?.remove(message.id) }
                else if let i = cache.mail.firstIndex(where: { $0.id == message.id }) { cache.mail[i].message.isUnread = false }
                save()
                if selectedID == message.id && action == "archive" { selectedID = visibleMessages.first?.id }
            } catch { self.error = error.localizedDescription }
        }
    }
    func snooze(_ message: MailMessage) {
        if demo { demoMessages.removeAll { $0.id == message.id } }
        else if let i = cache.mail.firstIndex(where: { $0.id == message.id }) {
            cache.mail[i].snoozedUntil = activeMailbox == "Snoozed" ? nil : .now.addingTimeInterval(3600); save()
        }
        notch?.remove(message.id); selectedID = visibleMessages.first?.id
    }
    func prefer(_ message: MailMessage, mute: Bool = false) {
        let address = message.address.lowercased()
        if mute { cache.preferences.mutedAddresses.insert(address); cache.preferences.vipAddresses.remove(address) }
        else { cache.preferences.vipAddresses.insert(address); cache.preferences.mutedAddresses.remove(address) }
        for i in cache.mail.indices where cache.mail[i].message.address.lowercased() == address {
            cache.mail[i].message = PriorityScorer().score(cache.mail[i].message, vipAddresses: cache.preferences.vipAddresses)
            if mute { cache.mail[i].message.tier = .noise; cache.mail[i].message.score = 0; cache.mail[i].message.explanation = "Bu gönderen sessize alındı" }
        }
        if demo { demoMessages = demoMessages.map { PriorityScorer().score($0, vipAddresses: cache.preferences.vipAddresses) } }
        if mute { notch?.remove(message.id) }; save()
    }
    func openMessage(_ message: MailMessage) {
        activeMailbox = "All"; select(message)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.identifier?.rawValue == "mail" || ($0.canBecomeMain && !($0 is NSPanel)) })?.makeKeyAndOrderFront(nil)
        notch?.hide()
    }
    func reply(_ message: MailMessage) { openMessage(message); replyText = ""; replyMessage = message }
    func queueReply() {
        guard let message = replyMessage, !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !sending else { return }
        if demo { error = "Demo modunda e-posta gönderilmez."; return }
        guard let mail = cache.mail.first(where: { $0.id == message.id }), let account = cache.accounts.first(where: { $0.id == mail.accountID }) else { return }
        let text = replyText
        sending = true
        sendTask = Task {
            defer { sending = false; sendCountdown = 0 }
            do {
                for second in (1...10).reversed() { sendCountdown = second; try await Task.sleep(for: .seconds(1)) }
                sendCountdown = 0
                try await provider.mutate(mail, account: account, action: "reply", text: text)
                replyMessage = nil; replyText = ""; status = "Yanıt Microsoft’a gönderildi"
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
    func undoSend() { guard sendCountdown > 0 else { return }; sendTask?.cancel() }
    func previewNotch() { start(); notch?.notify(Array(DemoMailbox.messages().prefix(3)), preview: true) }
}
