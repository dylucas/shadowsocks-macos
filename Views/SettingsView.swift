// SettingsView — General application settings (port, proxy mode, auto-start, etc.)

import SwiftUI

struct SettingsView: View {
    @ObservedObject var proxyService: ProxyService

    @AppStorage("localPort") private var localPort: Int = 1080
    @AppStorage("proxyMode") private var proxyModeRaw: String = ProxyMode.pac.rawValue
    @AppStorage("autoStart") private var autoStart: Bool = false
    @AppStorage("updateInterval") private var updateInterval: Int = 6
    @AppStorage("showLatencyInList") private var showLatencyInList: Bool = true

    private var proxyMode: ProxyMode {
        get { ProxyMode(rawValue: proxyModeRaw) ?? .pac }
        set { proxyModeRaw = newValue.rawValue }
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            serverTab
                .tabItem {
                    Label("服务器", systemImage: "server.rack")
                }

            subscriptionTab
                .tabItem {
                    Label("订阅", systemImage: "link")
                }

            aboutTab
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            // Local port
            Picker("本地 SOCKS5 端口", selection: $localPort) {
                Text("1080").tag(1080)
                Text("1081").tag(1081)
                Text("1086").tag(1086)
                Text("自定义").tag(0)
            }

            // Proxy mode
            Picker("代理模式", selection: $proxyMode) {
                ForEach(ProxyMode.allCases, id: \.rawValue) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            // Auto start
            Toggle("开机自动启动", isOn: $autoStart)

            // Show latency
            Toggle("列表显示延迟", isOn: $showLatencyInList)

            // Update interval
            Picker("订阅更新频率", selection: $updateInterval) {
                Text("每小时").tag(1)
                Text("每 6 小时").tag(6)
                Text("每 12 小时").tag(12)
                Text("每 24 小时").tag(24)
                Text("仅手动更新").tag(0)
            }

            Divider()

            // Hardware acceleration info
            let accel = CryptoAccelerator.accelerationSummary()
            HStack {
                Label("硬件加速", systemImage: "bolt.fill")
                Spacer()
                Text(accel.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Server Tab

    private var serverTab: some View {
        ServerListView(
            serverStore: ServerStore(),
            proxyService: proxyService
        )
    }

    // MARK: - Subscription Tab

    private var subscriptionTab: some View {
        SubscriptionView(
            serverStore: ServerStore(),
            subscriptionStore: SubscriptionStore()
        )
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Shadowsocks")
                .font(.largeTitle)

            Text("macOS Apple Silicon 原生客户端")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("版本 1.0.0")
                .font(.caption)

            Divider()

            Text("Powered by shadowsocks-rust")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("MIT License")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
