import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AppModel {
    let client: ATProtoClient
    let ingestService: IngestService
    let headlineResolver: HeadlineResolver

    var isAuthenticated: Bool = false
    var currentHandle: String?
    var isRefreshing: Bool = false
    var isOffline: Bool = false
    var lastRefreshNewItemCount: Int?
    var lastRefreshDate: Date?

    private let staleThreshold: TimeInterval = 15 * 60

    init(client: ATProtoClient) {
        self.client = client
        self.ingestService = IngestService(client: client)
        self.headlineResolver = HeadlineResolver()
    }

    func refreshTimeline(context: ModelContext) async {
        guard isAuthenticated, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let result = try await ingestService.refresh(context: context)
            lastRefreshNewItemCount = result.newItemCount
            lastRefreshDate = Date()
            isOffline = false
            Task { await headlineResolver.resolveUnresolvedHeadlines(context: context) }
        } catch {
            if let urlError = (error as? ATProtoError), case .network = urlError {
                isOffline = true
            }
        }
    }

    /// Called when the app returns to the foreground — refreshes only if it's
    /// been a while, so backgrounding briefly doesn't spam the API (§5).
    func refreshIfStale(context: ModelContext) async {
        guard isAuthenticated, !isRefreshing else { return }
        if let lastRefreshDate, Date().timeIntervalSince(lastRefreshDate) < staleThreshold { return }
        await refreshTimeline(context: context)
    }

    /// Call on launch to sync UI state with the persisted session.
    func restoreSession() async {
        let authed = await client.isAuthenticated
        isAuthenticated = authed
        currentHandle = await client.handle
    }

    func login(handle: String, appPassword: String) async throws {
        do {
            try await client.login(handle: handle, appPassword: appPassword)
            isAuthenticated = true
            currentHandle = await client.handle
        } catch {
            isAuthenticated = false
            throw error
        }
    }

    func logout() async {
        await client.logout()
        isAuthenticated = false
        currentHandle = nil
    }
}
