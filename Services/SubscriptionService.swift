// SubscriptionService — Parse SIP002 URLs and SIP008 JSON subscriptions

import Foundation

enum SubscriptionParser {

    // MARK: - SIP002 URL Parsing

    /// Parse a single SIP002 ss:// URL into a Server
    /// Format: ss://base64(method:password)@host:port#remark
    /// Or: ss://base64(method:password@host:port)#remark
    static func parseSIP002URL(_ urlString: String) throws -> Server {
        // Strip "ss://" prefix
        var raw = urlString
        if raw.hasPrefix("ss://") {
            raw = String(raw.dropFirst(5))
        }

        // Extract remark from fragment (#)
        var remark = ""
        if let fragmentStart = raw.firstIndex(of: "#") {
            remark = String(raw[raw.index(after: fragmentStart)...])
            remark = remark.removingPercentEncoding ?? remark
            raw = String(raw[raw.startIndex..<fragmentStart])
        }

        // Try format: base64(method:password@host:port)
        if let decoded = decodeBase64(raw) {
            // decoded should be like "method:password@host:port"
            return parseMethodPasswordHostPort(decoded, remark: remark)
        }

        // Try format: base64(method:password)@host:port
        if let atIndex = raw.lastIndex(of: "@") {
            let userInfoPart = String(raw[raw.startIndex..<atIndex])
            let hostPortPart = String(raw[raw.index(after: atIndex)...])

            guard let decodedUserInfo = decodeBase64(userInfoPart) else {
                throw ParseError.invalidBase64
            }

            let hostPort = parseHostPort(hostPortPart)
            let methodPassword = parseMethodPassword(decodedUserInfo)

            return Server(
                name: remark,
                address: hostPort.host,
                port: hostPort.port,
                cipher: methodPassword.method,
                password: methodPassword.password,
                remark: remark,
                isManual: false
            )
        }

        throw ParseError.invalidFormat
    }

    /// Parse multiple SIP002 URLs (one per line, possibly base64 encoded)
    static func parseSIP002URLs(_ content: String) -> [Server] {
        // If entire content is base64, decode first
        let lines: [String]
        if let decoded = decodeBase64(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            lines = decoded.split(separator: "\n").map(String.init)
        } else {
            lines = content.split(separator: "\n").map(String.init)
        }

        return lines.compactMap { line ->
            Server? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("ss://") else { return nil }
            return try? parseSIP002URL(trimmed)
        }
    }

    // MARK: - SIP008 JSON Parsing

    /// Parse SIP008 JSON subscription into Server array
    /// SIP008 format: { "servers": [ { "server": "...", "port": ..., "method": "...", "password": "...", "remarks": "..." } ] }
    static func parseSIP008JSON(_ jsonString: String) throws -> [Server] {
        guard let data = jsonString.data(using: .utf8) else {
            throw ParseError.invalidJSON
        }

        let sip008 = try JSONDecoder().decode(SIP008Config.self, from: data)
        return sip008.servers.map { entry ->
            Server(
                name: entry.remarks ?? "",
                address: entry.server,
                port: UInt16(entry.port),
                cipher: CipherMethod(rawValue: entry.method) ?? .aes256Gcm,
                password: entry.password,
                remark: entry.remarks ?? "",
                isManual: false
            )
        }
    }

    // MARK: - Auto-detect and Parse

    /// Auto-detect format (SIP002 URL, SIP002 batch, SIP008 JSON) and parse
    static func parse(_ content: String) throws -> [Server] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // SIP008 JSON: starts with { or after base64 decode starts with {
        if trimmed.hasPrefix("{") {
            return try parseSIP008JSON(trimmed)
        }

        if let decoded = decodeBase64(trimmed), decoded.hasPrefix("{") {
            return try parseSIP008JSON(decoded)
        }

        // SIP002: single URL or batch
        if trimmed.hasPrefix("ss://") {
            let servers = parseSIP002URLs(trimmed)
            if servers.isEmpty {
                throw ParseError.invalidFormat
            }
            return servers
        }

        // Try decoding entire content as base64 batch
        if let decoded = decodeBase64(trimmed) {
            let servers = parseSIP002URLs(decoded)
            if !servers.isEmpty { return servers }

            if decoded.hasPrefix("{") {
                return try parseSIP008JSON(decoded)
            }
        }

        throw ParseError.unrecognizedFormat
    }

    // MARK: - Helpers

    private static func decodeBase64(_ string: String) -> String? {
        // Try standard base64 first, then URL-safe variant
        let variants = [
            Data(base64Encoded: string),
            Data(base64Encoded: string, options: .ignoreUnknownCharacters),
        ]

        for data in variants {
            if let data, let result = String(data: data, encoding: .utf8) {
                return result
            }
        }
        return nil
    }

    private static func parseHostPort(_ string: String) -> (host: String, port: UInt16) {
        // IPv6: [host]:port
        if string.hasPrefix("[") {
            if let bracketEnd = string.firstIndex(of: "]") {
                let host = String(string[string.index(after: string.startIndex)..<bracketEnd])
                let portStr = String(string[string.index(after: bracketEnd)...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                return (host, UInt16(portStr) ?? 8388)
            }
        }

        // IPv4: host:port
        let parts = string.split(separator: ":", maxSplits: 1)
        let host = String(parts[0])
        let port = parts.count > 1 ? UInt16(String(parts[1])) ?? 8388 : 8388
        return (host, port)
    }

    private static func parseMethodPassword(_ string: String) -> (method: CipherMethod, password: String) {
        let parts = string.split(separator: ":", maxSplits: 1)
        let methodStr = String(parts[0])
        let password = parts.count > 1 ? String(parts[1]) : ""
        let method = CipherMethod(rawValue: methodStr) ?? .aes256Gcm
        return (method, password)
    }

    private static func parseMethodPasswordHostPort(_ string: String, remark: String) -> Server {
        // Format: method:password@host:port
        let atIndex = string.lastIndex(of: "@") ?? string.endIndex
        let userInfoPart = String(string[string.startIndex..<atIndex])
        let hostPortPart = atIndex < string.endIndex ? String(string[string.index(after: atIndex)...]) : ""

        let methodPassword = parseMethodPassword(userInfoPart)
        let hostPort = parseHostPort(hostPortPart)

        return Server(
            name: remark,
            address: hostPort.host,
            port: hostPort.port,
            cipher: methodPassword.method,
            password: methodPassword.password,
            remark: remark,
            isManual: false
        )
    }
}

// MARK: - SIP008 JSON Structure

struct SIP008Config: Codable {
    let servers: [SIP008ServerEntry]
}

struct SIP008ServerEntry: Codable {
    let server: String
    let port: Int
    let method: String
    let password: String
    let remarks: String?
    let id: String? // SIP008 optional server ID
}

// MARK: - Parse Errors

enum ParseError: LocalizedError {
    case invalidBase64
    case invalidFormat
    case invalidJSON
    case unrecognizedFormat
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return "无法解析 Base64 编码内容"
        case .invalidFormat:
            return "服务器配置格式不正确，请检查 ss:// URL 是否完整"
        case .invalidJSON:
            return "订阅 JSON 格式不正确"
        case .unrecognizedFormat:
            return "无法识别配置格式，请使用 SIP002 URL 或 SIP008 JSON"
        case .emptyResult:
            return "解析成功但未找到任何服务器配置"
        }
    }
}
