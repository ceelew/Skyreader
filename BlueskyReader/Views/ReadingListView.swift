//  ReadingListView.swift
//  The main screen: a standard iOS list under a large title, grouped by the day each
//  link appeared in the feed. Filter and settings live in the toolbar; search pulls down.

import SwiftUI
import SwiftData
import UIKit

enum ListFilter: String, CaseIterable, Identifiable {
    case all = "All", unread = "Unread", saved = "Saved"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: "tray"
        case .unread: "circle.inset.filled"
        case .saved: "bookmark"
        }
    }
}

struct ReadingListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @Query(sort: \LinkItem.appearedAt, order: .reverse) private var items: [LinkItem]

    @AppStorage("showCommentary") private var showCommentary = false
    @AppStorage("hideReadItems") private var hideReadItems = false
    @AppStorage("retentionDays") private var retentionDays = 30

    @State private var filter: ListFilter = .all
    @State private var searchText = ""
    @State private var newCount: Int?
    @State private var readerURL: IdentifiableURL?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                if let status = statusMessage {
                    statusRow(status)
                }
                ForEach(days) { day in
                    Section {
                        ForEach(day.items) { item in
                            row(for: item)
                        }
                    } header: {
                        Text(day.title)
                            .padding(.leading, Self.rowLeadingInset - 20)   // line up with row text
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(filter == .all ? "Skyreader" : filter.rawValue)
            .searchable(text: $searchText, prompt: "Headlines, publications, people")
            .toolbar { toolbarContent }
            .overlay { emptyState }
            .overlay(alignment: .bottom) { if let n = newCount { newArticlesPill(n) } }
            .refreshable { await performRefresh() }
            .task {
                RetentionService.pruneOldUnread(context: modelContext, retentionDays: retentionDays)
                // Refresh on every launch (refreshIfStale always runs the first time),
                // so opening the app shows fresh links and retries stuck metadata.
                await performRefresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await appModel.refreshIfStale(context: modelContext) }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    handle: appModel.currentHandle ?? "unknown",
                    signOut: { Task { await appModel.signOut(context: modelContext) } }
                )
            }
            .fullScreenCover(item: $readerURL) { wrapped in
                ReaderView(url: wrapped.url) { readerURL = nil }
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: rows

    /// Wider than the default 20pt so the unread dot gets its own gutter
    /// instead of sitting against the screen edge.
    static let rowLeadingInset: CGFloat = 32

    private func row(for item: LinkItem) -> some View {
        Button { openArticle(item) } label: {
            ArticleRow(item: item, showCommentary: showCommentary)
        }
        .swipeActions(edge: .leading) {
            Button { toggleRead(item) } label: {
                Label(item.isRead ? "Unread" : "Read",
                      systemImage: item.isRead ? "circle.inset.filled" : "checkmark.circle")
            }
            .tint(Color.accent)
        }
        .swipeActions(edge: .trailing) {
            Button { toggleSaved(item) } label: {
                Label(item.isSaved ? "Unsave" : "Save",
                      systemImage: item.isSaved ? "bookmark.slash" : "bookmark")
            }
            .tint(.orange)
            if let url = URL(string: item.originalURL) {
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                    .tint(.gray)
            }
        }
        .listRowInsets(EdgeInsets(top: 10, leading: Self.rowLeadingInset, bottom: 10, trailing: 20))
        .contextMenu {
            Button { toggleRead(item) } label: {
                Label(item.isRead ? "Mark as Unread" : "Mark as Read",
                      systemImage: item.isRead ? "circle.inset.filled" : "checkmark.circle")
            }
            Button { toggleSaved(item) } label: {
                Label(item.isSaved ? "Remove from Saved" : "Save",
                      systemImage: item.isSaved ? "bookmark.slash" : "bookmark")
            }
            Divider()
            if let url = URL(string: item.originalURL) {
                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
            }
            Button { copyLink(item) } label: { Label("Copy Link", systemImage: "link") }
            Button { openPost(item) } label: {
                Label("Open Post in Bluesky", systemImage: "bubble.left.and.text.bubble.right")
            }
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Show", selection: $filter) {
                    ForEach(ListFilter.allCases) { f in
                        Label(f.rawValue, systemImage: f.systemImage).tag(f)
                    }
                }
            } label: {
                Image(systemName: filter == .all
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel("Filter, \(filter.rawValue)")
        }
    }

    // MARK: status, empty states, feedback

    private struct StatusMessage {
        let text: String
        let systemImage: String
        let isError: Bool
    }

    private var statusMessage: StatusMessage? {
        if appModel.isOffline {
            return StatusMessage(text: "You're offline. Showing articles saved on this iPhone.",
                                 systemImage: "wifi.slash", isError: false)
        }
        if let banner = appModel.bannerMessage {
            return StatusMessage(text: banner, systemImage: "exclamationmark.triangle.fill", isError: true)
        }
        return nil
    }

    private func statusRow(_ status: StatusMessage) -> some View {
        Label(status.text, systemImage: status.systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.hierarchical)
            .imageScale(.medium)
            .tint(status.isError ? .orange : .secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    @ViewBuilder private var emptyState: some View {
        if days.isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if items.isEmpty {
                if appModel.isRefreshing {
                    ProgressView("Loading your timeline…")
                } else {
                    ContentUnavailableView {
                        Label("No Articles Yet", systemImage: "newspaper")
                    } description: {
                        Text("Links shared in your Bluesky timeline will appear here. Pull down to refresh.")
                    }
                }
            } else {
                switch filter {
                case .saved:
                    ContentUnavailableView {
                        Label("No Saved Articles", systemImage: "bookmark")
                    } description: {
                        Text("Swipe left on an article to save it for later.")
                    }
                case .unread, .all:
                    ContentUnavailableView {
                        Label("All Caught Up", systemImage: "checkmark.circle")
                    } description: {
                        Text("You've read everything in your list.")
                    }
                }
            }
        }
    }

    private func newArticlesPill(_ n: Int) -> some View {
        Label {
            Text("^[\(n) new article](inflect: true)")
        } icon: {
            Image(systemName: "arrow.down.circle.fill")
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: data

    private var filteredItems: [LinkItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            if hideReadItems && item.isRead && filter != .saved { return false }
            switch filter {
            case .all: break
            case .unread: if item.isRead { return false }
            case .saved: if !item.isSaved { return false }
            }
            guard !query.isEmpty else { return true }
            return item.headline.localizedStandardContains(query)
                || item.publication.localizedStandardContains(query)
                || item.sharedByHandle.localizedStandardContains(query)
        }
    }

    /// See `ArticleDeduplicator` for the keying/placeholder rules.
    private var deduplicatedItems: [LinkItem] {
        ArticleDeduplicator.dedupe(filteredItems)
    }

    private var days: [DaySection] {
        let grouped = Dictionary(grouping: deduplicatedItems) { DateGrouping.dayKey(for: $0.appearedAt) }
        return grouped.keys.sorted(by: >).map { key in
            DaySection(id: key, title: DateGrouping.sectionLabel(for: key), items: grouped[key] ?? [])
        }
    }

    // MARK: actions

    private func openArticle(_ item: LinkItem) {
        guard let url = URL(string: item.originalURL) else { return }
        item.isRead = true
        try? modelContext.save()
        readerURL = IdentifiableURL(url: url)
    }

    private func performRefresh() async {
        await appModel.refreshTimeline(context: modelContext)
        if let count = appModel.lastRefreshNewItemCount, count > 0 {
            withAnimation(.spring) { newCount = count }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.spring) { newCount = nil }
        }
    }

    private func toggleRead(_ item: LinkItem) {
        withAnimation { item.isRead.toggle() }
        try? modelContext.save()
    }

    private func toggleSaved(_ item: LinkItem) {
        withAnimation { item.isSaved.toggle() }
        try? modelContext.save()
    }

    private func openPost(_ item: LinkItem) {
        guard let url = ATProtoURI.bskyAppURL(fromPostURI: item.postURI) else { return }
        openURL(url)
    }

    private func copyLink(_ item: LinkItem) {
        UIPasteboard.general.string = item.originalURL
    }
}

/// Grouping is a view concern: bucket LinkItems by the calendar day of appearedAt,
/// newest first. Titles: "Today", "Yesterday", then "EEEE, MMMM d".
struct DaySection: Identifiable {
    let id: Date
    let title: String
    let items: [LinkItem]
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

#Preview {
    ReadingListView()
        .environment(AppModel(client: ATProtoClient()))
}
