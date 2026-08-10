import SwiftUI
import SwiftData

@main
struct BlueskyReaderApp: App {
    let container: ModelContainer
    let appModel: AppModel

    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            container = try ModelContainer(for: LinkItem.self, IngestState.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        appModel = AppModel(client: ATProtoClient())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        BackgroundRefreshManager.scheduleNext()
                    }
                }
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(BackgroundRefreshManager.taskIdentifier)) {
            await BackgroundRefreshManager.performRefresh(client: appModel.client, container: container)
        }
    }
}
