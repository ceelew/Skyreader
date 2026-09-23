# Bluesky Link Reader — Build Plan

An iOS app that collects every link shared in the user's Bluesky timeline and presents them as a clean, chronological reading list — headlines and publication names, not raw URLs. No images required.

## 1. Product summary

- **Input:** the authenticated user's Bluesky home timeline.
- **Output:** a scrollable list of articles, newest-first, grouped by when they appeared in the feed (Today / Yesterday / date headers).
- **Each row shows:** headline, publication name, relative time it appeared, and who shared it (post author). Optionally the poster's commentary as a secondary line.
- **Tapping a row** opens the article in a reader view.
- **Explicit non-goals for v1:** posting, liking, replying, notifications, images/thumbnails, multiple accounts, custom feeds (home timeline only — but see stretch goals).

## 2. Tech stack

- **Swift 5.10+, SwiftUI**, iOS 17+ minimum (enables SwiftData and `@Observable`).
- **SwiftData** for persistence (link items must survive relaunch — the timeline is ephemeral, the reading list should not be).
- **URLSession** directly for the AT Protocol API — no third-party dependencies needed. The API is plain JSON over HTTPS.
- **Keychain** for credentials/tokens (use a small wrapper over Security.framework; do not store tokens in UserDefaults).
- **SFSafariViewController** (with `entersReaderIfAvailable = true`) for the reading experience in v1. A custom readability renderer is a stretch goal (§10).

## 3. Bluesky / AT Protocol integration

