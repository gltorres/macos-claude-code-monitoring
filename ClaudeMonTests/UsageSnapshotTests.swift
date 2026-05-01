import XCTest
@testable import ClaudeMon

final class UsageSnapshotTests: XCTestCase {

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func loadFixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        else {
            XCTFail("Fixture \(name).json not found in test bundle")
            return Data()
        }
        return try Data(contentsOf: url)
    }

    func testFullFixtureDecodesAllFields() throws {
        let data = try loadFixture("captured_usage")
        let snap = try decoder().decode(UsageSnapshot.self, from: data)

        XCTAssertEqual(snap.fiveHour?.utilization, 23.0)
        XCTAssertEqual(snap.fiveHour?.utilizationInt, 23)
        XCTAssertNotNil(snap.fiveHour?.resetsAt)

        XCTAssertEqual(snap.sevenDay?.utilization, 0.0)
        XCTAssertEqual(snap.sevenDaySonnet?.utilization, 5.5)
        XCTAssertEqual(snap.sevenDaySonnet?.utilizationInt, 6) // rounded
        XCTAssertNil(snap.sevenDaySonnet?.resetsAt)            // null in payload
        XCTAssertNil(snap.sevenDayOpus)                         // null in payload → nil
        XCTAssertEqual(snap.sevenDayOmelette?.utilization, 0.0)

        XCTAssertEqual(snap.extraUsage?.isEnabled, true)
        XCTAssertEqual(snap.extraUsage?.monthlyLimit, 3700)
        XCTAssertEqual(snap.extraUsage?.usedCredits, 3747.0)
        XCTAssertEqual(snap.extraUsage?.utilization, 100.0)
        XCTAssertEqual(snap.extraUsage?.utilizationInt, 100)
        XCTAssertEqual(snap.extraUsage?.currency, "USD")
    }

    func testPartialFixtureDecodesMissingFieldsAsNil() throws {
        let json = #"""
        {
            "five_hour":  { "utilization": 10.0, "resets_at": "2026-04-30T18:00:00Z" },
            "seven_day":  { "utilization": 20.0, "resets_at": "2026-05-04T04:00:00Z" }
        }
        """#.data(using: .utf8)!

        let snap = try decoder().decode(UsageSnapshot.self, from: json)
        XCTAssertEqual(snap.fiveHour?.utilization, 10.0)
        XCTAssertEqual(snap.sevenDay?.utilization, 20.0)
        XCTAssertNil(snap.sevenDaySonnet)
        XCTAssertNil(snap.sevenDayOpus)
        XCTAssertNil(snap.sevenDayOmelette)
        XCTAssertNil(snap.extraUsage)
    }

    func testMalformedBucketDegradesToNil() throws {
        // five_hour present but missing the required `utilization` field —
        // before the fix this aborted the whole snapshot decode.
        let json = #"""
        {
            "five_hour": { "resets_at": "2026-04-30T18:00:00Z" }
        }
        """#.data(using: .utf8)!
        let snap = try decoder().decode(UsageSnapshot.self, from: json)
        XCTAssertNil(snap.fiveHour, "malformed bucket should degrade to nil")
        XCTAssertNil(snap.sevenDay)
        XCTAssertNil(snap.extraUsage)
    }

    func testOneBucketFailureDoesNotPoisonOthers() throws {
        // five_hour is malformed; seven_day is fine. Pre-fix: whole decode
        // throws. Post-fix: seven_day surfaces, five_hour is nil.
        let json = #"""
        {
            "five_hour": { "resets_at": "2026-05-01T18:00:00Z" },
            "seven_day": { "utilization": 33.3, "resets_at": "2026-05-08T05:00:00Z" }
        }
        """#.data(using: .utf8)!
        let snap = try decoder().decode(UsageSnapshot.self, from: json)
        XCTAssertNil(snap.fiveHour)
        XCTAssertEqual(snap.sevenDay?.utilization, 33.3)
    }

    func testNullUtilizationDegradesBucketToNil() throws {
        let json = #"""
        {
            "five_hour": { "utilization": null, "resets_at": "2026-05-01T18:00:00Z" },
            "seven_day": { "utilization": 12.5, "resets_at": "2026-05-08T05:00:00Z" }
        }
        """#.data(using: .utf8)!
        let snap = try decoder().decode(UsageSnapshot.self, from: json)
        XCTAssertNil(snap.fiveHour)
        XCTAssertEqual(snap.sevenDay?.utilization, 12.5)
    }

    func testMalformedExtraUsageDegradesToNilWithoutBlockingBuckets() throws {
        // extra_usage is missing `currency` — pre-fix this aborted the parent.
        let json = #"""
        {
            "five_hour":   { "utilization": 5.0,  "resets_at": "2026-05-01T18:00:00Z" },
            "extra_usage": { "is_enabled": true, "monthly_limit": 100, "used_credits": 50, "utilization": 50 }
        }
        """#.data(using: .utf8)!
        let snap = try decoder().decode(UsageSnapshot.self, from: json)
        XCTAssertEqual(snap.fiveHour?.utilization, 5.0)
        XCTAssertNil(snap.extraUsage)
    }

    func testEmptyJSONDecodesAllNil() throws {
        let json = "{}".data(using: .utf8)!
        let snap = try decoder().decode(UsageSnapshot.self, from: json)
        XCTAssertNil(snap.fiveHour)
        XCTAssertNil(snap.sevenDay)
        XCTAssertNil(snap.sevenDaySonnet)
        XCTAssertNil(snap.extraUsage)
    }

    func testCompletelyInvalidPayloadStillThrows() {
        // Top-level array — no keyed container possible.
        let json = "[]".data(using: .utf8)!
        XCTAssertThrowsError(try decoder().decode(UsageSnapshot.self, from: json))
    }
}
