import XCTest
@testable import ClaudeMon

final class KeychainStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainStore.delete()
    }

    override func tearDown() {
        KeychainStore.delete()
        super.tearDown()
    }

    func testRoundTrip() throws {
        XCTAssertNil(KeychainStore.sessionKey(), "Expected clean state at start of test")

        try KeychainStore.setSessionKey("sk-ant-sid01-abc123")
        XCTAssertEqual(KeychainStore.sessionKey(), "sk-ant-sid01-abc123")
    }

    func testOverwrite() throws {
        try KeychainStore.setSessionKey("first-value")
        XCTAssertEqual(KeychainStore.sessionKey(), "first-value")

        try KeychainStore.setSessionKey("second-value")
        XCTAssertEqual(KeychainStore.sessionKey(), "second-value")
    }

    func testDelete() throws {
        try KeychainStore.setSessionKey("to-be-deleted")
        XCTAssertNotNil(KeychainStore.sessionKey())

        KeychainStore.delete()
        XCTAssertNil(KeychainStore.sessionKey())
    }

    func testDeleteWhenAbsentIsNoOp() {
        // Delete from clean state should not crash and should leave nil.
        KeychainStore.delete()
        XCTAssertNil(KeychainStore.sessionKey())
    }
}
