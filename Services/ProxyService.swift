// ProxyService — Unified proxy control: orchestrates sslocal + system proxy
// Handles crash recovery with max 3 auto-restart attempts

import Foundation
import Combine

final class ProxyService: ObservableObject {
    @Published var isActive: Bool = false
    @Published var activeServerID: UUID?
    @Published var errorMessage: String?

    private let sslocalBridge: SslocalBridge
    private let systemProxy: SystemProxyService
    private var serverStore: ServerStore?
    private var restartAttempts: Int = 0
    private let maxRestartAttempts: Int = 3

    // Current configuration
    private var currentConfig: SslocalConfig?
    private var currentLocalPort: UInt16 = 1080
    private var currentProxyMode: ProxyMode = .pac

    // Crash monitoring timer
    private var crashMonitorTimer: Timer?

    init(
        sslocalBridge: SslocalBridge = SslocalBridge(),
        systemProxy: SystemProxyService = SystemProxyService()
    ) {
        self.sslocalBridge = sslocalBridge
        self.systemProxy = systemProxy
    }

    /// Configure with shared ServerStore (called by AppDelegate or App)
    func configure(serverStore: ServerStore) {
        self.serverStore = serverStore
    }

    // MARK: - Start Proxy

    /// Start proxy with a specific server
    func start(serverID: UUID, serverStore: ServerStore? = nil, localPort: UInt16 = 1080, mode: ProxyMode = .pac) async throws {
        // Use provided store or fallback to configured one
        let store = serverStore ?? self.serverStore ?? ServerStore()

        guard let server = store.serverWithPassword(id: serverID) else {
            throw ProxyError.serverNotFound
        }

        errorMessage = nil
        currentLocalPort = localPort
        currentProxyMode = mode

        // Generate sslocal config
        let config = SslocalConfig.from(server: server, localPort: localPort)
        currentConfig = config
        activeServerID = serverID

        // Start sslocal
        do {
            try await sslocalBridge.launch(with: config)
        } catch {
            errorMessage = "代理启动失败：\(error.localizedDescription)"
            isActive = false
            throw ProxyError.launchFailed(underlying: error)
        }

        // Set system proxy
        do {
            try systemProxy.enable(socks5Port: localPort, mode: mode)
        } catch {
            // Rollback: stop sslocal if system proxy fails
            try? await sslocalBridge.terminate()
            isActive = false
            errorMessage = "系统代理设置失败：\(error.localizedDescription)"
            throw ProxyError.systemProxyFailed(underlying: error)
        }

        isActive = true
        restartAttempts = 0
        startCrashMonitor()
    }

    // MARK: - Stop Proxy

    /// Stop proxy and rollback system proxy settings
    func stop() async throws {
        crashMonitorTimer?.invalidate()
        crashMonitorTimer = nil

        do {
            try await sslocalBridge.terminate()
        } catch {
            errorMessage = "sslocal 停止异常，但系统代理已回滚"
        }

        systemProxy.disable()

        isActive = false
        activeServerID = nil
        currentConfig = nil
        errorMessage = nil
        restartAttempts = 0
    }

    /// Synchronous stop for AppDelegate cleanup
    func stopSync() {
        // Immediately rollback system proxy (most critical for user's network)
        systemProxy.disable()
        isActive = false
        activeServerID = nil
        errorMessage = nil

        // Attempt to stop sslocal in background (may not complete before app exits)
        Task {
            try? await sslocalBridge.terminate()
        }
    }

    // MARK: - Switch Server

    func switchServer(to serverID: UUID) async throws {
        try await stop()
        try await start(serverID: serverID, localPort: currentLocalPort, mode: currentProxyMode)
    }

    // MARK: - Crash Recovery

    private func startCrashMonitor() {
        crashMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            // Check if sslocal process exited unexpectedly
            if !self.sslocalBridge.isRunning && self.isActive {
                self.handleCrash()
            }
        }
    }

    private func handleCrash() {
        restartAttempts += 1

        if restartAttempts > maxRestartAttempts {
            isActive = false
            errorMessage = "代理连接不稳定，已自动重试 \(maxRestartAttempts) 次。请检查服务器或更换节点。"
            systemProxy.disable()
            crashMonitorTimer?.invalidate()
            crashMonitorTimer = nil
            return
        }

        errorMessage = "代理连接中断，正在自动恢复（第 \(restartAttempts) 次）..."

        guard let config = currentConfig else { return }

        Task {
            do {
                try await sslocalBridge.launch(with: config)
                try systemProxy.enable(socks5Port: currentLocalPort, mode: currentProxyMode)
                errorMessage = nil
            } catch {
                // Will retry on next timer tick
            }
        }
    }

    // MARK: - Proxy Mode Change

    func setProxyMode(_ mode: ProxyMode) async throws {
        currentProxyMode = mode
        guard isActive else { return }
        systemProxy.disable()
        try systemProxy.enable(socks5Port: currentLocalPort, mode: mode)
    }

    // MARK: - Latency Test

    func testLatency(for serverID: UUID, serverStore: ServerStore? = nil) async -> Int? {
        let store = serverStore ?? self.serverStore ?? ServerStore()
        guard let server = store.serverWithPassword(id: serverID) else { return nil }

        do {
            let latency = try await NetworkService.testTCPLatency(
                host: server.address,
                port: server.port
            )
            store.updateLatency(for: serverID, latency: latency)
            return latency
        } catch {
            store.updateLatency(for: serverID, latency: nil)
            return nil
        }
    }
}

// MARK: - Errors

enum ProxyError: LocalizedError {
    case serverNotFound
    case launchFailed(underlying: Error)
    case systemProxyFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .serverNotFound:
            return "找不到服务器配置"
        case .launchFailed(let error):
            return "代理启动失败：\(error.localizedDescription)"
        case .systemProxyFailed(let error):
            return "系统代理设置失败：\(error.localizedDescription)"
        }
    }
}
