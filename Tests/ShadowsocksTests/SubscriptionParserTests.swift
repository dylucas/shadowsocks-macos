// SubscriptionParserTests — Unit tests for SIP002/SIP008 parsing

import XCTest
@testable import Shadowsocks

final class SubscriptionParserTests: XCTestCase {

    // MARK: - SIP002 URL Parsing

    func testParseSimpleSIP002URL() throws {
        // Standard SIP002: ss://base64(method:password)@host:port#remark
        let userInfo = "aes-256-gcm:test-password"
        let encoded = Data(userInfo.utf8).base64EncodedString()
        let url = "ss://\(encoded)@1.2.3.4:8388#TestServer"

        let server = try SubscriptionParser.parseSIP002URL(url)

        XCTAssertEqual(server.address, "1.2.3.4")
        XCTAssertEqual(server.port, 8388)
        XCTAssertEqual(server.cipher, .aes256Gcm)
        XCTAssertEqual(server.password, "test-password")
        XCTAssertEqual(server.remark, "TestServer")
        XCTAssertEqual(server.isManual, false)
    }

    func testParseSIP002URLWithoutRemark() throws {
        let userInfo = "chacha20-ietf-poly1305:mypassword"
        let encoded = Data(userInfo.utf8).base64EncodedString()
        let url = "ss://\(encoded)@example.com:443"

        let server = try SubscriptionParser.parseSIP002URL(url)

        XCTAssertEqual(server.address, "example.com")
        XCTAssertEqual(server.port, 443)
        XCTAssertEqual(server.cipher, .chacha20IetfPoly1305)
        XCTAssertEqual(server.password, "mypassword")
        XCTAssertEqual(server.remark, "")
    }

    func testParseSIP002URLWithIPv6Host() throws {
        let userInfo = "aes-128-gcm:pass123"
        let encoded = Data(userInfo.utf8).base64EncodedString()
        let url = "ss://\(encoded)@[::1]:8388#IPv6Server"

        let server = try SubscriptionParser.parseSIP002URL(url)

        XCTAssertEqual(server.address, "::1")
        XCTAssertEqual(server.port, 8388)
    }

    func testParseLegacySIP002Format() throws {
        // Legacy format: ss://base64(method:password@host:port)
        let full = "aes-256-gcm:secretpass@9.8.7.6:1234"
        let encoded = Data(full.utf8).base64EncodedString()
        let url = "ss://\(encoded)"

        let server = try SubscriptionParser.parseSIP002URL(url)

        XCTAssertEqual(server.address, "9.8.7.6")
        XCTAssertEqual(server.port, 1234)
        XCTAssertEqual(server.cipher, .aes256Gcm)
        XCTAssertEqual(server.password, "secretpass")
    }

    // MARK: - SIP002 Batch Parsing

    func testParseBatchSIP002URLs() {
        let line1 = "aes-256-gcm:pass1@1.1.1.1:1000"
        let line2 = "aes-128-gcm:pass2@2.2.2.2:2000"
        let content = "ss://\(Data(line1.utf8).base64EncodedString())\nss://\(Data(line2.utf8).base64EncodedString())"

        let servers = SubscriptionParser.parseSIP002URLs(content)
        XCTAssertEqual(servers.count, 2)
    }

    func testParseBase64EncodedBatch() {
        // Entire subscription content may be base64 encoded
        let inner = "aes-256-gcm:pass@host:8388"
        let lines = "ss://\(Data(inner.utf8).base64EncodedString())"
        let encoded = Data(lines.utf8).base64EncodedString()

        let servers = SubscriptionParser.parseSIP002URLs(encoded)
        XCTAssertEqual(servers.count, 1)
    }

    // MARK: - SIP008 JSON Parsing

    func testParseSIP008JSON() throws {
        let json = """
        {
            "servers": [
                {
                    "server": "server1.example.com",
                    "port": 8388,
                    "method": "aes-256-gcm",
                    "password": "password1",
                    "remarks": "Server 1"
                },
                {
                    "server": "server2.example.com",
                    "port": 443,
                    "method": "chacha20-ietf-poly1305",
                    "password": "password2",
                    "remarks": "Server 2"
                }
            ]
        }
        """

        let servers = try SubscriptionParser.parseSIP008JSON(json)

        XCTAssertEqual(servers.count, 2)
        XCTAssertEqual(servers[0].address, "server1.example.com")
        XCTAssertEqual(servers[0].port, 8388)
        XCTAssertEqual(servers[0].cipher, .aes256Gcm)
        XCTAssertEqual(servers[0].password, "password1")
        XCTAssertEqual(servers[0].remark, "Server 1")

        XCTAssertEqual(servers[1].address, "server2.example.com")
        XCTAssertEqual(servers[1].cipher, .chacha20IetfPoly1305)
    }

    // MARK: - Auto-detect Format

    func testAutoDetectSIP002URL() throws {
        let url = "ss://\(Data("aes-256-gcm:pass@1.2.3.4:8388".utf8).base64EncodedString())"
        let servers = try SubscriptionParser.parse(url)
        XCTAssertEqual(servers.count, 1)
    }

    func testAutoDetectSIP008JSON() throws {
        let json = """
        {"servers": [{"server": "1.2.3.4", "port": 8388, "method": "aes-256-gcm", "password": "test"}]}
        """
        let servers = try SubscriptionParser.parse(json)
        XCTAssertEqual(servers.count, 1)
    }

    // MARK: - Error Cases

    func testInvalidFormatThrowsError() {
        XCTAssertThrowsError(try SubscriptionParser.parse("not-a-valid-format"))
    }

    func testEmptyStringThrowsError() {
        XCTAssertThrowsError(try SubscriptionParser.parse(""))
    }

    func testInvalidBase64ThrowsError() {
        XCTAssertThrowsError(try SubscriptionParser.parseSIP002URL("ss://!!!invalid!!!@host:port"))
    }
}
