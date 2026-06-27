// Server Model — Represents a single Shadowsocks server configuration

import Foundation

struct Server: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var address: String
    var port: UInt16
    var cipher: CipherMethod
    var password: String // Stored separately in Keychain
    var remark: String
    var latency: Int? // milliseconds, nil if untested
    var lastTestedAt: Date?
    var isManual: Bool // true if manually added, false if from subscription

    init(
        id: UUID = UUID(),
        name: String = "",
        address: String,
        port: UInt16,
        cipher: CipherMethod,
        password: String = "",
        remark: String = "",
        latency: Int? = nil,
        lastTestedAt: Date? = nil,
        isManual: Bool = true
    ) {
        self.id = id
        self.name = name.isEmpty ? "\(address):\(port)" : name
        self.address = address
        self.port = port
        self.cipher = cipher
        self.password = password
        self.remark = remark
        self.latency = latency
        self.lastTestedAt = lastTestedAt
        self.isManual = isManual
    }

    /// Display name for UI
    var displayName: String {
        remark.isEmpty ? "\(address):\(port)" : remark
    }

    /// SIP002 URL representation
    var sip002URL: String {
        let userInfo = "\(cipher.rawValue):\(password)".data(using: .utf8)?
            .base64EncodedString() ?? ""
        return "ss://\(userInfo)@\(address):\(port)"
    }
}

// MARK: - Cipher Methods

enum CipherMethod: String, Codable, CaseIterable {
    // AEAD 2022 (recommended)
    case aes128Gcm2022 = "2022-blake3-aes-128-gcm"
    case aes256Gcm2022 = "2022-blake3-aes-256-gcm"
    case chacha20Poly13052022 = "2022-blake3-chacha20-poly1305"
    case chacha8Poly13052022 = "2022-blake3-chacha8-poly1305"

    // AEAD (standard)
    case aes128Gcm = "aes-128-gcm"
    case aes256Gcm = "aes-256-gcm"
    case chacha20IetfPoly1305 = "chacha20-ietf-poly1305"

    // Display name for UI
    var displayName: String {
        switch self {
        case .aes128Gcm2022: return "AEAD-2022 AES-128-GCM"
        case .aes256Gcm2022: return "AEAD-2022 AES-256-GCM"
        case .chacha20Poly13052022: return "AEAD-2022 ChaCha20-Poly1305"
        case .chacha8Poly13052022: return "AEAD-2022 ChaCha8-Poly1305"
        case .aes128Gcm: return "AEAD AES-128-GCM"
        case .aes256Gcm: return "AEAD AES-256-GCM"
        case .chacha20IetfPoly1305: return "AEAD ChaCha20-Poly1305"
        }
    }

    /// Whether this cipher benefits from ARM AES hardware acceleration
    var usesArmAES: Bool {
        switch self {
        case .aes128Gcm, .aes256Gcm, .aes128Gcm2022, .aes256Gcm2022:
            return true
        default:
            return false
        }
    }
}
