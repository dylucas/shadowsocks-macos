// SystemProxyTests — Integration tests for macOS system proxy settings

import XCTest
@testable import Shadowsocks

final class SystemProxyTests: XCTestCase {

    var systemProxy: SystemProxyService!

    override func setUp() {
        super.setUp()
        systemProxy = SystemProxyService()
        // Ensure proxy is disabled before each test
        systemProxy.disable()
    }

    override func tearDown() {
        systemProxy.disable()
        super.tearDown()
    }

    // MARK: - Enable/Disable

    func testEnableGlobalProxy() throws {
        try systemProxy.enable(socks5Port: 1080, mode: .global)

        XCTAssertTrue(systemProxy.isProxyEnabled())

        systemProxy.disable()
        XCTAssertFalse(systemProxy.isProxyEnabled())
    }

    func testEnablePACProxy() throws {
        try systemProxy.enable(socks5Port: 1080, mode: .pac)

        XCTAssertTrue(systemProxy.isProxyEnabled())

        systemProxy.disable()
        XCTAssertFalse(systemProxy.isProxyEnabled())
    }

    func testEnableDirectModeDoesNothing() throws {
        try systemProxy.enable(socks5Port: 1080, mode: .direct)

        // Direct mode should not enable any proxy
        XCTAssertFalse(systemProxy.isProxyEnabled())
    }

    // MARK: - Rollback

    func testDisableRestoresPreviousState() throws {
        // First, check the initial proxy state
        let wasEnabledBefore = systemProxy.isProxyEnabled()

        // Enable proxy
        try systemProxy.enable(socks5Port: 1080, mode: .global)
        XCTAssertTrue(systemProxy.isProxyEnabled())

        // Disable should restore to initial state
        systemProxy.disable()
        XCTAssertEqual(systemProxy.isProxyEnabled(), wasEnabledBefore)
    }
}
