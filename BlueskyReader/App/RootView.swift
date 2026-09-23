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
        .tint(Color.accent)
        .task {
            guard !didRestoreSession else { return }
            #if DEBUG
            if SampleData.isRequested {
                SampleData.seed(into: modelContext)
                appModel.isSampleDataMode = true
                appModel.isAuthenticated = true
                appModel.currentHandle = "sample.bsky.social"
                didRestoreSession = true
                return
            }
            #endif
            await appModel.restoreSession()
            didRestoreSession = true
        }
    }
}
