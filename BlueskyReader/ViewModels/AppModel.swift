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
    /// Non-offline status text for the reading list's status strip (rate limiting,
    /// server errors, decoding failures). Cleared on the next successful refresh.
    var bannerMessage: String?
    /// Set when a refresh had to sign the user out (expired/invalid credentials) so
    /// LoginView can explain why they're back at the login screen.
    var loginMessage: String?

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
            bannerMessage = nil
            Task { await headlineResolver.resolveUnresolvedHeadlines(context: context) }
        } catch {
            await handleRefreshError(error, context: context)
        }
    }

    private func handleRefreshError(_ error: Error, context: ModelContext) async {
        guard let atError = error as? ATProtoError else {
            bannerMessage = "Couldn't read the timeline response."
            return
        }

        switch atError {
        case .network:
            isOffline = true

        case .invalidCredentials, .notAuthenticated:
            await logout(context: context)
            loginMessage = "Your Bluesky session ended. Sign in again."

        case .rateLimited(let retryAfter):
            if let retryAfter {
                let minutes = max(1, Int((retryAfter / 60).rounded(.up)))
                bannerMessage = "Bluesky is rate-limiting requests. Try again in \(minutes) min."
            } else {
                bannerMessage = "Bluesky is rate-limiting requests. Try again shortly."
            }

        case .server(let status, _):
            bannerMessage = "Bluesky returned an error (\(status)). Pull to retry."

        case .decoding, .expiredToken:
            bannerMessage = "Couldn't read the timeline response."
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
            loginMessage = nil
        } catch {
            isAuthenticated = false
            throw error
        }
    }

    /// Signs out and clears this device's account data (saved articles, ingest
    /// checkpoint). `SiteNameCache` is host metadata, not account data, so it's left
    /// alone.
    func logout(context: ModelContext) async {
        do {
            try context.delete(model: LinkItem.self)
            try context.delete(model: IngestState.self)
            try context.save()
        } catch {
            // Best-effort: still proceed to clear the session below even if the
            // local delete failed.
        }
        await client.logout()
        isAuthenticated = false
        currentHandle = nil
    }
}
