import Foundation
import Observation

@Observable
final class AppModel {
    let client: ATProtoClient

    var isAuthenticated: Bool = false
    var currentHandle: String?
    var isRefreshing: Bool = false
    var lastError: String?
    var isOffline: Bool = false

    init(client: ATProtoClient) {
        self.client = client
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
