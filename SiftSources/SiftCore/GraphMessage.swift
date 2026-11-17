import Foundation

public struct GraphMessage: Decodable, Sendable {
    public struct Recipient: Decodable, Sendable {
        public struct Address: Decodable, Sendable { public var name: String?; public var address: String? }
        public var emailAddress: Address
    }
    public struct Body: Decodable, Sendable { public var contentType: String?; public var content: String? }
    public struct Header: Decodable, Sendable { public var name: String; public var value: String }
    public struct Removed: Decodable, Sendable {}
    public var id: String
    public var subject: String?
    public var bodyPreview: String?
    public var body: Body?
    public var from: Recipient?
    public var toRecipients: [Recipient]?
    public var receivedDateTime: String?
    public var isRead: Bool?
    public var importance: String?
    public var webLink: String?
    public var internetMessageHeaders: [Header]?
    public var removed: Removed?
    enum CodingKeys: String, CodingKey {
        case id, subject, bodyPreview, body, from, toRecipients, receivedDateTime, isRead, importance, webLink, internetMessageHeaders
        case removed = "@removed"
    }
    public func stored(account: MailAccount, vip: Set<String>) -> StoredMail {
        let address = from?.emailAddress.address ?? ""
        let preview = bodyPreview ?? ""
        // Graph is requested with outlook.body-content-type=text. Never render HTML or load remote resources.
        let text = body?.contentType?.lowercased() == "text" ? (body?.content ?? preview) : preview
        let signals = ((subject ?? "") + " " + preview).lowercased()
        let deadlines = ["today", "tomorrow", "deadline", "due by", "bugün", "yarın", "son tarih"]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: receivedDateTime ?? "") ?? ISO8601DateFormatter().date(from: receivedDateTime ?? "") ?? .distantPast
        var message = MailMessage(sender: from?.emailAddress.name ?? address, address: address,
            subject: subject ?? "(Konu yok)", preview: preview, body: text, receivedAt: date,
            isUnread: !(isRead ?? false),
            isDirect: toRecipients?.contains { $0.emailAddress.address?.lowercased() == account.address.lowercased() } ?? false,
            isMailingList: internetMessageHeaders?.contains { $0.name.lowercased() == "list-unsubscribe" || $0.name.lowercased() == "list-id" } ?? false,
            isNoReply: ["no-reply", "noreply", "do-not-reply"].contains { address.lowercased().contains($0) },
            containsDeadline: deadlines.contains { signals.contains($0) }, containsQuestion: signals.contains("?"))
        message = PriorityScorer().score(message, vipAddresses: vip)
        if importance == "high", message.tier < .important {
            message.tier = .important; message.score = max(35, message.score)
            message.explanation = "Gönderen yüksek önem işareti koydu · " + message.explanation
        }
        return StoredMail(accountID: account.id, remoteID: id, message: message, webLink: webLink)
    }
}

public struct GraphDeltaPage: Decodable, Sendable {
    public var value: [GraphMessage]
    public var nextLink: String?
    public var deltaLink: String?
    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
        case deltaLink = "@odata.deltaLink"
    }
}
