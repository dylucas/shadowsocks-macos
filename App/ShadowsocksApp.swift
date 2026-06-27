// Shadowsocks macOS Client — App Entry Point
// SwiftUI MenuBarExtra-based status bar app (no Dock icon)

import SwiftUI

@main
struct ShadowsocksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Shared stores — single instances for the entire app
    @StateObject private var serverStore = ServerStore()
    @StateObject private var subscriptionStore = SubscriptionStore()
    @StateObject private var proxyService = ProxyService()

    var body: some Scene {
        MenuBarExtra("Shadowsocks", systemImage: proxyService.isActive ? "shield.fill" : "shield") {
            StatusBarView(
                proxyService: proxyService,
                serverStore: serverStore,
                subscriptionStore: subscriptionStore
            )
        }
        .task {
            // Connect AppDelegate to ProxyService for exit-time cleanup
            appDelegate.configure(proxyService: proxyService)
            proxyService.configure(serverStore: serverStore)
        }

        Settings {
            SettingsView(
                proxyService: proxyService,
                serverStore: serverStore,
                subscriptionStore: subscriptionStore
            )
        }
    }
}
