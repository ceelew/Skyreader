import SwiftUI
import SwiftData

struct ReadingListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LinkItem.appearedAt, order: .reverse) private var items: [LinkItem]

    var body: some View {
        NavigationStack {
            List {
                if let count = appModel.lastRefreshNewItemCount {
                    Section {
                        Text("Last refresh added \(count) new item\(count == 1 ? "" : "s"). \(items.count) total.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = appModel.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.headline)
                            .font(.subheadline.weight(.semibold))
                        Text("\(item.publication) · shared by @\(item.sharedByHandle) · \(item.appearedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !item.headlineResolved {
                            Text("headline unresolved")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Reading List (debug)")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if appModel.isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task { await appModel.refreshTimeline(context: modelContext) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out", role: .destructive) {
                        Task { await appModel.logout() }
                    }
                }
            }
            .task {
                if items.isEmpty {
                    await appModel.refreshTimeline(context: modelContext)
                }
            }
            .refreshable {
                await appModel.refreshTimeline(context: modelContext)
            }
        }
    }
}

#Preview {
    ReadingListView()
        .environment(AppModel(client: ATProtoClient()))
}
