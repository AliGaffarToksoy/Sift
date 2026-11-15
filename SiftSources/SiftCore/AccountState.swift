import Foundation

public struct MailAccount: Identifiable, Codable, Sendable {
    public var id: String
    public var address: String
    public var name: String
    public var clientID: String
    public var deltaLink: String?
    public var lastSync: Date?
    public init(id: String, address: String, name: String, clientID: String) {
        self.id = id; self.address = address; self.name = name; self.clientID = clientID
    }
}

public struct StoredMail: Identifiable, Codable, Sendable {
    public var id: UUID { message.id }
    public var accountID: String
    public var remoteID: String
    public var message: MailMessage
    public var snoozedUntil: Date?
    public var webLink: String?
    public init(accountID: String, remoteID: String, message: MailMessage, webLink: String? = nil) {
        self.accountID = accountID; self.remoteID = remoteID; self.message = message; self.webLink = webLink
    }
}

public struct SiftPreferences: Codable, Sendable {
    public var notchEnabled = true
    public var minimumTier: PriorityTier = .important
    public var alertDuration = 8.0
    public var expandOnHover = true
    public var hidePreview = false
    public var paused = false
    public var quietHours = false
    public var quietStart = 22
    public var quietEnd = 8
    public var vipAddresses: Set<String> = []
    public var mutedAddresses: Set<String> = []
    public var microsoftClientID = ""
    public init() {}
    public func permitsAlert(at date: Date, calendar: Calendar = .current) -> Bool {
        guard notchEnabled, !paused else { return false }
        guard quietHours else { return true }
        let hour = calendar.component(.hour, from: date)
        if quietStart == quietEnd { return false }
        return quietStart < quietEnd ? !(quietStart..<quietEnd).contains(hour) : !(hour >= quietStart || hour < quietEnd)
    }
}

public struct MailCache: Codable, Sendable {
    public var version = 1
    public var accounts: [MailAccount] = []
    public var mail: [StoredMail] = []
    public var preferences = SiftPreferences()
    public init() {}

    /// Apply a complete delta round atomically. Existing local IDs and snoozes survive updates.
    public mutating func apply(_ updates: [StoredMail], removed: Set<String>, accountID: String, reset: Bool) {
        let old = Dictionary(mail.filter { $0.accountID == accountID }.map { ($0.remoteID, $0) }, uniquingKeysWith: { a, _ in a })
        if reset { mail.removeAll { $0.accountID == accountID } }
        mail.removeAll { $0.accountID == accountID && removed.contains($0.remoteID) }
        for var update in updates {
            if let existing = old[update.remoteID] {
                update.message = update.message.withID(existing.id)
                update.snoozedUntil = existing.snoozedUntil
            }
            if let index = mail.firstIndex(where: { $0.accountID == accountID && $0.remoteID == update.remoteID }) {
                mail[index] = update
            } else { mail.append(update) }
        }
    }
}

extension MailMessage {
    func withID(_ id: UUID) -> Self {
        var result = self
        result.id = id
        return result
    }
}

public enum GraphSafety {
    public static func validatedURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme == "https", url.host == "graph.microsoft.com",
              url.user == nil, url.password == nil, url.port == nil || url.port == 443,
              url.path.hasPrefix("/v1.0/") else { return nil }
        return url
    }
    public static func pathSegment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
    }
}
