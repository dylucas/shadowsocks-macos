// SubscriptionView — Manage subscription sources

import SwiftUI

struct SubscriptionView: View {
    @ObservedObject var serverStore: ServerStore
    @ObservedObject var subscriptionStore: SubscriptionStore
    @State private var showingAddSubscription = false
    @State private var updatingSubID: UUID?
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // === Subscription List ===
            if subscriptionStore.subscriptions.isEmpty {
                emptyState
            } else {
                List(subscriptionStore.subscriptions) { sub in
                    subscriptionRow(sub)
                }
                .listStyle(.sidebar)
            }

            Divider()

            // === Bottom Bar ===
            HStack {
                Button {
                    showingAddSubscription = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    updateAllSubscriptions()
                } label: {
                    Label("全部更新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddSubscriptionView(subscriptionStore: subscriptionStore, serverStore: serverStore)
        }
        .alert("订阅更新失败", isPresented: $showError) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("还没有订阅源")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("添加订阅") {
                showingAddSubscription = true
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Subscription Row

    private func subscriptionRow(_ sub: Subscription) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name)
                    .font(.body)
                Text(sub.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let lastUpdated = sub.lastUpdatedAt {
                    Text("上次更新: \(lastUpdated.formatted(.dateTime.hour().minute()))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if updatingSubID == sub.id {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                Button {
                    updateSubscription(sub)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Update Actions

    private func updateSubscription(_ sub: Subscription) {
        updatingSubID = sub.id

        let updateService = SubscriptionUpdateService(
            serverStore: serverStore,
            subscriptionStore: subscriptionStore
        )

        Task {
            do {
                let servers = try await updateService.fetchSubscription(sub)
                try updateService.mergeServers(fetched: servers, from: sub)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            updatingSubID = nil
        }
    }

    private func updateAllSubscriptions() {
        let updateService = SubscriptionUpdateService(
            serverStore: serverStore,
            subscriptionStore: subscriptionStore
        )
        let needsUpdate = updateService.subscriptionsNeedingUpdate()
        for sub in needsUpdate {
            updateSubscription(sub)
        }
    }
}

// MARK: - Add Subscription View

struct AddSubscriptionView: View {
    @ObservedObject var subscriptionStore: SubscriptionStore
    @ObservedObject var serverStore: ServerStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var url = ""
    @State private var updateInterval = 6

    var body: some View {
        VStack(spacing: 16) {
            Text("添加订阅")
                .font(.headline)

            Form {
                TextField("名称", text: $name)
                TextField("订阅链接", text: $url)

                Picker("更新频率", selection: $updateInterval) {
                    Text("每小时").tag(1)
                    Text("每 6 小时").tag(6)
                    Text("每 12 小时").tag(12)
                    Text("每 24 小时").tag(24)
                }

                Button("从剪贴板识别") {
                    if let content = PasteboardParser.detectShadowsocksContent() {
                        url = content
                    }
                }
            }

            HStack {
                Button("取消") { dismiss() }
                Button("添加并更新") {
                    saveAndFetch()
                }
                .disabled(url.isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func saveAndFetch() {
        guard !url.isEmpty else { return }
        let sub = Subscription(
            name: name,
            url: url,
            updateIntervalHours: updateInterval
        )
        subscriptionStore.add(sub)

        // Immediately fetch servers from this subscription
        let updateService = SubscriptionUpdateService(
            serverStore: serverStore,
            subscriptionStore: subscriptionStore
        )

        Task {
            do {
                let servers = try await updateService.fetchSubscription(sub)
                try updateService.mergeServers(fetched: servers, from: sub)
            } catch {
                // Subscription added but fetch failed — user can retry manually
            }
            dismiss()
        }
    }
}
