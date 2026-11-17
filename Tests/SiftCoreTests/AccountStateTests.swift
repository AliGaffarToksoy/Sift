import XCTest
@testable import SiftCore

final class AccountStateTests: XCTestCase {
    private func mail(_ remote: String, account: String = "a", subject: String = "Hello") -> StoredMail {
        StoredMail(accountID: account, remoteID: remote, message: MailMessage(sender: "Sender", address: "sender@example.com", subject: subject, preview: "Preview", body: "Body"))
    }
    func testDeltaPreservesIdentityAndLocalSnooze() {
        var cache = MailCache()
        var original = mail("one"); original.snoozedUntil = Date(timeIntervalSince1970: 1000)
        cache.mail = [original]
        cache.apply([mail("one", subject: "Updated")], removed: [], accountID: "a", reset: false)
        XCTAssertEqual(cache.mail.count, 1)
        XCTAssertEqual(cache.mail[0].id, original.id)
        XCTAssertEqual(cache.mail[0].snoozedUntil, original.snoozedUntil)
        XCTAssertEqual(cache.mail[0].message.subject, "Updated")
    }
    func testResetAndDeletionAreAccountScoped() {
        var cache = MailCache()
        cache.mail = [mail("same"), mail("same", account: "b"), mail("old")]
        cache.apply([mail("new")], removed: ["same"], accountID: "a", reset: true)
        XCTAssertEqual(Set(cache.mail.map(\.remoteID)), ["same", "new"])
        XCTAssertTrue(cache.mail.contains { $0.accountID == "b" })
    }
    func testDuplicateDeltaUpdatesAreIdempotent() {
        var cache = MailCache()
        let update = mail("one")
        cache.apply([update, update], removed: [], accountID: "a", reset: false)
        cache.apply([update], removed: [], accountID: "a", reset: false)
        XCTAssertEqual(cache.mail.count, 1)
    }
    func testGraphLinksCannotExfiltrateTokens() {
        XCTAssertNotNil(GraphSafety.validatedURL("https://graph.microsoft.com/v1.0/me/messages?$skiptoken=opaque"))
        for url in ["https://graph.microsoft.com.evil.test/v1.0/me", "http://graph.microsoft.com/v1.0/me", "https://evil.test/v1.0/me", "https://user@graph.microsoft.com/v1.0/me", "https://graph.microsoft.com:8443/v1.0/me", "https://graph.microsoft.com/beta/me"] {
            XCTAssertNil(GraphSafety.validatedURL(url))
        }
        XCTAssertFalse(GraphSafety.pathSegment("id/with?query").contains("/"))
    }
    func testQuietHoursWrapMidnightAndBoundaries() {
        var preferences = SiftPreferences(); preferences.quietHours = true
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        for (hour, allowed) in [(21, true), (22, false), (0, false), (7, false), (8, true)] {
            let date = Date(timeIntervalSince1970: TimeInterval(hour * 3600))
            XCTAssertEqual(preferences.permitsAlert(at: date, calendar: calendar), allowed)
        }
        preferences.quietStart = 9; preferences.quietEnd = 17
        XCTAssertFalse(preferences.permitsAlert(at: Date(timeIntervalSince1970: 12 * 3600), calendar: calendar))
        preferences.quietStart = 17
        XCTAssertFalse(preferences.permitsAlert(at: .now, calendar: calendar))
        preferences.quietHours = false; preferences.paused = true
        XCTAssertFalse(preferences.permitsAlert(at: .now))
    }
    func testGraphPlainTextAndTurkishSignals() throws {
        let json = #"{"id":"mail-1","subject":"Bugün inceleyebilir misin?","bodyPreview":"Bugün gerekli","body":{"contentType":"text","content":"Merhaba, bugün yanıtlar mısın?"},"from":{"emailAddress":{"name":"Ece","address":"ece@example.com"}},"toRecipients":[{"emailAddress":{"address":"ME@EXAMPLE.COM"}}],"receivedDateTime":"2026-11-15T12:00:00.123Z","isRead":false}"#
        let remote = try JSONDecoder().decode(GraphMessage.self, from: Data(json.utf8))
        let account = MailAccount(id: "a", address: "me@example.com", name: "Me", clientID: "")
        let message = remote.stored(account: account, vip: []).message
        XCTAssertTrue(message.isDirect); XCTAssertTrue(message.containsDeadline); XCTAssertTrue(message.containsQuestion)
        XCTAssertEqual(message.tier, .important); XCTAssertTrue(message.body.hasPrefix("Merhaba"))
        XCTAssertGreaterThan(message.receivedAt, .distantPast)
    }
    func testHTMLIsNeverRenderedAsBody() throws {
        let json = #"{"id":"1","bodyPreview":"Safe preview","body":{"contentType":"html","content":"<img src='https://tracker.test'>"}}"#
        let remote = try JSONDecoder().decode(GraphMessage.self, from: Data(json.utf8))
        XCTAssertEqual(remote.stored(account: MailAccount(id: "a", address: "a", name: "A", clientID: ""), vip: []).message.body, "Safe preview")
    }
    func testCacheRoundTrip() throws {
        var cache = MailCache(); cache.mail = [mail("one")]
        cache.accounts = [MailAccount(id: "a", address: "a@example.com", name: "A", clientID: "public-id")]
        cache.accounts[0].deltaLink = "https://graph.microsoft.com/v1.0/me/delta"
        let data = try JSONEncoder().encode(cache)
        let copy = try JSONDecoder().decode(MailCache.self, from: data)
        XCTAssertEqual(copy.mail[0].id, cache.mail[0].id)
        XCTAssertEqual(copy.accounts[0].deltaLink, cache.accounts[0].deltaLink)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("refreshToken"))
    }
}
