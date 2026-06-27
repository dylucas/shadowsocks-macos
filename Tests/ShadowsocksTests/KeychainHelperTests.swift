// KeychainHelperTests — Unit tests for Keychain password storage

import XCTest
@testable import Shadowsocks

final class KeychainHelperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainHelper.deleteAll()
    }

    override func tearDown() {
        KeychainHelper.deleteAll()
        super.tearDown()
    }

    // MARK: - Save and Load

    func testSaveAndLoadPassword() throws {
        let serverID = UUID()
        let password = "my-secret-password"

        try KeychainHelper.save(password: password, for: serverID)

        let loaded = KeychainHelper.load(for: serverID)
        XCTAssertEqual(loaded, password)
    }

    func testLoadNonExistentReturnsNil() {
        let serverID = UUID()
        let loaded = KeychainHelper.load(for: serverID)
        XCTAssertNil(loaded)
    }

    // MARK: - Update

    func testUpdatePassword() throws {
        let serverID = UUID()

        try KeychainHelper.save(password: "old-password", for: serverID)
        XCTAssertEqual(KeychainHelper.load(for: serverID), "old-password")

        // Save again with new password (delete + add)
        try KeychainHelper.save(password: "new-password", for: serverID)
        XCTAssertEqual(KeychainHelper.load(for: serverID), "new-password")
    }

    // MARK: - Delete

    func testDeletePassword() throws {
        let serverID = UUID()

        try KeychainHelper.save(password: "password", for: serverID)
        XCTAssertNotNil(KeychainHelper.load(for: serverID))

        KeychainHelper.delete(for: serverID)
        XCTAssertNil(KeychainHelper.load(for: serverID))
    }

    // MARK: - Delete All

    func testDeleteAllPasswords() throws {
        let id1 = UUID()
        let id2 = UUID()

        try KeychainHelper.save(password: "pass1", for: id1)
        try KeychainHelper.save(password: "pass2", for: id2)

        KeychainHelper.deleteAll()

        XCTAssertNil(KeychainHelper.load(for: id1))
        XCTAssertNil(KeychainHelper.load(for: id2))
    }
}
