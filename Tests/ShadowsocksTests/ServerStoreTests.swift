// ServerStoreTests — Unit tests for server CRUD operations

import XCTest
@testable import Shadowsocks

final class ServerStoreTests: XCTestCase {

    var serverStore: ServerStore!

    override func setUp() {
        super.setUp()
        serverStore = ServerStore()
        // Clean up any existing data
        serverStore.deleteAll()
        KeychainHelper.deleteAll()
    }

    override func tearDown() {
        serverStore.deleteAll()
        KeychainHelper.deleteAll()
        super.tearDown()
    }

    // MARK: - Add Server

    func testAddServer() throws {
        let server = Server(
            name: "Test Server",
            address: "1.2.3.4",
            port: 8388,
            cipher: .aes256Gcm,
            password: "test-password",
            remark: "Test remark"
        )

        try serverStore.add(server)

        XCTAssertEqual(serverStore.servers.count, 1)
        XCTAssertEqual(serverStore.servers[0].address, "1.2.3.4")
        XCTAssertEqual(serverStore.servers[0].port, 8388)
        XCTAssertEqual(serverStore.servers[0].cipher, .aes256Gcm)
        XCTAssertEqual(serverStore.servers[0].remark, "Test remark")

        // Password should NOT be in UserDefaults (empty in stored copy)
        XCTAssertEqual(serverStore.servers[0].password, "")

        // But should be retrievable from Keychain
        let fullServer = serverStore.serverWithPassword(id: server.id)
        XCTAssertEqual(fullServer?.password, "test-password")
    }

    // MARK: - Update Server

    func testUpdateServer() throws {
        let server = Server(
            name: "Original",
            address: "1.2.3.4",
            port: 8388,
            cipher: .aes256Gcm,
            password: "original-password"
        )

        try serverStore.add(server)

        let updated = Server(
            id: server.id,
            name: "Updated",
            address: "5.6.7.8",
            port: 9999,
            cipher: .chacha20IetfPoly1305,
            password: "updated-password"
        )

        try serverStore.update(updated)

        XCTAssertEqual(serverStore.servers.count, 1)
        XCTAssertEqual(serverStore.servers[0].name, "Updated")
        XCTAssertEqual(serverStore.servers[0].address, "5.6.7.8")

        let fullServer = serverStore.serverWithPassword(id: server.id)
        XCTAssertEqual(fullServer?.password, "updated-password")
    }

    // MARK: - Delete Server

    func testDeleteServer() throws {
        let server = Server(
            address: "1.2.3.4",
            port: 8388,
            cipher: .aes256Gcm,
            password: "test"
        )

        try serverStore.add(server)
        XCTAssertEqual(serverStore.servers.count, 1)

        serverStore.delete(server)
        XCTAssertEqual(serverStore.servers.count, 0)

        // Keychain should also be cleaned
        XCTAssertNil(KeychainHelper.load(for: server.id))
    }

    // MARK: - Multiple Servers

    func testMultipleServers() throws {
        let servers = [
            Server(address: "1.1.1.1", port: 1000, cipher: .aes256Gcm, password: "p1"),
            Server(address: "2.2.2.2", port: 2000, cipher: .aes128Gcm, password: "p2"),
            Server(address: "3.3.3.3", port: 3000, cipher: .chacha20IetfPoly1305, password: "p3"),
        ]

        for server in servers {
            try serverStore.add(server)
        }

        XCTAssertEqual(serverStore.servers.count, 3)

        let allWithPasswords = serverStore.allServersWithPasswords()
        XCTAssertEqual(allWithPasswords[0].password, "p1")
        XCTAssertEqual(allWithPasswords[1].password, "p2")
        XCTAssertEqual(allWithPasswords[2].password, "p3")
    }

    // MARK: - Display Name

    func testDisplayNameWithRemark() {
        let server = Server(address: "1.2.3.4", port: 8388, cipher: .aes256Gcm, remark: "My Server")
        XCTAssertEqual(server.displayName, "My Server")
    }

    func testDisplayNameWithoutRemark() {
        let server = Server(address: "1.2.3.4", port: 8388, cipher: .aes256Gcm)
        XCTAssertEqual(server.displayName, "1.2.3.4:8388")
    }
}
