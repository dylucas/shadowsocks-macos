// AppDelegate — Handles lifecycle, cleanup, and system proxy rollback on exit

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var proxyService: ProxyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure system proxy is off at startup (safety net if previous session crashed)
        let systemProxy = SystemProxyService()
        if systemProxy.isProxyEnabled() {
            systemProxy.disable()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Rollback system proxy on normal exit
        if let proxyService {
            proxyService.stopSync()
        }
    }

    /// Inject ProxyService reference for cleanup
    func configure(proxyService: ProxyService) {
        self.proxyService = proxyService
    }
}
