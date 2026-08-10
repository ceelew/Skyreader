import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var didRestoreSession = false

    var body: some View {
        Group {
            if !didRestoreSession {
                ProgressView()
            } else if appModel.isAuthenticated {
                ReadingListView()
            } else {
                LoginView()
            }
        }
        .task {
            guard !didRestoreSession else { return }
            await appModel.restoreSession()
            didRestoreSession = true
        }
    }
}
