import XCTest
@testable import ClaudeMon

final class CookieExtractorTests: XCTestCase {
    private func cookie(name: String, domain: String, value: String = "v") -> HTTPCookie {
        HTTPCookie(properties: [
            .name: name, .value: value, .domain: domain, .path: "/",
        ])!
    }

    func testMatchesExactDomain() {
        XCTAssertTrue(CookieExtractor.matches(cookie(name: "sessionKey", domain: "claude.ai")))
    }
    func testMatchesLeadingDot() {
        XCTAssertTrue(CookieExtractor.matches(cookie(name: "sessionKey", domain: ".claude.ai")))
    }
    func testMatchesSubdomain() {
        XCTAssertTrue(CookieExtractor.matches(cookie(name: "sessionKey", domain: "api.claude.ai")))
    }
    func testRejectsWrongName() {
        XCTAssertFalse(CookieExtractor.matches(cookie(name: "other", domain: "claude.ai")))
    }
    func testRejectsForeignDomain() {
        XCTAssertFalse(CookieExtractor.matches(cookie(name: "sessionKey", domain: "evil.example")))
    }
    func testRejectsLookalikeDomain() {
        // "fakeclaude.ai" must not match — ensures we don't substring-match.
        XCTAssertFalse(CookieExtractor.matches(cookie(name: "sessionKey", domain: "fakeclaude.ai")))
    }

    func testRejectsBadPrefix() {
        // Defends against truncation / future cookie-name reuse: if the value
        // doesn't start with sk-ant-sid01-, we must not commit it to Keychain.
        XCTAssertNil(CookieExtractor.validate(value: "not-a-real-key"))
        XCTAssertNil(CookieExtractor.validate(value: ""))
        XCTAssertNil(CookieExtractor.validate(value: "sk-ant-sid02-newscheme"))
    }

    func testValidateAcceptsAndTrimsGoodValue() {
        let raw = "  sk-ant-sid01-deadbeef  \n"
        XCTAssertEqual(CookieExtractor.validate(value: raw), "sk-ant-sid01-deadbeef")
    }
}
