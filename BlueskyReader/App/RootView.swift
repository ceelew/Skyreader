import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @State private var didRestoreSession = false

    var body: some View {
        Group {
            if !didRestoreSession {
                ProgressView()
            } else if appModel.isAuthenticated {
                ReadingListView()
            } else {
                LoginView(signIn: { handle, appPassword in
                    try await appModel.login(handle: handle, appPassword: appPassword, context: modelContext)
                }, message: appModel.loginMessage)
            }
        }
        .task {
            guard !didRestoreSession else { return }
            await appModel.restoreSession()
            didRestoreSession = true
        }
    }
}
