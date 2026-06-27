// SslocalConfigTests — Unit tests for sslocal configuration generation

import XCTest
@testable import Shadowsocks

final class SslocalConfigTests: XCTestCase {

    // MARK: - Config Generation

    func testConfigFromServerBasic() throws {
        let server = Server(
            address: "1.2.3.4",
            port: 8388,
            cipher: .aes256Gcm,
            password: "test-password"
        )

        let config = SslocalConfig.from(server: server, localPort: 1080)

        XCTAssertEqual(config.server, "1.2.3.4")
        XCTAssertEqual(config.server_port, 8388)
        XCTAssertEqual(config.method, "aes-256-gcm")
        XCTAssertEqual(config.password, "test-password")
        XCTAssertEqual(config.locals.count, 1)
        XCTAssertEqual(config.locals[0].local_address, "127.0.0.1")
        XCTAssertEqual(config.locals[0].local_port, 1080)
        XCTAssertEqual(config.locals[0].localProtocol, "socks5")
    }

    func testConfigWithHTTPProxy() throws {
        let server = Server(
            address: "example.com",
            port: 443,
            cipher: .chacha20IetfPoly1305,
            password: "pass"
        )

        let config = SslocalConfig.from(server: server, socksPort: 1080, httpPort: 1081)

        XCTAssertEqual(config.locals.count, 2)
        XCTAssertEqual(config.locals[0].localProtocol, "socks5")
        XCTAssertEqual(config.locals[0].local_port, 1080)
        XCTAssertEqual(config.locals[1].localProtocol, "http")
        XCTAssertEqual(config.locals[1].local_port, 1081)
    }

    func testConfigWithAEAD2022Cipher() throws {
        let server = Server(
            address: "5.6.7.8",
            port: 9999,
            cipher: .aes256Gcm2022,
            password: "2022-password"
        )

        let config = SslocalConfig.from(server: server)

        XCTAssertEqual(config.method, "2022-blake3-aes-256-gcm")
        XCTAssertEqual(config.password, "2022-password")
    }

    // MARK: - JSON Serialization (protocol key should be "protocol" not "localProtocol")

    func testJSONSerialization() throws {
        let server = Server(
            address: "1.2.3.4",
            port: 8388,
            cipher: .aes256Gcm,
            password: "test"
        )

        let config = SslocalConfig.from(server: server)
        let json = try config.toJSON()

        // Verify JSON contains expected keys — "protocol" (not "localProtocol") due to CodingKeys
        XCTAssertTrue(json.contains("\"server\""))
        XCTAssertTrue(json.contains("\"server_port\""))
        XCTAssertTrue(json.contains("\"method\""))
        XCTAssertTrue(json.contains("\"password\""))
        XCTAssertTrue(json.contains("\"locals\""))
        XCTAssertTrue(json.contains("\"protocol\""))
        XCTAssertFalse(json.contains("\"localProtocol\""))
    }

    // MARK: - File Writing

    func testWriteToFile() throws {
        let server = Server(
            address: "1.2.3.4",
            port: 8388,
            cipher: .aes256Gcm,
            password: "test"
        )

        let config = SslocalConfig.from(server: server)
        let fileURL = try config.writeToFile()

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("\"server\": \"1.2.3.4\""))

        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Cipher Method Properties

    func testCipherArmAESDetection() {
        XCTAssertTrue(CipherMethod.aes256Gcm.usesArmAES)
        XCTAssertTrue(CipherMethod.aes128Gcm.usesArmAES)
        XCTAssertTrue(CipherMethod.aes256Gcm2022.usesArmAES)
        XCTAssertTrue(CipherMethod.aes128Gcm2022.usesArmAES)
        XCTAssertFalse(CipherMethod.chacha20IetfPoly1305.usesArmAES)
        XCTAssertFalse(CipherMethod.chacha20Poly13052022.usesArmAES)
    }
}
