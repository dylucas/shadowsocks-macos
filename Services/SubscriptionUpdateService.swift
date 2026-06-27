// SubscriptionUpdateService — Fetch and merge subscription updates

import Foundation

final class SubscriptionUpdateService {
    private let serverStore: ServerStore
    private let subscriptionStore: SubscriptionStore
    private let urlSession: URLSession

    init(
        serverStore: ServerStore,
        subscriptionStore: SubscriptionStore,
        urlSession: URLSession = .shared
    ) {
        self.serverStore = serverStore
        self.subscriptionStore = subscriptionStore
        self.urlSession = urlSession
    }

    // MARK: - Fetch Subscription

    /// Fetch a subscription URL and parse into servers
    func fetchSubscription(_ subscription: Subscription) async throws -> [Server] {
        guard let url = URL(string: subscription.url) else {
            throw UpdateError.invalidURL
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw UpdateError.networkError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw UpdateError.invalidContent
        }

        return try SubscriptionParser.parse(content)
    }

    // MARK: - Merge Servers

    /// Merge fetched servers: remove servers from THIS subscription, then add fetched ones.
    /// Preserve manual servers and servers from OTHER subscriptions.
    func mergeServers(fetched: [Server], from subscription: Subscription) throws {
        // Remove servers that came from this subscription (matched by address+port)
        let fetchedAddresses = Set(fetched.map { "\( $0.address):\( $0.port)" })
        let toRemove = serverStore.servers.filter {
            !$0.isManual && fetchedAddresses.contains("\($0.address):\($0.port)")
        }
        for server in toRemove {
            serverStore.delete(server)
        }

        // Add all fetched servers (marked as non-manual)
        for server in fetched {
            var newServer = server
            newServer.isManual = false
            try serverStore.add(newServer)
        }

        // Update subscription lastUpdated timestamp
        subscriptionStore.updateLastUpdated(for: subscription.id)
    }

    // MARK: - Auto Update

    /// Check all subscriptions for update eligibility (based on interval)
    func subscriptionsNeedingUpdate() -> [Subscription] {
        let now = Date()
        return subscriptionStore.subscriptions.filter { sub ->
            Bool in
            guard sub.isActive else { return false }
            guard let lastUpdated = sub.lastUpdatedAt else { return true } // Never updated
            let interval = TimeInterval(sub.updateIntervalHours * 3600)
            return now.timeIntervalSince(lastUpdated) >= interval
        }
    }
}

// MARK: - Errors

enum UpdateError: LocalizedError {
    case invalidURL
    case networkError(statusCode: Int)
    case invalidContent

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "订阅链接格式不正确"
        case .networkError(let code):
            return "网络请求失败（状态码: \(code)）"
        case .invalidContent:
            return "订阅内容无法解析"
        }
    }
}
