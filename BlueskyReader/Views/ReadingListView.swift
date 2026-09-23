//  ReadingListView.swift
//  A plain list on paper: hairline rules, pinned day headers, no cards, no shadows.
//
//  Adapted from the Skyreader design handoff. The handoff's stub takes pre-grouped
//  `days` as an external parameter while keeping `filter` as internal @State — those
//  two can't coexist (the caller can't filter data it was never given), so the data
//  layer is internalized here (@Query + AppModel, matching the rest of this app)
//  while every visual/behavioral spec from the design is kept exact.

import SwiftUI
import SwiftData
import UIKit

enum ListFilter: String, CaseIterable, Identifiable {
    case all = "All", unread = "Unread", saved = "Saved"
    var id: String { rawValue }
}

struct ReadingListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize

    @Query(sort: \LinkItem.appearedAt, order: .reverse) private var items: [LinkItem]

    @AppStorage("showCommentary") private var showCommentary = false
    @AppStorage("hideReadItems") private var hideReadItems = false
    @AppStorage("retentionDays") private var retentionDays = 30

    @State private var filter: ListFilter = .all
    @State private var newCount: Int?
    @State private var readerURL: IdentifiableURL?

    var body: some View {
        NavigationStack {
            List {
                ForEach(days) { day in
                    Section {
                        ForEach(day.items) { item in
                            Button { openArticle(item) } label: {
                                ArticleRow(item: item, showCommentary: showCommentary)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.paper)
                            .listRowSeparatorTint(Color.rule)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in Space.xl }
                            .swipeActions(edge: .leading) {
                                Button(item.isRead ? "Mark unread" : "Mark read") { toggleRead(item) }
                                    .tint(.accent)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(item.isSaved ? "Unsave" : "Save") { toggleSaved(item) }
                                    .tint(.accent)
                                if let url = URL(string: item.originalURL) {
                                    ShareLink(item: url) { Text("Share") }
                                        .tint(.inkTertiary)
                                }
                            }
                            .contextMenu {
                                Button("Open post in Bluesky") { openPost(item) }
                                Button("Copy link") { copyLink(item) }
                            }
                        }
                    } header: {
                        Text(day.title)
                            .font(.dayHeader)
                            .textCase(.uppercase)
                            .tracking(0.9)
                            .foregroundStyle(Color.inkTertiary)
                            .padding(.top, Space.xxl)
                            .padding(.bottom, 10)
                            .padding(.horizontal, Space.xl)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.paper)
                    }
                    .listRowSeparator(.hidden, edges: .top)
                }
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .environment(\.defaultMinListRowHeight, 64)
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .refreshable { await performRefresh() }
            .safeAreaInset(edge: .top, spacing: 0) { masthead }
            .overlay(alignment: .top) { if let n = newCount { newArticlesPill(n) } }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                RetentionService.pruneOldUnread(context: modelContext, retentionDays: retentionDays)
                if items.isEmpty {
                    await performRefresh()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await appModel.refreshIfStale(context: modelContext) }
            }
            .sheet(item: $readerURL) { wrapped in
                ReaderView(url: wrapped.url)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: masthead — serif title, date line, filters, one hairline

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Skyreader")
                        .font(.masthead)
                        .tracking(-0.5)
                        .foregroundStyle(Color.ink)
                    Text(dateLine)
                        .font(.caption).fontWeight(.semibold)
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(Color.inkTertiary)
                }
                Spacer()
                NavigationLink {
                    SettingsView(
                        handle: appModel.currentHandle ?? "unknown",
                        storedCount: items.count,
                        signOut: { Task { await appModel.logout() } },
                        pruneRead: { RetentionService.pruneRead(context: modelContext) }
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: 44, height: 44, alignment: .trailing)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, 14)

            filterRow
                .padding(.horizontal, Space.xl)
                .padding(.top, 18)

            Rectangle().fill(Color.rule).frame(height: 0.5)

            if appModel.isOffline {
                statusStrip(text: "Offline — showing \(items.count) saved articles", dotColor: .inkTertiary)
                Rectangle().fill(Color.rule).frame(height: 0.5)
            } else if let bannerMessage = appModel.bannerMessage {
                statusStrip(text: bannerMessage, dotColor: .destructive)
                Rectangle().fill(Color.rule).frame(height: 0.5)
            }
        }
        .background(Color.paper)
    }

    /// Text tabs with a 2pt ink underline — quieter than a segmented control.
    /// Collapses to a Menu at accessibility sizes, where three labels can't share a row.
    @ViewBuilder private var filterRow: some View {
        if typeSize.isAccessibilitySize {
            Menu {
                ForEach(ListFilter.allCases) { f in Button(f.rawValue) { filter = f } }
            } label: {
                HStack(spacing: 4) { Text(filter.rawValue); Image(systemName: "chevron.down") }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .frame(minHeight: 44)
            }
        } else {
            HStack(spacing: 22) {
                ForEach(ListFilter.allCases) { f in
                    Button { filter = f } label: {
                        VStack(spacing: 7) {
                            Text(f.rawValue)
                                .font(.subheadline)
                                .fontWeight(filter == f ? .semibold : .regular)
                                .foregroundStyle(filter == f ? Color.ink : Color.inkTertiary)
                            Rectangle()
                                .fill(filter == f ? Color.ink : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    private func newArticlesPill(_ n: Int) -> some View {
        HStack(spacing: Space.s) {
            Circle().fill(Color.accent).frame(width: 6, height: 6)
            Text("^[\(n) new article](inflect: true)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.ink)
        }
        .padding(.horizontal, 15).padding(.vertical, 9)
        .background(Capsule().fill(Color.surface))
        .overlay(Capsule().stroke(Color.rule, lineWidth: 0.5))
        .padding(.top, Space.s)
        .transition(.opacity)
    }

    /// Design spec: an 11pt-padded strip on #F2EFE8 (light) between two rules, a 6pt
    /// dot + message in .footnote, inkSecondary. No token in Theme.swift matches
    /// #F2EFE8 (no dark value given either), and adding a tenth color asset isn't
    /// allowed by the brief — using `surface` as the nearest existing "elevated
    /// strip" role instead. Flagged to Corey; not a silent swap.
    /// Shared by the offline strip and the error/rate-limit banner; only the dot
    /// color and text differ.
    private func statusStrip(text: String, dotColor: Color) -> some View {
        HStack(spacing: Space.s) {
            Circle().fill(dotColor).frame(width: 6, height: 6)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface)
    }

    private var dateLine: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"
        return f.string(from: .now)
    }

    // MARK: data

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

    /// Two `LinkItem`s can end up representing the same article under different
    /// normalized URLs (e.g. a shortener that resolved on one share but not another).
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
            withAnimation { newCount = count }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { newCount = nil }
        }
    }

    private func toggleRead(_ item: LinkItem) {
        item.isRead.toggle()
        try? modelContext.save()
    }

    private func toggleSaved(_ item: LinkItem) {
        item.isSaved.toggle()
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
