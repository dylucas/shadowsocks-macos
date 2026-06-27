// Shadowsocks macOS Client — App Entry Point
// SwiftUI MenuBarExtra-based status bar app (no Dock icon)

import SwiftUI

@main
struct ShadowsocksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var proxyService = ProxyService()

    var body: some Scene {
        MenuBarExtra("Shadowsocks", systemImage: proxyService.isActive ? "shield.fill" : "shield") {
            StatusBarView(proxyService: proxyService)
        }

        Settings {
            SettingsView(proxyService: proxyService)
        }
    }
}