Base URL: `https://bsky.social/xrpc/` (the user's PDS; using bsky.social directly is fine for v1).

### 3.1 Authentication

Bluesky does not use OAuth for third-party apps in the common case — it uses **app passwords**:

1. Onboarding screen instructs the user to create an app password at Bluesky → Settings → Privacy and Security → App Passwords, then enter their handle (e.g. `corey.bsky.social`) and that app password.
2. `POST com.atproto.server.createSession` with `{"identifier": handle, "password": appPassword}` → returns `accessJwt`, `refreshJwt`, `did`, `handle`.
3. Store both JWTs and the DID in the Keychain. The app password itself may also be stored in Keychain to allow silent re-login, or discarded after first session — builder's choice; storing it (Keychain only) makes recovery simpler.
4. Access tokens are short-lived (~2 hours). On a 400/401 with error `ExpiredToken`, call `POST com.atproto.server.refreshSession` with the **refresh** JWT as the Bearer token; it returns fresh tokens. If refresh fails, fall back to `createSession` with the stored app password; if that fails, surface the login screen.
5. All authenticated calls send `Authorization: Bearer <accessJwt>`.

Build a small `ATProtoClient` actor that owns tokens and serializes refresh (so concurrent requests don't double-refresh).

### 3.2 Fetching the timeline

`GET app.bsky.feed.getTimeline?limit=100&cursor=<cursor>`

- Returns `{ feed: [FeedViewPost], cursor: String? }`.
- Paginate with the cursor. On each refresh, page backwards until you hit posts already ingested (match on post URI) or a cap (e.g. 10 pages / 1000 posts) to bound work.
- Decode leniently: model only the fields you need, make everything optional, and never fail the whole page because one post has an unexpected shape.

### 3.3 Extracting links from posts

Each `FeedViewPost` has `post` (a `PostView`) and optional `reason` (repost info). Links appear in two places — **check both**:

1. **External embed (primary, richest source):** `post.embed` with `$type == "app.bsky.embed.external#view"` contains `external: { uri, title, description, thumb }`. The `title` is usually the article's OpenGraph headline — this is your headline for free. Note: embeds can also be nested inside `app.bsky.embed.recordWithMedia#view` (link + quote post) — check `media` there too.
2. **Facets (links in post text with no card):** `post.record.facets[]`, where a facet's `features[]` contains `$type == "app.bsky.richtext.facet#link"` with a `uri`. These have no title — the app must resolve one (§3.5).

Skip: posts with no links; links pointing at Bluesky itself (`bsky.app` post/profile URLs); obvious non-articles are fine to keep — don't over-filter in v1.

### 3.4 Timestamps — "when it showed up in my feed"

The ordering requirement is *feed appearance time*, not article publish time:

- Normal post: use `post.indexedAt`.
- Repost (`reason.$type == "app.bsky.feed.defs#reasonRepost"`): use `reason.indexedAt` (when the repost happened — that's when it entered the feed), and record the reposter as the sharer.
- Store this as `appearedAt` and sort/group by it.

### 3.5 Headline and publication resolution

Every link item needs a **headline** and a **publication**:

- **Headline:**
  1. Embed card `title` if present and non-empty (the common case).
  2. Otherwise fetch the URL (respecting redirects) and parse `og:title`, falling back to `<title>`. Do this lazily/async after insert; show the domain as a placeholder until resolved. Cap the fetch at ~10s and ~1MB; parse with a lightweight regex/scanner over the `<head>` — no HTML-parsing dependency required.
  3. Final fallback: the URL's host + path, truncated.
- **Publication:**
  1. `og:site_name` when the page was fetched anyway.
  2. Otherwise derive from the final (post-redirect) host: strip `www.`/`m.`/`amp.`, then look up a small bundled mapping for prettification (`nytimes.com → The New York Times`, `theverge.com → The Verge`, ~50 common outlets). Unknown hosts: display the bare domain (`example.com`) — that's acceptable and honest.
  3. Normalize the URL before dedup and display: unwrap known shorteners by following redirects; strip tracking params (`utm_*`, `fbclid`, etc.).

## 4. Data model (SwiftData)

```swift
@Model final class LinkItem {
  @Attribute(.unique) var normalizedURL: String   // dedup key
  var originalURL: String
  var headline: String            // may start as placeholder
  var headlineResolved: Bool
  var publication: String         // pretty name or bare domain
  var appearedAt: Date            // first time seen in feed (§3.4)
  var sharedByHandle: String      // who put it in the feed (reposter if repost)
  var sharedByDisplayName: String?
  var postText: String?           // sharer's commentary, optional secondary line
  var postURI: String             // at:// URI, for "open post in Bluesky"
  var isRead: Bool
  var isSaved: Bool               // simple bookmark flag
}

@Model final class IngestState {
  var lastRefreshAt: Date?
  var newestSeenPostURI: String?  // refresh stop marker
}
```

**Dedup rule:** if the same normalized URL appears again, keep the existing item and its original `appearedAt` (first appearance wins); optionally bump a `shareCount`. Post URIs seen before are skipped entirely (track recent post URIs, or rely on URL dedup — URL dedup alone is sufficient for v1).

**Retention:** prune unread items older than 30 days on launch; never prune `isSaved` items.

## 5. App architecture

Three layers, kept simple:

- **`ATProtoClient` (actor):** login, refresh, `getTimeline` paging. Knows nothing about the database.
- **`IngestService`:** orchestrates refresh — page timeline, extract links (§3.3), normalize, dedup, insert `LinkItem`s, kick off async headline resolution for unresolved items. Runs on: app launch, pull-to-refresh, foreground return (if >15 min since last refresh), and BGAppRefreshTask (§8).
- **SwiftUI views** reading SwiftData via `@Query` — the list updates live as ingestion inserts rows. State (auth vs. logged out, refreshing flag, errors) in one `@Observable` `AppModel`.

## 6. UI spec

### Screens

1. **Login** — handle field, app-password field (secure), short explanation of app passwords with a link to the Bluesky settings page, sign-in button, inline error states (bad handle, bad password, network).
2. **Reading list (main screen)** — a plain `List`, newest-first, grouped into sections by `appearedAt`: **Today**, **Yesterday**, then day headers (**Friday, August 8**). Each row:
   - Headline: `.headline` weight, 3-line limit.
   - Second line, `.subheadline` secondary color: `Publication · shared by @handle · 2h ago`.
   - Optional third line (user-toggleable in settings): the post text, 2-line limit, tertiary color.
   - Read items render the headline in secondary color. Swipe actions: mark read/unread, save, share sheet, "open post in Bluesky" (deep link `https://bsky.app/profile/<did>/post/<rkey>`).
   - Pull-to-refresh; unobtrusive "N new articles" feedback after refresh.
3. **Reader** — `SFSafariViewController` wrapped for SwiftUI, `entersReaderIfAvailable = true`. Mark the item read on open.
4. **Settings (minimal)** — account (handle, sign out), toggle post-commentary line, toggle "hide read items", retention length, prune-now.

### Filters

Segmented control or menu on the main screen: **All / Unread / Saved**.

### Design notes

Typography-first, no images: generous line spacing, system fonts (New York for headlines is a nice touch via `.fontDesign(.serif)`), respect Dynamic Type, dark mode for free via system colors. The whole app is essentially one great list — spend the polish there.

## 7. Error handling

- Auth failure mid-session → attempt token refresh → app-password re-login → only then bounce to login screen (never silently show an empty list).
- Network offline: show cached list (this is the point of persistence) with a subtle "offline" banner; refresh silently retries on foreground.
- Headline fetch failures: keep domain placeholder, retry once on next refresh, then stop (mark `headlineResolved = true` with fallback text).
- Rate limiting (HTTP 429): back off, respect `ratelimit-reset` header if present, cap refresh paging.

## 8. Background refresh (nice-to-have, in v1 if cheap)

Register a `BGAppRefreshTask` that runs `IngestService.refresh()` with a tight budget (2 pages max, skip headline resolution for facet-only links). This keeps the list warm so opening the app feels instant.

## 9. Milestones (build in this order)

1. **M1 — Skeleton + auth:** Xcode project, login screen, `ATProtoClient` with createSession/refresh, Keychain storage. *Done when: user can sign in and the DID is persisted across launches.*
2. **M2 — Ingest:** getTimeline paging, link extraction from embeds + facets, normalization/dedup, SwiftData models. *Done when: a console/debug list shows correct deduped links with correct `appearedAt` ordering, including reposts.*
3. **M3 — Reading list UI:** grouped list, rows per spec, pull-to-refresh, read state, Safari reader on tap. *Done when: the core loop (open app → see fresh headlines → tap → read → return, item marked read) works.*
4. **M4 — Headline resolution:** async og:title fetch for facet-only links, publication prettification, placeholder → live update in the list.
5. **M5 — Polish:** filters, swipe actions, settings, retention pruning, background refresh, empty/error/offline states, app icon.

Each milestone should build and run in the iOS Simulator before moving on.

## 10. Stretch goals (explicitly out of v1)

- Custom in-app reader: fetch article HTML, run a Readability-style extractor, render with adjustable serif typography. (Swift ports of Mozilla Readability exist; or run Readability.js in a hidden WKWebView.)
- Source list beyond home timeline: pick a custom feed or list via `app.bsky.feed.getFeed` / `getListFeed`.
- Share count ("shared by 3 people in your feed") with grouped attribution.
- iCloud sync (SwiftData + CloudKit) and an iPad/Mac layout.
- OAuth (`atproto` OAuth is rolling out; app passwords are the pragmatic v1 choice).

## 11. Acceptance criteria (v1)

- [ ] Sign in with handle + app password; session survives relaunch and token expiry.
- [ ] Every external link from the home timeline (embed cards **and** bare text links) appears exactly once, newest-first, grouped by day of feed appearance.
- [ ] Reposts are timestamped by repost time and attributed to the reposter.
- [ ] ≥95% of items display a real headline (not a URL); the rest show a clean domain fallback.
- [ ] Publication shown for every item (pretty name or bare domain).
- [ ] Tap → reader view; item marked read; read/unread/saved filters work.
- [ ] Fully usable offline with previously ingested items.
- [ ] No third-party dependencies; no credentials outside the Keychain.
