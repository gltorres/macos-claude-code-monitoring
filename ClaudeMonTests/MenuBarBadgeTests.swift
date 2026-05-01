import XCTest
import AppKit
@testable import ClaudeMon

final class MenuBarBadgeTests: XCTestCase {

    func testNilReturnsBareBolt() {
        let img = MenuBarBadge.compose(percent: nil, resetsAt: nil)
        XCTAssertTrue(img.isTemplate)
        XCTAssertLessThanOrEqual(img.size.width, img.size.height + 4)
    }

    func testBelowThresholdReturnsBareBolt() {
        let img = MenuBarBadge.compose(percent: MenuBarBadge.showThreshold - 1, resetsAt: nil)
        XCTAssertTrue(img.isTemplate)
        XCTAssertLessThanOrEqual(img.size.width, img.size.height + 4)
    }

    func testAtThresholdReturnsComposedImage() {
        let bare = MenuBarBadge.compose(percent: nil, resetsAt: nil)
        let composed = MenuBarBadge.compose(percent: MenuBarBadge.showThreshold, resetsAt: nil)
        XCTAssertTrue(composed.isTemplate)
        XCTAssertGreaterThan(composed.size.width, bare.size.width)
    }

    func testStackedLayoutWithReset() {
        let now = Date()
        let inAnHour = now.addingTimeInterval(3600)
        let withReset = MenuBarBadge.compose(percent: 50, resetsAt: inAnHour, now: now)
        let bare = MenuBarBadge.compose(percent: nil, resetsAt: nil)
        XCTAssertTrue(withReset.isTemplate)
        // Stacked version must be wider than the bare bolt because we drew text alongside it.
        XCTAssertGreaterThan(withReset.size.width, bare.size.width)
    }

    func testCompactRemainingFormats() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(MenuBarBadge.compactRemaining(from: base, to: base.addingTimeInterval(-10)), "now")
        XCTAssertEqual(MenuBarBadge.compactRemaining(from: base, to: base.addingTimeInterval(45 * 60)), "45m")
        XCTAssertEqual(MenuBarBadge.compactRemaining(from: base, to: base.addingTimeInterval(60 * 60)), "1h")
        XCTAssertEqual(MenuBarBadge.compactRemaining(from: base, to: base.addingTimeInterval(2 * 3600 + 30 * 60)), "2h30m")
        XCTAssertEqual(MenuBarBadge.compactRemaining(from: base, to: base.addingTimeInterval(11 * 3600 + 15 * 60)), "11h")
    }
}
