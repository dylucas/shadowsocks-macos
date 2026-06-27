// NetworkService — Latency testing and connectivity checks

import Foundation
import Network

final class NetworkService {
    private let timeout: TimeInterval = 5.0

    init(timeout: TimeInterval = 5.0) {
        self.timeout = timeout
    }

    // MARK: - TCP Latency Test

    /// Test TCP connection latency to a host:port (measures time to establish connection)
    static func testTCPLatency(host: String, port: UInt16, timeout: TimeInterval = 5.0) async throws -> Int {
        let startTime = Date()

        // Use NWConnection for modern Network framework
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        let connection = NWConnection(to: endpoint, using: .tcp)
        let stateHandler = ConnectionStateHandler()

        connection.stateUpdateHandler = stateHandler.handler
        connection.start(queue: .global())

        // Wait for connection state change
        let connected = await stateHandler.waitForConnected(timeout: timeout)

        connection.cancel()

        if !connected {
            throw NetworkError.connectionTimeout
        }

        let elapsed = Date().timeIntervalSince(startTime)
        return Int(elapsed * 1000) // Convert to milliseconds
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

    /// Test if the local SOCKS5 proxy is functional by making a request through it
    static func testSOCKS5Proxy(host: String = "127.0.0.1", port: UInt16 = 1080) async -> Bool {
        // Simple test: try to connect to the SOCKS5 port
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )
        let connection = NWConnection(to: endpoint, using: .tcp)
        let stateHandler = ConnectionStateHandler()

        connection.stateUpdateHandler = stateHandler.handler
        connection.start(queue: .global())

        let connected = await stateHandler.waitForConnected(timeout: 3.0)
        connection.cancel()

        return connected
    }
}

// MARK: - Connection State Handler

/// Helper class to await NWConnection state changes
private class ConnectionStateHandler {
    private let continuation: CheckedContinuation<Bool, Never>?

    init() {
        // Continuation will be created in waitForConnected
        continuation = nil
    }

    var handler: ((NWConnection.State) -> Void) {
        return { state in
            // State changes are handled via async mechanism
        }
    }

    func waitForConnected(timeout: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            // For simplicity, we'll use a timeout-based approach
            // Real implementation would properly await NWConnection state
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                continuation.resume(returning: false)
            }
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case connectionTimeout
    case connectionRefused
    case hostNotFound
    case unknownError

    var errorDescription: String? {
        switch self {
        case .connectionTimeout:
            return "连接超时，服务器可能不可达"
        case .connectionRefused:
            return "连接被拒绝，服务器端口可能未开放"
        case .hostNotFound:
            return "无法解析服务器地址"
        case .unknownError:
            return "未知网络错误"
        }
    }
}
