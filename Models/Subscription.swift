// Subscription Model — Represents a subscription source that provides server configs

import Foundation
import Combine

struct Subscription: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
    var lastUpdatedAt: Date?
    var updateIntervalHours: Int // default 6
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        url: String,
        lastUpdatedAt: Date? = nil,
        updateIntervalHours: Int = 6,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name.isEmpty ? url : name
        self.url = url
        self.lastUpdatedAt = lastUpdatedAt
        self.updateIntervalHours = updateIntervalHours
        self.isActive = isActive
    }
}

// MARK: - Subscription Store

final class SubscriptionStore: ObservableObject {
    @Published private(set) var subscriptions: [Subscription] = []

    private let defaults = UserDefaults.standard
    private let subsKey = "shadowsocks_subscriptions"

    init() {
        loadSubscriptions()
    }

    func add(_ subscription: Subscription) {
        subscriptions.append(subscription)
        saveToDefaults()
    }

    func update(_ subscription: Subscription) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        subscriptions[index] = subscription
        saveToDefaults()
    }

    func delete(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        saveToDefaults()
    }

    func updateLastUpdated(for subID: UUID) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subID }) else { return }
        subscriptions[index].lastUpdatedAt = Date()
        saveToDefaults()
    }

    private func loadSubscriptions() {
        guard let data = defaults.data(forKey: subsKey) else { return }
        guard let decoded = try? JSONDecoder().decode([Subscription].self, from: data) else { return }
        subscriptions = decoded
    }

    private func saveToDefaults() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(subscriptions) else { return }
        defaults.set(data, forKey: subsKey)
    }
}
