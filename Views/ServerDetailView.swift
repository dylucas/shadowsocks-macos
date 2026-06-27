// ServerDetailView — Edit and test a single server configuration

import SwiftUI

struct ServerDetailView: View {
    @ObservedObject var serverStore: ServerStore
    @ObservedObject var proxyService: ProxyService
    let serverID: UUID

    @State private var name: String = ""
    @State private var address: String = ""
    @State private var port: String = ""
    @State private var cipher: CipherMethod = .aes256Gcm
    @State private var password: String = ""
    @State private var remark: String = ""
    @State private var isTesting = false
    @State private var testResult: Int?

    var body: some View {
        Form {
            TextField("名称", text: $name)
            TextField("服务器地址", text: $address)
            TextField("端口", text: $port)
            Picker("加密方式", selection: $cipher) {
                ForEach(CipherMethod.allCases, id: \.rawValue) { method in
                    HStack {
                        Text(method.displayName)
                        if method.usesArmAES {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.blue)
                                .help("支持 M芯片 AES 硬件加速")
                        }
                    }
                    .tag(method)
                }
            }
            SecureField("密码", text: $password)
            TextField("备注", text: $remark)

            Divider()

            // Hardware acceleration info
            if cipher.usesArmAES {
                let accel = CryptoAccelerator.accelerationSummary()
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.blue)
                    Text(accel.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Latency test
            HStack {
                Button("测试延迟") {
                    testLatency()
                }
                .disabled(isTesting)

                if isTesting {
                    ProgressView()
                        .scaleEffect(0.5)
                }

                if let latency = testResult {
                    let color: Color = latency < 100 ? .green : (latency < 300 ? .orange : .red)
                    Text("\(latency) ms")
                        .foregroundColor(color)
                        .font(.title3.monospacedDigit())
                }
            }

            // Connect button
            Button("连接此服务器") {
                Task {
                    try? await proxyService.start(serverID: serverID)
                }
            }
            .disabled(proxyService.isActive && proxyService.activeServerID == serverID)
        }
        .padding()
        .onAppear {
            loadServerData()
        }
    }

    // MARK: - Load Data

    private func loadServerData() {
        guard let server = serverStore.serverWithPassword(id: serverID) else { return }
        name = server.name
        address = server.address
        port = String(server.port)
        cipher = server.cipher
        password = server.password
        remark = server.remark
        testResult = server.latency
    }

    // MARK: - Save

    private func saveChanges() {
        guard let portNum = UInt16(port) else { return }
        let updated = Server(
            id: serverID,
            name: name,
            address: address,
            port: portNum,
            cipher: cipher,
            password: password,
            remark: remark
        )
        try? serverStore.update(updated)
    }

    // MARK: - Test Latency

    private func testLatency() {
        isTesting = true
        testResult = nil

        Task {
            let result = await proxyService.testLatency(for: serverID)
            testResult = result
            isTesting = false
        }
    }
}
