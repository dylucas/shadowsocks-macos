// SslocalConfig — Generate shadowsocks-rust sslocal JSON configuration file

import Foundation

struct SslocalConfig: Codable {
    // MARK: - Local Proxy Configuration

    let locals: [LocalConfig]
    let server: String
    let server_port: UInt16
    let method: String
    let password: String

    // Optional
    let plugin: String?
    let plugin_opts: String?
    let mode: String // "tcp_and_udp" recommended
    let ipv6_first: Bool
    let fast_open: Bool

    // MARK: - Local Config Entry

    struct LocalConfig: Codable {
        let local_address: String
        let local_port: UInt16
        let mode: String // "tcp_and_udp"
        let `protocol`: String // "socks5" — backticks because protocol is a Swift keyword
    }

    // MARK: - Create from Server

    static func from(server: Server, localPort: UInt16 = 1080) -> SslocalConfig {
        SslocalConfig(
            locals: [
                LocalConfig(
                    local_address: "127.0.0.1",
                    local_port: localPort,
                    mode: "tcp_and_udp",
                    `protocol`: "socks5"
                ),
            ],
            server: server.address,
            server_port: server.port,
            method: server.cipher.rawValue,
            password: server.password,
            plugin: nil,
            plugin_opts: nil,
            mode: "tcp_and_udp",
            ipv6_first: false,
            fast_open: false
        )
    }

    // MARK: - Create with HTTP proxy

    static func from(server: Server, socksPort: UInt16 = 1080, httpPort: UInt16 = 1081) -> SslocalConfig {
        SslocalConfig(
            locals: [
                LocalConfig(
                    local_address: "127.0.0.1",
                    local_port: socksPort,
                    mode: "tcp_and_udp",
                    `protocol`: "socks5"
                ),
                LocalConfig(
                    local_address: "127.0.0.1",
                    local_port: httpPort,
                    mode: "tcp_only",
                    `protocol`: "http"
                ),
            ],
            server: server.address,
            server_port: server.port,
            method: server.cipher.rawValue,
            password: server.password,
            plugin: nil,
            plugin_opts: nil,
            mode: "tcp_and_udp",
            ipv6_first: false,
            fast_open: false
        )
    }

    // MARK: - Serialize to JSON

    func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Write to Temp File

    /// Write config to a temporary file for sslocal -c
    func writeToFile() throws -> URL {
        let json = try toJSON()
        let tempDir = FileManager.default.temporaryDirectory
        let configFileURL = tempDir.appendingPathComponent("sslocal_config_\(UUID().uuidString).json")

        try json.write(to: configFileURL, atomically: true, encoding: .utf8)
        return configFileURL
    }
}
