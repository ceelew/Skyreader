import SwiftUI

struct LinkRowView: View {
    let item: LinkItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.headline)
                .font(.headline)
                .fontDesign(.serif)
                .foregroundStyle(item.isRead ? .secondary : .primary)
                .lineLimit(3)

            Text("\(item.publication) · shared by @\(item.sharedByHandle) · \(item.appearedAt.formatted(.relative(presentation: .named)))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let postText = item.postText, !postText.isEmpty {
                Text(postText)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    List {
        LinkRowView(item: LinkItem(
            normalizedURL: "https://example.com/a",
            originalURL: "https://example.com/a",
            headline: "A Very Interesting Headline About Something Important",
            headlineResolved: true,
            publication: "Example Times",
            appearedAt: .now,
            sharedByHandle: "corey.bsky.social",
            postText: "This is a great read, highly recommend it to everyone following along.",
            postURI: "at://x"
        ))
    }
}
