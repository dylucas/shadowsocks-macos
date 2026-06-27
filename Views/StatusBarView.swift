// StatusBarView — Main MenuBarExtra popup panel
// Sheets don't work in NSMenu popovers → use inline expansion or open Settings

import SwiftUI

struct StatusBarView: View {
    @ObservedObject var proxyService: ProxyService
    @ObservedObject var serverStore: ServerStore
    @ObservedObject var subscriptionStore: SubscriptionStore
    @State private var showAddServer = false
    @State private var showAddSubscription = false

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

            // === Inline Add Forms ===
            if showAddServer {
                Divider()
                inlineAddServer
            }
            if showAddSubscription {
                Divider()
                inlineAddSubscription
            }

            Divider()

            // === Quick Actions ===
            actionButtons
        }
        .frame(width: 300)
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
            } else if let first = sortedServers.first {
                Button {
                    Task {
                        try? await proxyService.start(serverID: first.id, serverStore: serverStore)
                    }
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.borderless)
                .help("快速连接")
            }
        }
    }

    // MARK: - Server List

    private var serverList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(sortedServers) { server in
                    serverRow(server)
                }
            }
        }
        .frame(maxHeight: 200)
    }

    private func serverRow(_ server: Server) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(proxyService.activeServerID == server.id ? Color.blue : Color.clear)
                .frame(width: 8, height: 8)

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

            if !proxyService.isActive || proxyService.activeServerID != server.id {
                Button {
                    Task {
                        try? await proxyService.start(serverID: server.id, serverStore: serverStore)
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
            Task {
                try? await proxyService.start(serverID: server.id, serverStore: serverStore)
            }
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

    private var sortedServers: [Server] {
        serverStore.servers.sorted { a, b in
            if proxyService.activeServerID == a.id { return true }
            if proxyService.activeServerID == b.id { return false }
            return (a.latency ?? Int.max) < (b.latency ?? Int.max)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("还没有服务器配置")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Inline Add Server

    private var inlineAddServer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("添加服务器").font(.headline)

            TextField("服务器地址", text: $addServerAddress)
                .textFieldStyle(.roundedBorder)
                .font(.body)
            HStack {
                TextField("端口", text: $addServerPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Picker("", selection: $addServerCipher) {
                    ForEach(CipherMethod.allCases, id: \.rawValue) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .frame(width: 180)
            }
            SecureField("密码", text: $addServerPassword)
                .textFieldStyle(.roundedBorder)
            TextField("备注", text: $addServerRemark)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") {
                    showAddServer = false
                    clearAddServerFields()
                }
                Spacer()
                Button("从剪贴板导入") {
                    if let content = PasteboardParser.detectShadowsocksContent() {
                        if let servers = try? SubscriptionParser.parse(content), let first = servers.first {
                            addServerAddress = first.address
                            addServerPort = String(first.port)
                            addServerCipher = first.cipher
                            addServerPassword = first.password
                            addServerRemark = first.remark
                        }
                    }
                }
                Button("添加") {
                    saveServer()
                }
                .disabled(addServerAddress.isEmpty || addServerPassword.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @State private var addServerAddress = ""
    @State private var addServerPort = "8388"
    @State private var addServerCipher: CipherMethod = .aes256Gcm
    @State private var addServerPassword = ""
    @State private var addServerRemark = ""

    private func saveServer() {
        guard !addServerAddress.isEmpty, let port = UInt16(addServerPort), !addServerPassword.isEmpty else { return }
        let server = Server(
            address: addServerAddress,
            port: port,
            cipher: addServerCipher,
            password: addServerPassword,
            remark: addServerRemark
        )
        try? serverStore.add(server)
        showAddServer = false
        clearAddServerFields()
    }

    private func clearAddServerFields() {
        addServerAddress = ""
        addServerPort = "8388"
        addServerCipher = .aes256Gcm
        addServerPassword = ""
        addServerRemark = ""
    }

    // MARK: - Inline Add Subscription

    private var inlineAddSubscription: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("导入订阅").font(.headline)

            TextField("订阅链接", text: $addSubURL)
                .textFieldStyle(.roundedBorder)

            Button("从剪贴板识别") {
                if let content = PasteboardParser.detectShadowsocksContent() {
                    addSubURL = content
                }
            }

            HStack {
                Button("取消") {
                    showAddSubscription = false
                    addSubURL = ""
                }
                Spacer()
                Button("导入") {
                    saveSubscription()
                }
                .disabled(addSubURL.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @State private var addSubURL = ""

    private func saveSubscription() {
        guard !addSubURL.isEmpty else { return }
        let sub = Subscription(url: addSubURL)
        subscriptionStore.add(sub)

        let updateService = SubscriptionUpdateService(serverStore: serverStore, subscriptionStore: subscriptionStore)
        Task {
            do {
                let servers = try await updateService.fetchSubscription(sub)
                try updateService.mergeServers(fetched: servers, from: sub)
            } catch { }
        }

        showAddSubscription = false
        addSubURL = ""
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

            if !showAddServer {
                Button {
                    showAddServer = true
                    showAddSubscription = false
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("添加服务器")
            }

            if !showAddSubscription {
                Button {
                    showAddSubscription = true
                    showAddServer = false
                } label: {
                    Image(systemName: "link")
                }
                .buttonStyle(.borderless)
                .help("导入订阅")
            }

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("设置")
        }
    }
}
