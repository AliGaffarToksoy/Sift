import XCTest
@testable import SiftCore

final class PriorityScorerTests: XCTestCase {
    func testVIPDeadlineAndDirectRequestAreCriticalAndExplainable() {
        let message = MailMessage(sender: "Deniz", address: "deniz@example.com", subject: "Review",
            preview: "Please review this today", body: "", isDirect: true,
            containsDeadline: true, containsQuestion: true)
        let result = PriorityScorer().score(message, vipAddresses: ["deniz@example.com"])
        XCTAssertEqual(result.tier, .critical)
        XCTAssertEqual(result.score, 93)
        XCTAssertTrue(result.explanation.contains("Pinned sender"))
        XCTAssertFalse(result.summary.isEmpty)
    }

    func testAutomatedNewsletterIsDownranked() {
        let message = MailMessage(sender: "Digest", address: "digest@example.com", subject: "Weekly",
            preview: "Your weekly digest", body: "", isDirect: false, isMailingList: true, isNoReply: true)
        let result = PriorityScorer().score(message)
        XCTAssertEqual(result.tier, .noise)
        XCTAssertEqual(result.score, 0)
        XCTAssertTrue(result.explanation.contains("Mailing list"))
    }
}
