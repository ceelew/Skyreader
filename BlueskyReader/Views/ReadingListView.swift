import SwiftUI
import SwiftData

struct ReadingListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query(sort: \LinkItem.appearedAt, order: .reverse) private var items: [LinkItem]

    @AppStorage("hideReadItems") private var hideReadItems: Bool = false

    @State private var readerURL: IdentifiableURL?
    @State private var filter: ItemFilter = .all
    @State private var showingSettings = false
    @State private var shareURL: IdentifiableURL?

    private struct DaySection: Identifiable {
        let id: Date
        let label: String
        let items: [LinkItem]
    }

    private var filteredItems: [LinkItem] {
        items.filter { item in
            if hideReadItems && item.isRead { return false }
            switch filter {
            case .all: return true
            case .unread: return !item.isRead
            case .saved: return item.isSaved
            }
        }
    }

    private var sections: [DaySection] {
        let grouped = Dictionary(grouping: filteredItems) { DateGrouping.dayKey(for: $0.appearedAt) }
        return grouped.keys.sorted(by: >).map { key in
            DaySection(id: key, label: DateGrouping.sectionLabel(for: key), items: grouped[key] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if appModel.isOffline {
                    banner("Offline — showing saved articles", systemImage: "wifi.slash", tint: .orange)
                } else if let error = appModel.lastError {
                    banner(error, systemImage: "exclamationmark.triangle.fill", tint: .red)
                }

                Picker("Filter", selection: $filter) {
                    ForEach(ItemFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if filteredItems.isEmpty && !appModel.isRefreshing {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: emptyIcon,
                        description: Text(emptyDescription)
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sections) { section in
                            Section(section.label) {
                                ForEach(section.items) { item in
                                    LinkRowView(item: item)
                                        .onTapGesture { open(item) }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button {
                                                item.isRead.toggle()
                                                try? modelContext.save()
                                            } label: {
                                                Label(item.isRead ? "Mark Unread" : "Mark Read", systemImage: item.isRead ? "envelope.badge" : "envelope.open")
                                            }
                                            .tint(.blue)

                                            Button {
                                                item.isSaved.toggle()
                                                try? modelContext.save()
                                            } label: {
                                                Label(item.isSaved ? "Unsave" : "Save", systemImage: item.isSaved ? "bookmark.slash" : "bookmark")
                                            }
                                            .tint(.yellow)
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                            if let bskyURL = ATProtoURI.bskyAppURL(fromPostURI: item.postURI) {
                                                Button {
                                                    openURL(bskyURL)
                                                } label: {
                                                    Label("Open Post", systemImage: "at")
                                                }
                                                .tint(.indigo)
                                            }
                                            if let url = URL(string: item.originalURL) {
                                                Button {
                                                    shareURL = IdentifiableURL(url: url)
                                                } label: {
                                                    Label("Share", systemImage: "square.and.arrow.up")
                                                }
                                                .tint(.gray)
                                            }
                                        }
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
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task {
                RetentionService.pruneOldUnread(context: modelContext, retentionDays: retentionDaysSetting)
                if items.isEmpty {
                    await appModel.refreshTimeline(context: modelContext)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await appModel.refreshIfStale(context: modelContext) }
            }
            .refreshable {
                await appModel.refreshTimeline(context: modelContext)
            }
            .sheet(item: $readerURL) { wrapped in
                ReaderView(url: wrapped.url)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $shareURL) { wrapped in
                ShareSheet(url: wrapped.url)
            }
        }
    }

    private var retentionDaysSetting: Int {
        let stored = UserDefaults.standard.integer(forKey: "retentionDays")
        return stored == 0 ? 30 : stored
    }

    private var emptyTitle: String {
        switch filter {
        case .all: return "No articles yet"
        case .unread: return "All caught up"
        case .saved: return "No saved articles"
        }
    }

    private var emptyIcon: String {
        switch filter {
        case .all: return "tray"
        case .unread: return "checkmark.circle"
        case .saved: return "bookmark"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .all: return "Pull to refresh to check your timeline for links."
        case .unread: return "You've read everything in your list."
        case .saved: return "Swipe an article and tap Save to keep it here."
        }
    }

    private func open(_ item: LinkItem) {
        guard let url = URL(string: item.originalURL) else { return }
        item.isRead = true
        try? modelContext.save()
        readerURL = IdentifiableURL(url: url)
    }

    private func banner(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(tint.opacity(0.1))
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
