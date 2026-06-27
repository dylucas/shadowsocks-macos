// SslocalBridge — Manages sslocal subprocess lifecycle (launch, terminate, monitor)

import Foundation
import Combine

final class SslocalBridge: ObservableObject {
    @Published private(set) var isRunning: Bool = false

    private var process: Process?
    private var configFilePath: URL?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var recentLogs: [String] = [] // Last 100 log lines
    private let maxLogLines = 100

    // MARK: - Path to Embedded sslocal Binary

    /// Locate sslocal binary inside the app bundle
    private func sslocalPath() -> String? {
        let bundle = Bundle.main

        // Try Resources directory first (embedded binary)
        if let path = bundle.path(forResource: "sslocal", ofType: nil) {
            return path
        }

        // Fallback: look in executable directory
        let execPath = bundle.executablePath ?? ""
        let execDir = (execPath as NSString).deletingLastPathComponent
        let sslocalInExecDir = execDir + "/sslocal"
        if FileManager.default.fileExists(atPath: sslocalInExecDir) {
            return sslocalInExecDir
        }

        // Fallback: Homebrew installation
        let brewPath = "/opt/homebrew/bin/sslocal"
        if FileManager.default.fileExists(atPath: brewPath) {
            return brewPath
        }

        return nil
    }

    // MARK: - Launch

    /// Launch sslocal with the given configuration
    func launch(with config: SslocalConfig) async throws {
        // Clean up any existing process
        if isRunning {
            try await terminate()
        }

        // Ensure sslocal binary exists
        guard let sslocalBin = sslocalPath() else {
            throw BridgeError.binaryNotFound
        }

        // Write config file
        let configFileURL = try config.writeToFile()
        self.configFilePath = configFileURL

        // Set up process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sslocalBin)
        process.arguments = ["-c", configFileURL.path]
        process.currentDirectoryURL = FileManager.default.temporaryDirectory

        // Capture stdout/stderr for monitoring
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        // Monitor stderr for logs
        setupLogMonitoring(stderrPipe)

        // Set up termination handler
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.cleanupConfigFile()
            }
        }

        self.process = process

        // Launch
        try process.run()
        isRunning = true

        // Give sslocal a moment to start listening
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Verify process is still running (crash detection)
        if !process.isRunning {
            isRunning = false
            throw BridgeError.launchFailed(reason: "sslocal exited immediately — check config or binary")
        }
    }

    /// Launch sslocal with a raw JSON config string (for direct config control)
    func launchWithJSON(configJSON: String) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let configFileURL = tempDir.appendingPathComponent("sslocal_config_\(UUID().uuidString).json")
        try configJSON.write(to: configFileURL, atomically: true, encoding: .utf8)
        self.configFilePath = configFileURL

        // Create a minimal config wrapper to reuse launch logic
        // We just need the file path, so we'll call the same launch sequence
        guard let sslocalBin = sslocalPath() else {
            throw BridgeError.binaryNotFound
        }

        if isRunning {
            try await terminate()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: sslocalBin)
        process.arguments = ["-c", configFileURL.path]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        self.stderrPipe = stderrPipe

        setupLogMonitoring(stderrPipe)

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.cleanupConfigFile()
            }
        }

        self.process = process
        try process.run()
        isRunning = true

        try await Task.sleep(nanoseconds: 500_000_000)

        if !process.isRunning {
            isRunning = false
            throw BridgeError.launchFailed(reason: "sslocal exited immediately")
        }
    }

    // MARK: - Terminate

    /// Gracefully terminate sslocal (SIGTERM)
    func terminate() async throws {
        guard let process, isRunning else { return }

        process.interrupt() // SIGTERM equivalent

        // Wait for process to exit (up to 3 seconds)
        let deadline = Date().addingTimeInterval(3.0)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        // Force kill if still running
        if process.isRunning {
            process.terminate() // SIGKILL
        }

        isRunning = false
        cleanupConfigFile()
        self.process = nil
    }

    // MARK: - Log Access

    /// Get recent sslocal log output
    func getRecentLogs() -> [String] {
        recentLogs
    }

    // MARK: - Crash Detection

    /// Whether the process crashed (exited unexpectedly while we expected it to run)
    var didCrash: Bool {
        guard let process else { return false }
        return !process.isRunning && isRunning // We think it should be running but it's not
    }

    // MARK: - Private Helpers

    private func setupLogMonitoring(_ pipe: Pipe) {
        recentLogs.removeAll()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let output = String(data: data, encoding: .utf8) else { return }

            let lines = output.split(separator: "\n").map(String.init)
            DispatchQueue.main.async {
                self?.appendLogs(lines)
            }
        }
    }

    private func appendLogs(_ lines: [String]) {
        recentLogs.append(contentsOf: lines)
        if recentLogs.count > maxLogLines {
            recentLogs = recentLogs.suffix(maxLogLines)
        }
    }

    private func cleanupConfigFile() {
        if let configFilePath {
            try? FileManager.default.removeItem(at: configFilePath)
            self.configFilePath = nil
        }
    }
}

// MARK: - Errors

enum BridgeError: LocalizedError {
    case binaryNotFound
    case launchFailed(reason: String)
    case terminateFailed
    case configWriteFailed

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "找不到 sslocal 程序，请确认已嵌入到应用包内"
        case .launchFailed(let reason):
            return "sslocal 启动失败：\(reason)"
        case .terminateFailed:
            return "sslocal 停止失败"
        case .configWriteFailed:
            return "配置文件写入失败"
        }
    }
}
