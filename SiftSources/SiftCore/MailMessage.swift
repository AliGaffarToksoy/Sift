import Foundation

public enum PriorityTier: Int, CaseIterable, Codable, Sendable, Comparable {
    case noise = 0, low, normal, important, critical

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .critical: "Critical"
        case .important: "Important"
        case .normal: "Normal"
        case .low: "Low"
        case .noise: "Noise"
        }
    }
}

public struct MailMessage: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var sender: String
    public var address: String
    public var subject: String
    public var preview: String
    public var body: String
    public var receivedAt: Date
    public var isUnread: Bool
    public var isDirect: Bool
    public var isReplyToMe: Bool
    public var isMailingList: Bool
    public var isNoReply: Bool
    public var containsDeadline: Bool
    public var containsQuestion: Bool
    public var tier: PriorityTier
    public var score: Int
    public var explanation: String
    public var summary: String

    public init(id: UUID = UUID(), sender: String, address: String, subject: String,
                preview: String, body: String, receivedAt: Date = .now, isUnread: Bool = true,
                isDirect: Bool = true, isReplyToMe: Bool = false, isMailingList: Bool = false,
                isNoReply: Bool = false, containsDeadline: Bool = false, containsQuestion: Bool = false,
                tier: PriorityTier = .normal, score: Int = 0, explanation: String = "",
                summary: String = "") {
        self.id = id; self.sender = sender; self.address = address; self.subject = subject
        self.preview = preview; self.body = body; self.receivedAt = receivedAt; self.isUnread = isUnread
        self.isDirect = isDirect; self.isReplyToMe = isReplyToMe; self.isMailingList = isMailingList
        self.isNoReply = isNoReply; self.containsDeadline = containsDeadline
        self.containsQuestion = containsQuestion; self.tier = tier; self.score = score
        self.explanation = explanation; self.summary = summary
    }
}

public struct PriorityScorer: Sendable {
    public init() {}

    public func score(_ message: MailMessage, vipAddresses: Set<String> = []) -> MailMessage {
        var result = message
        var points = 0
        var reasons: [String] = []
        if Set(vipAddresses.map { $0.lowercased() }).contains(message.address.lowercased()) { points += 42; reasons.append("Pinned sender") }
        if message.isDirect { points += 12; reasons.append("Sent directly to you") }
        if message.isReplyToMe { points += 28; reasons.append("Reply to a thread you started") }
        if message.containsQuestion { points += 15; reasons.append("Asks you a question") }
        if message.containsDeadline { points += 24; reasons.append("Mentions a deadline or date") }
        if message.isMailingList { points -= 25; reasons.append("Mailing list") }
        if message.isNoReply { points -= 18; reasons.append("Automated sender") }
        if ["security", "verification", "güvenlik", "doğrulama"].contains(where: { message.subject.localizedCaseInsensitiveContains($0) }) {
            points += 25; reasons.append("Security or verification message")
        }
        result.score = min(100, max(0, points))
        result.tier = points >= 65 ? .critical : points >= 35 ? .important : points >= 12 ? .normal : points >= 0 ? .low : .noise
        result.explanation = reasons.isEmpty ? "No urgent signals detected" : reasons.prefix(2).joined(separator: " · ")
        if result.summary.isEmpty { result.summary = String(message.preview.prefix(120)) }
        return result
    }
}

public enum DemoMailbox {
    public static func messages(now: Date = .now) -> [MailMessage] {
        let samples: [(String, String, String, String, String, Int, Bool, Bool, Bool)] = [
            ("Deniz Yılmaz", "deniz@example.com", "Can you review the launch plan today?", "The client needs our final notes before 16:00. Could you review the attached launch plan and send your edits?", "Client review is due today at 16:00.", 0, true, false, false),
            ("Maya Chen", "maya@example.com", "Re: Saturday in Kadıköy", "I booked the table for 19:30. Does that still work for you?", "Maya confirmed the reservation and asks if 19:30 works.", 1, true, true, false),
            ("Cloud Security", "alerts@cloud.example", "Security verification code", "Your sign-in code is 482 910. It expires in 10 minutes.", "One-time sign-in code expires in 10 minutes.", 2, true, false, false),
            ("Ece Demir", "ece@example.com", "Fatura taslağı", "Merhaba, son faturayı ekte paylaştım. Bugün göz atabilir misin?", "Ece bugün fatura taslağını incelemeni istiyor.", 4, true, false, false),
            ("Aylin from Studio", "aylin@studio.example", "The colors look great", "Thanks for the thoughtful notes. I made the small contrast change we discussed.", "Aylin applied the contrast adjustment.", 5, true, false, false),
            ("Field Notes", "digest@fieldnotes.example", "Your weekly design digest", "Five ideas for calmer interfaces, selected for you this week.", "This week’s design links are ready to browse.", 8, false, false, true),
            ("Northstar Travel", "no-reply@northstar.example", "Your flight receipt", "Istanbul to Copenhagen · 22 Nov · Booking Q8L4", "Flight receipt for Istanbul to Copenhagen on 22 November.", 12, false, false, false)
        ]
        return samples.map { item in
            let message = MailMessage(sender: item.0, address: item.1, subject: item.2,
                preview: item.3, body: item.3 + "\n\n" + item.4 + "\n\nThis is sample mail for Sift Demo Mode.",
                receivedAt: now.addingTimeInterval(-Double(item.5) * 3600), isUnread: item.5 < 5,
                isDirect: item.6, isReplyToMe: item.7, isMailingList: item.8,
                isNoReply: item.1.hasPrefix("no-reply"), containsDeadline: item.0 == "Deniz Yılmaz",
                containsQuestion: item.2.contains("?") || item.3.contains("?") , summary: item.4)
            return PriorityScorer().score(message, vipAddresses: ["deniz@example.com"])
        }.sorted { $0.score > $1.score }
    }
}
