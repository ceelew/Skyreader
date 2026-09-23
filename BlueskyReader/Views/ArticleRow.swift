//  ArticleRow.swift
//  One row = one article, laid out like a news app: source and time on top,
//  a serif headline that never truncates, then who shared it.
//  Unread gets a Mail-style dot in the leading gutter; read dims the headline.

import SwiftUI

struct ArticleRow: View {
    let item: LinkItem
    let showCommentary: Bool

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sourceLine

            Text(displayHeadline)
                .font(item.headlineResolved ? .articleHead : .unresolved)
                .foregroundStyle(item.isRead ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)   // never truncate a headline

            Text("Shared by @\(item.sharedByHandle)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)

            if showCommentary, let note = item.postText, !note.isEmpty {
                Text(note)
                    .font(.commentary)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.quaternary).frame(width: 3)
                    }
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .topLeading) {
            if !item.isRead {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 9, height: 9)
                    // Centred on the publication line (which sits below the 6pt top padding).
                    .offset(x: -20, y: 10)   // centred in the 32pt row gutter
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
    }

    private var displayHeadline: String {
        HeadlineCleaner.clean(item.headline, publication: item.publication,
                              host: URLNormalizer.host(of: item.originalURL))
    }

    /// Publication on the left, time (and saved mark) on the right. Stacks at
    /// accessibility sizes so neither side gets squeezed.
    @ViewBuilder private var sourceLine: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: 6))
        layout {
            Text(item.publication)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(item.isRead ? Color.secondary : Color.accent)
                .lineLimit(1)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            HStack(spacing: 6) {
                if item.isSaved {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.orange)
                }
                Text(item.appearedAt.relativeShort)
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
            .fixedSize()
        }
    }

    /// Colour is never the only signal — VoiceOver says the state out loud.
    private var a11yLabel: String {
        var parts: [String] = []
        parts.append(item.isRead ? "Read." : "Unread.")
        if item.isSaved { parts.append("Saved.") }
        parts.append(displayHeadline)
        parts.append("\(item.publication), shared by @\(item.sharedByHandle), \(item.appearedAt.relativeShort)")
        return parts.joined(separator: " ")
    }
}
