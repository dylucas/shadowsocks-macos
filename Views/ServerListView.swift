// ServerListView — Manage server list in settings window

import SwiftUI

struct ServerListView: View {
    @ObservedObject var serverStore: ServerStore
    @ObservedObject var proxyService: ProxyService
    @State private var searchText = ""
    @State private var selectedServerID: UUID?
    @State private var showingAddServer = false
    @State private var showingDeleteConfirmation = false
    @State private var serverToDelete: Server?

    var body: some View {
        VStack(spacing: 0) {
            // === Search Bar ===
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索服务器", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)

            Divider()

            // === Server List ===
            List(filteredServers, selection: $selectedServerID) { server in
                serverRow(server)
            }
            .listStyle(.sidebar)

            Divider()

            // === Bottom Bar ===
            HStack {
                Button {
                    showingAddServer = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Button {
                    if let id = selectedServerID {
                        serverToDelete = serverStore.servers.first { $0.id == id }
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedServerID == nil)

                Spacer()

                Button {
                    testAllLatencies()
                } label: {
                    Image(systemName: "gauge")
                }
                .buttonStyle(.borderless)
                .help("全部测速")
            }
            .padding(8)
        }
        .sheet(isPresented: $showingAddServer) {
            AddServerView(serverStore: serverStore)
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                if let server = serverToDelete {
                    serverStore.delete(server)
                    selectedServerID = nil
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let server = serverToDelete {
                Text("确定要删除服务器 \(server.displayName) 吗？")
            }
        }
    }

    // MARK: - Server Row

    private func serverRow(_ server: Server) -> some View {
        HStack(spacing: 12) {
            // Connection indicator
            Circle()
                .fill(proxyService.activeServerID == server.id ? Color.blue : Color.clear)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.displayName)
                    .font(.body)
                Text("\(server.address):\(server.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(server.cipher.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Latency badge
            if let latency = server.latency {
                Text("\(latency)ms")
                    .font(.caption)
                    .foregroundColor(latency < 100 ? .green : (latency < 300 ? .orange : .red))
            }
        }
    }

    // MARK: - Filtered Servers

    private var filteredServers: [Server] {
        if searchText.isEmpty {
            return serverStore.servers
        }
        return serverStore.servers.filter {
            $0.displayName.contains(searchText) ||
            $0.address.contains(searchText) ||
            $0.remark.contains(searchText)
        }
    }

    // MARK: - Latency Test

    private func testAllLatencies() {
        Task {
            let results = await NetworkService.batchLatencyTest(
                servers: serverStore.allServersWithPasswords()
            )
            for (id, latency) in results {
                serverStore.updateLatency(for: id, latency: latency)
            }
        }
    }
}

// MARK: - Add Server View

struct AddServerView: View {
    @ObservedObject var serverStore: ServerStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var port = "8388"
    @State private var cipher: CipherMethod = .aes256Gcm
    @State private var password = ""
    @State private var remark = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("添加服务器")
                .font(.headline)

            Form {
                TextField("名称", text: $name)
                TextField("服务器地址", text: $address)
                TextField("端口", text: $port)
                Picker("加密方式", selection: $cipher) {
                    ForEach(CipherMethod.allCases, id: \.rawValue) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                SecureField("密码", text: $password)
                TextField("备注", text: $remark)

                Button("从剪贴板导入 ss:// URL") {
                    if let content = PasteboardParser.detectShadowsocksContent() {
                        if let servers = try? SubscriptionParser.parse(content), let first = servers.first {
                            address = first.address
                            port = String(first.port)
                            cipher = first.cipher
                            password = first.password
                            remark = first.remark
                            name = first.name
                        }
                    }
                }
            }

            HStack {
                Button("取消") { dismiss() }
                Button("添加") { saveServer() }
                    .disabled(address.isEmpty || password.isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func saveServer() {
        guard !address.isEmpty, let portNum = UInt16(port), !password.isEmpty else { return }

        let server = Server(
            name: name,
            address: address,
            port: portNum,
            cipher: cipher,
            password: password,
            remark: remark
        )

        do {
            try serverStore.add(server)
            dismiss()
        } catch {
            // Handle error
        }
    }
}
