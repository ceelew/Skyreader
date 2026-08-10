import SwiftUI
import SwiftData

struct ReadingListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LinkItem.appearedAt, order: .reverse) private var items: [LinkItem]

    @State private var readerURL: IdentifiableURL?

    private struct DaySection: Identifiable {
        let id: Date
        let label: String
        let items: [LinkItem]
    }

    private var sections: [DaySection] {
        let grouped = Dictionary(grouping: items) { DateGrouping.dayKey(for: $0.appearedAt) }
        return grouped.keys.sorted(by: >).map { key in
            DaySection(id: key, label: DateGrouping.sectionLabel(for: key), items: grouped[key] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty && !appModel.isRefreshing {
                    ContentUnavailableView(
                        "No articles yet",
                        systemImage: "tray",
                        description: Text("Pull to refresh to check your timeline for links.")
                    )
                } else {
                    List {
                        ForEach(sections) { section in
                            Section(section.label) {
                                ForEach(section.items) { item in
                                    LinkRowView(item: item)
                                        .onTapGesture { open(item) }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Reading List")
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
                    .font(.footnote)
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
            .sheet(item: $readerURL) { wrapped in
                ReaderView(url: wrapped.url)
                    .ignoresSafeArea()
            }
        }
    }

    private func open(_ item: LinkItem) {
        guard let url = URL(string: item.originalURL) else { return }
        item.isRead = true
        try? modelContext.save()
        readerURL = IdentifiableURL(url: url)
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

#Preview {
    ReadingListView()
        .environment(AppModel(client: ATProtoClient()))
}
