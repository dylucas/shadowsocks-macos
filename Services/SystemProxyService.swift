// SystemProxyService — macOS system SOCKS5 proxy configuration via networksetup

import Foundation

enum ProxyMode: String, CaseIterable, Codable {
    case global = "全局代理"
    case pac = "PAC 自动代理"
    case direct = "直连（不使用代理）"
}

final class SystemProxyService {
    private let networkSetupPath = "/usr/sbin/networksetup"
    private var savedProxySettings: [String: ProxySetting] = [:]

    // MARK: - Proxy State

    /// Check if SOCKS5 proxy is currently enabled on any interface
    func isProxyEnabled() -> Bool {
        let interfaces = networkInterfaces()
        return interfaces.contains { interface ->
            Bool in
            getSocksProxyState(for: interface).enabled
        }
    }

    // MARK: - Enable Proxy

    /// Enable SOCKS5 system proxy on all network interfaces
    func enable(socks5Port: UInt16, mode: ProxyMode = .global) throws {
        let interfaces = networkInterfaces()

        // Save current settings for rollback
        saveCurrentSettings(interfaces: interfaces)

        for interface in interfaces {
            switch mode {
            case .global:
                setSocksProxy(for: interface, host: "127.0.0.1", port: socks5Port)
            case .pac:
                setAutoProxyURL(for: interface, url: pacFileURL())
            case .direct:
                // Don't enable anything
                break
            }
        }
    }

    // MARK: - Disable Proxy

    /// Disable SOCKS5 system proxy and restore previous settings
    func disable() {
        let interfaces = networkInterfaces()

        for interface in interfaces {
            // Restore saved settings if available
            if let saved = savedProxySettings[interface] {
                if saved.enabled {
                    setSocksProxy(for: interface, host: saved.host, port: saved.port)
                } else {
                    disableSocksProxy(for: interface)
                }
            } else {
                // No saved settings — just disable
                disableSocksProxy(for: interface)
                disableAutoProxyURL(for: interface)
            }
        }

        savedProxySettings.removeAll()
    }

    // MARK: - Network Interfaces

    /// Get all active network service names
    private func networkInterfaces() -> [String] {
        let result = runNetworkSetup(["-listallnetworkservices"])
        guard result.success else { return ["Wi-Fi"] } // Fallback

        let lines = result.output.split(separator: "\n").map(String.init)
        // First line is header "An asterisk (*) denotes..."
        return lines.dropFirst().filter { !$0.hasPrefix("*") && !$0.isEmpty }
    }

    // MARK: - SOCKS5 Proxy

    private func setSocksProxy(for interface: String, host: String, port: UInt16) {
        runNetworkSetup(["-setsocksfirewallproxy", interface, host, String(port)])
        // Enable the proxy setting
        runNetworkSetup(["-setsocksfirewallproxystate", interface, "on"])
    }

    private func disableSocksProxy(for interface: String) {
        runNetworkSetup(["-setsocksfirewallproxystate", interface, "off"])
    }

    private func getSocksProxyState(for interface: String) -> ProxySetting {
        let result = runNetworkSetup(["-getsocksfirewallproxy", interface])
        guard result.success else {
            return ProxySetting(enabled: false, host: "", port: 0)
        }

        let lines = result.output.split(separator: "\n").map(String.init)
        var enabled = false
        var host = ""
        var port: UInt16 = 0

        for line in lines {
            if line.hasPrefix("Enabled: Yes") { enabled = true }
            if line.hasPrefix("Server: ") { host = String(line.dropFirst("Server: ".count)) }
            if line.hasPrefix("Port: ") { port = UInt16(String(line.dropFirst("Port: ".count))) ?? 0 }
        }

        return ProxySetting(enabled: enabled, host: host, port: port)
    }

    // MARK: - PAC Auto Proxy

    private func setAutoProxyURL(for interface: String, url: String) {
        runNetworkSetup(["-setautoproxyurl", interface, url])
        runNetworkSetup(["-setautoproxystate", interface, "on"])
    }

    private func disableAutoProxyURL(for interface: String) {
        runNetworkSetup(["-setautoproxystate", interface, "off"])
    }

    /// Generate PAC file URL (local file URL)
    private func pacFileURL() -> String {
        // Write PAC file to app support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pacDir = appSupport.appendingPathComponent("Shadowsocks", isDirectory: true)
        try? FileManager.default.createDirectory(at: pacDir, withIntermediateDirectories: true)

        let pacFile = pacDir.appendingPathComponent("proxy.pac")

        // Write default PAC content
        let pacContent = DefaultPAC.generate(socks5Host: "127.0.0.1", socks5Port: 1080)
        try? pacContent.write(to: pacFile, atomically: true, encoding: .utf8)

        return "file://\(pacFile.path)"
    }

    // MARK: - Save/Restore

    private func saveCurrentSettings(interfaces: [String]) {
        savedProxySettings.removeAll()
        for interface in interfaces {
            savedProxySettings[interface] = getSocksProxyState(for: interface)
        }
    }

    // MARK: - Shell Execution

    private func runNetworkSetup(_ arguments: [String]) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: networkSetupPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return ShellResult(success: process.terminationStatus == 0, output: output)
        } catch {
            return ShellResult(success: false, output: error.localizedDescription)
        }
    }
}

// MARK: - Helper Types

struct ProxySetting {
    let enabled: Bool
    let host: String
    let port: UInt16
}

struct ShellResult {
    let success: Bool
    let output: String
}
