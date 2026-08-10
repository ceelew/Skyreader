import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AppModel {
    let client: ATProtoClient
    let ingestService: IngestService

    var isAuthenticated: Bool = false
    var currentHandle: String?
    var isRefreshing: Bool = false
    var lastError: String?
    var isOffline: Bool = false
    var lastRefreshNewItemCount: Int?

    init(client: ATProtoClient) {
        self.client = client
        self.ingestService = IngestService(client: client)
    }

    func refreshTimeline(context: ModelContext) async {
        guard isAuthenticated, !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        do {
            let result = try await ingestService.refresh(context: context)
            lastRefreshNewItemCount = result.newItemCount
            isOffline = false
        } catch {
            lastError = error.localizedDescription
            if let urlError = (error as? ATProtoError), case .network = urlError {
                isOffline = true
            }
        }
    }

    /// Call on launch to sync UI state with the persisted session.
    func restoreSession() async {
        let authed = await client.isAuthenticated
        isAuthenticated = authed
        currentHandle = await client.handle
    }

    func login(handle: String, appPassword: String) async {
        lastError = nil
        do {
            try await client.login(handle: handle, appPassword: appPassword)
            isAuthenticated = true
            currentHandle = await client.handle
        } catch {
            lastError = error.localizedDescription
            isAuthenticated = false
        }
    }

    func logout() async {
        await client.logout()
        isAuthenticated = false
        currentHandle = nil
    }
}
