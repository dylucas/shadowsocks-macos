// ServerStore — CRUD operations for server configurations
// Passwords stored in Keychain separately from UserDefaults

import Foundation
import Combine

final class ServerStore: ObservableObject {
    @Published private(set) var servers: [Server] = []

    private let defaults = UserDefaults.standard
    private let serversKey = "shadowsocks_servers"

    // MARK: - Lifecycle

    init() {
        loadServers()
    }

    // MARK: - CRUD

    func add(_ server: Server) throws {
        // Save password to Keychain
        if !server.password.isEmpty {
            try KeychainHelper.save(password: server.password, for: server.id)
        }

        // Save server config (without password) to UserDefaults
        var serverForStorage = server
        serverForStorage.password = "" // Never store password in UserDefaults
        servers.append(serverForStorage)
        saveToDefaults()
    }

    func update(_ server: Server) throws {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else {
            return
        }

        // Update password in Keychain
        if !server.password.isEmpty {
            try KeychainHelper.save(password: server.password, for: server.id)
        }

        var serverForStorage = server
        serverForStorage.password = ""
        servers[index] = serverForStorage
        saveToDefaults()
    }

    func delete(_ server: Server) {
        servers.removeAll { $0.id == server.id }
        KeychainHelper.delete(for: server.id)
        saveToDefaults()
    }

    func deleteAll() {
        servers.forEach { KeychainHelper.delete(for: $0.id) }
        servers.removeAll()
        saveToDefaults()
    }

    // MARK: - Password Access

    /// Retrieve the full server with password from Keychain
    func serverWithPassword(id: UUID) -> Server? {
        guard var server = servers.first(where: { $0.id == id }) else { return nil }
        server.password = KeychainHelper.load(for: id) ?? ""
        return server
    }

    /// Retrieve all servers with passwords from Keychain
    func allServersWithPasswords() -> [Server] {
        servers.map { server ->
            Server in
            var s = server
            s.password = KeychainHelper.load(for: s.id) ?? ""
            return s
        }
    }

    // MARK: - Latency Updates

    func updateLatency(for serverID: UUID, latency: Int?) {
        guard let index = servers.firstIndex(where: { $0.id == serverID }) else { return }
        servers[index].latency = latency
        servers[index].lastTestedAt = latency != nil ? Date() : nil
        saveToDefaults()
    }

    // MARK: - Persistence

    private func loadServers() {
        guard let data = defaults.data(forKey: serversKey) else { return }
        guard let decoded = try? JSONDecoder().decode([Server].self, from: data) else { return }
        servers = decoded
    }

    private func saveToDefaults() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(servers) else { return }
        defaults.set(data, forKey: serversKey)
    }
}
