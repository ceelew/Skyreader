import SwiftUI
import SwiftData

@main
struct BlueskyReaderApp: App {
    let container: ModelContainer
    let appModel: AppModel

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
        }
        .modelContainer(container)
    }
}
