// NetworkService — Latency testing and connectivity checks

import Foundation
import Network

final class NetworkService {
    private let timeout: TimeInterval = 5.0

    init(timeout: TimeInterval = 5.0) {
        self.timeout = timeout
    }

    // MARK: - TCP Latency Test

    /// Test TCP connection latency to a host:port
    static func testTCPLatency(host: String, port: UInt16, timeout: TimeInterval = 5.0) async throws -> Int {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NetworkError.invalidPort
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        let connection = NWConnection(to: endpoint, using: .tcp)

        let startTime = Date()
        let connected = await withCheckedContinuation { continuation in
            var resumed = false
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !resumed {
                        resumed = true
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    if !resumed {
                        resumed = true
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }
            connection.start(queue: .global())

            // Timeout safety net
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if !resumed {
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }

        connection.cancel()

        if connected {
            let elapsed = Date().timeIntervalSince(startTime)
            return Int(elapsed * 1000)
        } else {
            throw NetworkError.connectionTimeout
        }
    }

    // MARK: - Batch Latency Test

    /// Test latency for multiple servers concurrently
    static func batchLatencyTest(servers: [Server], timeout: TimeInterval = 5.0) async -> [(UUID, Int?)] {
        await withTaskGroup(of: (UUID, Int?).self) { group in
            for server in servers {
                group.addTask {
                    let latency = try? await testTCPLatency(
                        host: server.address,
                        port: server.port,
                        timeout: timeout
                    )
                    return (server.id, latency)
                }
            }

            var results: [(UUID, Int?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    // MARK: - SOCKS5 Connectivity Test

    /// Test if the local SOCKS5 proxy is functional
    static func testSOCKS5Proxy(host: String = "127.0.0.1", port: UInt16 = 1080) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        let connection = NWConnection(to: endpoint, using: .tcp)

        let connected = await withCheckedContinuation { continuation in
            var resumed = false
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !resumed {
                        resumed = true
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    if !resumed {
                        resumed = true
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }
            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                if !resumed {
                    resumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }

        connection.cancel()
        return connected
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case connectionTimeout
    case invalidPort
    case hostNotFound

    var errorDescription: String? {
        switch self {
        case .connectionTimeout:
            return "连接超时，服务器可能不可达"
        case .invalidPort:
            return "端口无效"
        case .hostNotFound:
            return "无法解析服务器地址"
        }
    }
}
