// StatusBarView — Main MenuBarExtra popup panel
// Shows proxy status, server list, and quick actions

import SwiftUI

struct StatusBarView: View {
    @ObservedObject var proxyService: ProxyService
    @ObservedObject var serverStore: ServerStore
    @ObservedObject var subscriptionStore: SubscriptionStore
    @State private var selectedServerID: UUID?
    @State private var showingSettings = false
    @State private var showingAddServer = false
    @State private var showingAddSubscription = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // === Status Header ===
            statusHeader

            Divider()

            // === Server List ===
            if serverStore.servers.isEmpty {
                emptyState
            } else {
                serverList
            }

            Divider()

            // === Quick Actions ===
            actionButtons
        }
        .frame(width: 280)
        .padding(12)
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack {
            Image(systemName: proxyService.isActive ? "shield.fill" : "shield")
                .foregroundColor(proxyService.isActive ? .blue : .secondary)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(proxyService.isActive ? "已连接" : "未连接")
                    .font(.headline)
                if let activeID = proxyService.activeServerID,
                   let server = serverStore.serverWithPassword(id: activeID) {
                    Text(server.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if proxyService.isActive {
                Button {
                    Task { try? await proxyService.stop() }
                } label: {
                    Image(systemName: "stop.circle")
                }
                .buttonStyle(.borderless)
                .help("断开连接")
            }
        }
    }

    // MARK: - Server List

    private var serverList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(sortedServers) { server in
                    serverRow(server)
                }
            }
        }
        .frame(maxHeight: 200)
    }

    private func serverRow(_ server: Server) -> some View {
        HStack(spacing: 8) {
            // Selection indicator
            Circle()
                .fill(proxyService.activeServerID == server.id ? Color.blue : Color.clear)
                .frame(width: 8, height: 8)

            // Server info
            VStack(alignment: .leading, spacing: 1) {
                Text(server.displayName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(server.address)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let latency = server.latency {
                        latencyBadge(latency)
                    }
                }
            }

            Spacer()

            // Quick connect button
            if !proxyService.isActive || proxyService.activeServerID != server.id {
                Button {
                    Task {
                        do {
                            try await proxyService.start(
                                serverID: server.id,
                                serverStore: serverStore
                            )
                        } catch {
                            // Error shown via proxyService.errorMessage
                        }
                    }
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.borderless)
                .help("连接此服务器")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedServerID = server.id
        }
    }

    private func latencyBadge(_ latency: Int) -> some View {
        let color: Color = latency < 100 ? .green : (latency < 300 ? .orange : .red)
        return Text("\(latency)ms")
            .font(.caption2)
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    // MARK: - Sorted Servers

    private var sortedServers: [Server] {
        serverStore.servers.sorted { a, b in
            // Active server first, then by latency
            if proxyService.activeServerID == a.id { return true }
            if proxyService.activeServerID == b.id { return false }
            let latA = a.latency ?? Int.max
            let latB = b.latency ?? Int.max
            return latA < latB
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("还没有服务器配置")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button("添加服务器") {
                    showingAddServer = true
                }
                .buttonStyle(.borderless)
                Button("导入订阅") {
                    showingAddSubscription = true
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack {
            Button {
                Task {
                    let results = await NetworkService.batchLatencyTest(
                        servers: serverStore.allServersWithPasswords()
                    )
                    for (id, latency) in results {
                        serverStore.updateLatency(for: id, latency: latency)
                    }
                }
            } label: {
                Label("测速", systemImage: "gauge")
            }
            .buttonStyle(.borderless)

            Spacer()

            Button {
                showingAddServer = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)

            Button {
                showingAddSubscription = true
            } label: {
                Image(systemName: "link")
            }
            .buttonStyle(.borderless)
        }
        .sheet(isPresented: $showingAddServer) {
            AddServerView(serverStore: serverStore)
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddSubscriptionView(subscriptionStore: subscriptionStore, serverStore: serverStore)
        }
    }
}
