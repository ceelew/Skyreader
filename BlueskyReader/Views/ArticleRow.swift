//  ArticleRow.swift
//  The heart of the app. One row = one article.
//  Rules: the headline never truncates, the meta line always fits on one,
//  read state is a colour shift only, and the unread dot lives in the gutter.

import SwiftUI

struct ArticleRow: View {
    let item: LinkItem
    let showCommentary: Bool

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.headline)
                .font(item.headlineResolved ? .articleHead : .unresolved)
                .foregroundStyle(item.isRead ? Color.inkSecondary : Color.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)   // never truncate a headline

            HStack(spacing: 7) {
                metaLine
                    .font(.meta)
                    .foregroundStyle(item.isRead ? Color.inkTertiary : Color.inkSecondary)
                if item.isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.top, 6)

            if showCommentary, let note = item.postText, !note.isEmpty {
                Text(note)
                    .font(.commentary)
                    .foregroundStyle(Color.inkTertiary)
                    .lineLimit(2)
                    .padding(.top, 5)
            }
        }
        .skyreaderRowInsets()
        .overlay(alignment: .topLeading) {
            if !item.isRead {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 7, height: 7)
                    .padding(.leading, Space.s)   // centred in the 20pt gutter
                    .padding(.top, 22)            // aligned to the headline's first line
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
    }

    /// The sharer's handle gives way first so the time never gets truncated.
    @ViewBuilder private var metaLine: some View {
        if typeSize.isAccessibilitySize {
            Text("\(item.publication) · shared by @\(item.sharedByHandle) · \(item.appearedAt.relativeShort)")
                .lineLimit(3)
        } else {
            HStack(spacing: 0) {
                Text("\(item.publication) · shared by @\(item.sharedByHandle)")
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(" · \(item.appearedAt.relativeShort)")
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    /// Colour is never the only signal — VoiceOver says the state out loud.
    private var a11yLabel: String {
        var parts: [String] = []
        parts.append(item.isRead ? "Read." : "Unread.")
        if item.isSaved { parts.append("Saved.") }
        parts.append(item.headline)
        parts.append("\(item.publication), shared by @\(item.sharedByHandle), \(item.appearedAt.relativeShort)")
        return parts.joined(separator: " ")
    }
}
