import SwiftUI
import SwiftData

@main
struct BlueskyReaderApp: App {
    let container: ModelContainer
    let appModel: AppModel

    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            var inMemory = false
            #if DEBUG
            // Sample data never touches the on-disk store, so it can't leak into a real list.
            inMemory = SampleData.isRequested
            #endif
            container = try ModelContainer(
                for: LinkItem.self, IngestState.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
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
