# Skyreader / Bluesky Reader: coding-agent handoff

Updated September 23, 2026. This handoff combines the conversation history with an inspection of the local source and Git history. No app code changed during this handoff. The author did not build the app, run tests, launch a simulator, or verify live Bluesky access during this inspection.

## Product and user intent

Corey wants an iOS app that collects external links from their Bluesky home feed and presents a readable, chronological list. Show article headlines and publication names instead of URLs. Group articles by when someone shared them in the feed, including repost time. Images are optional; the chosen direction uses an image-free list.

The user also requested a visual redesign through Claude Design and an app icon combining ideas from Bluesky's butterfly and the RSS symbol. The proposed direction was a quiet newspaper-like reading experience, serif headlines, light and dark appearances, and Dynamic Type support.

“Skyreader” began as a suggested placeholder name. The current interface uses Skyreader, while the Xcode target and project retain BlueskyReader and the configured display name remains “Bluesky Reader.” Confirm naming before release.

## Locations

| Item | Absolute path |
| --- | --- |
| Repository and project root | `/Users/corey/Developer/BlueskyReader` |
| This handoff | `/Users/corey/Developer/BlueskyReader/PROJECT_HANDOFF.md` |
| Original implementation plan | `/Users/corey/bluesky-reader-plan.md` |
| Xcode project | `/Users/corey/Developer/BlueskyReader/BlueskyReader.xcodeproj` |
| XcodeGen configuration | `/Users/corey/Developer/BlueskyReader/project.yml` |
| Swift source root | `/Users/corey/Developer/BlueskyReader/BlueskyReader` |
| Theme definitions | `/Users/corey/Developer/BlueskyReader/BlueskyReader/Theme/Theme.swift` |
| Asset catalog | `/Users/corey/Developer/BlueskyReader/BlueskyReader/Resources/Assets.xcassets` |
| App icon image | `/Users/corey/Developer/BlueskyReader/BlueskyReader/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` |
| App configuration | `/Users/corey/Developer/BlueskyReader/BlueskyReader/Resources/Info.plist` |

The original plan lives outside the repository. Include it when moving the project to another machine. No separate Claude Design export location was established in this handoff; source comments reference a design handoff, and Git records its integration.

## Work completed and provenance

In the earlier conversation, the assistant supplied the implementation plan and a Claude Design prompt covering the list, login, settings, design tokens, and butterfly/RSS icon concepts. Corey reported creating the initial app shell. The local repository now contains further implementation and design work. Do not infer that this conversation's assistant authored those commits.

At inspection, the branch was `master`, HEAD was `fd16414`, and the working tree was clean before adding this document. `git remote -v` returned no configured remotes.

Recent commits:

- `fd16414`: Skyreader design system, color tokens, Theme.swift, ArticleRow, redesigned reading list/login/settings, new app icon.
- `4f8633b`: swipe behavior change and deduplication by resolved headline.
- `7933ed5`: filters, swipe actions, settings, retention, background refresh, offline/error banners, app icon.
- `f5090d2`: asynchronous headline and publication resolution with retry limits.
- `1bb6b7d`: grouped reading list and Safari reader on tap.

Treat current source as the authority for behavior. Commit descriptions and the original plan can differ from the final implementation.

## Stack and build setup

The XcodeGen configuration specifies Swift 5.10, SwiftUI, iOS 17+, SwiftData, an iPhone target, and bundle identifier `com.coreylewis.BlueskyReader`. The app uses Foundation/URLSession for networking, Keychain for credentials, and SafariServices for article reading. The inspected configuration declares no third-party packages or test targets.

Open the existing project:

```sh
open /Users/corey/Developer/BlueskyReader/BlueskyReader.xcodeproj
```

After changing project configuration or adding files, regenerate from the repository root with XcodeGen if installed:

```sh
cd /Users/corey/Developer/BlueskyReader
xcodegen generate
```

Inspect available schemes and simulator destinations before choosing a build command:

```sh
xcodebuild -list -project /Users/corey/Developer/BlueskyReader/BlueskyReader.xcodeproj
xcodebuild -showdestinations -project /Users/corey/Developer/BlueskyReader/BlueskyReader.xcodeproj -scheme BlueskyReader
```

These commands are next steps, not checks completed for this handoff. The configuration leaves `DEVELOPMENT_TEAM` empty; device signing needs an appropriate team.

## Source map

All paths below are relative to the Swift source root listed above.

| Area | Files and responsibilities |
| --- | --- |
| App startup | `App/BlueskyReaderApp.swift`: SwiftData container, shared AppModel, background task registration. `App/RootView.swift`: root view. |
| Application state | `ViewModels/AppModel.swift`: login/logout, session restoration, refresh state, foreground refresh after 15 minutes, headline resolution after ingest. |
| Networking | `Networking/ATProtoClient.swift`: actor owning auth, Keychain-backed session, token refresh coordination, timeline requests. `ATProtoModels.swift`: API models. `KeychainStore.swift`: credential storage. |
| Persistence | `Models/LinkItem.swift`: article records. `Models/IngestState.swift`: ingest checkpoint. |
| Timeline ingestion | `Ingest/IngestService.swift`, `LinkExtractor.swift`, `URLNormalizer.swift`: pagination, external embed/facet links, shortener resolution, URL deduplication, persistence. |
| Page metadata | `Ingest/HeadlineResolver.swift`, `HeadlinePageFetcher.swift`, `HTMLMetaParser.swift`, `PublicationMapper.swift`: headline lookup, publication names and fallbacks. |
| Supporting services | `Ingest/DateGrouping.swift`, `DateParsing.swift`, `ATProtoURI.swift`, `RetentionService.swift`, `BackgroundRefreshManager.swift`. |
| Screens | `Views/ReadingListView.swift`, `ArticleRow.swift`, `LoginView.swift`, `SettingsView.swift`, `ReaderView.swift`. |
| Visual design | `Theme/Theme.swift`, `Resources/Assets.xcassets/Colors/`, app icon asset set. |

## Behavior confirmed in source

### Authentication and feed ingest

The client uses `https://bsky.social/xrpc/`, handle plus app password, and the createSession/refreshSession endpoints. It stores access and refresh tokens, DID, handle, and app password through KeychainStore. It coordinates concurrent token refresh requests and can retry login with stored credentials.

The ingest service requests the home timeline through `app.bsky.feed.getTimeline`, with up to 10 pages / 1,000 posts per foreground refresh. It stops on a stored post URI checkpoint or a paging limit.

LinkExtractor reads external embed cards, including resolved nested external embeds, and rich-text link facets. It skips `bsky.app` links and non-HTTP(S) URLs. For reposts, it uses the repost's indexed timestamp and reposter attribution; otherwise it uses the post's indexed timestamp and author. These timestamps approximate feed appearance, not the moment the user viewed an article.

LinkItem uses a unique normalized URL and stores the original/resolved URL, headline, publication, appearance time, sharer, source post URI/text, read/saved flags, and metadata retry count. Ingest keeps existing URL records unchanged and skips subsequent duplicates.

### Headlines and reading

Embed titles populate headlines during ingest. For links without titles, the app starts with a host placeholder and fetches page metadata. HeadlineResolver allows four concurrent fetches and two attempts before marking a record resolved. It updates publication from site metadata when available. It applies fetched results after the batch completes.

The reading list sorts by descending appearance time and groups into Today, Yesterday, and dated sections. Users can filter All / Unread / Saved, pull to refresh, save articles, mark them read/unread, share links, copy links, and open source posts in Bluesky. Opening an article marks it read and presents SFSafariViewController with `entersReaderIfAvailable = true`. Article content still depends on the publisher and Safari Reader availability; this is not a custom or offline full-text reader.

The current view uses leading swipe actions for read/unread and trailing actions for save/unsave and share. It also suppresses repeated resolved headlines in the displayed list, keeping the newest matching item within the active filter.

Settings include poster commentary, hiding read items, unread retention of 7/30/90 days, removing read items, and sign-out. The app schedules background refresh with an earliest begin time one hour later and ingests at most two pages / 200 posts in that path. iOS controls execution time; the code does not guarantee hourly delivery.

### Current visual implementation

Theme.swift defines warm paper backgrounds, ink text colors, blue accents, light/dark asset variants, serif masthead/headlines, system metadata typography, and shared spacing. ReadingListView uses a Skyreader masthead, text filters, thin rules, day headers, and an offline strip. At accessibility text sizes it replaces the filter row with a menu.

The repository includes a 1024px app icon. This handoff confirms the file exists but does not assess its appearance or whether it meets the butterfly/RSS brief.

## Gaps and review priorities

These are source-inspection findings and verification tasks, not a request to expand the product scope without direction.

1. **Build and UI validation remain unverified.** Run a simulator build and inspect login, list, settings, light/dark appearance, and accessibility sizes. No test target appears in project.yml.
2. **Headline deduplication can hide distinct articles.** ReadingListView deduplicates by headline alone, without publication or URL. HeadlineResolver also marks failed host placeholders resolved after two attempts, so multiple failed articles from the same host can then collapse into one displayed row.
3. **Checkpoint semantics need review.** Ingest stops by original post URI, even for reposts. Repeated appearances of the same post may stop pagination too soon. Refresh caps and the checkpoint also deserve testing for gaps after long absences.
4. **“First appearance wins” needs precision.** The original plan uses that phrase, but the app keeps the first occurrence it ingests while scanning newest-first, then leaves that stored record unchanged. This does not establish the earliest historical share time.
5. **Publication enrichment is partial.** HeadlineResolver only fetches records whose headline is unresolved. Articles with embed headlines retain domain-based publication mapping unless another path enriches them.
6. **Authentication and error UX need verification.** AppModel catches refresh errors but only marks network failures offline. Confirm visible handling of expired credentials, rate limits, and server failures, plus correct navigation back to login when needed.
7. **Account changes need review.** Logout clears credentials but AppModel does not clear SwiftData articles or the ingest checkpoint. The model has no account ownership field. Decide what to do with stored data before supporting account switching.
8. **Release details remain.** Settings uses a generic `https://github.com/` Source link and hardcodes “Skyreader 1.0 (1).” Reconcile display naming and signing before distribution.
9. **API guidance in the original plan needs rechecking before auth changes.** It makes broad claims about Bluesky authentication. Treat its app-password flow as this implementation's choice; verify current official guidance for OAuth and hosting support. The current client hardcodes bsky.social.

The previous conversation also included conflicting, unverified model recommendations for Claude/Claude Design. Do not use those model names or availability claims as technical requirements. A screenshot led the assistant to retract its initial claim that Claude Design had no model picker.

## Suggested continuation

Read this handoff and the original plan, inspect Git status, then build the existing project. Preserve the implemented design while assessing it in the simulator. If Corey requests further design work, start from screenshots of the current app and the existing theme/icon rather than assuming a bare shell. Prioritize any reproduced feed-loss, deduplication, or authentication issue before adding features.

For prose, Corey requires the stop-slop skill at `/Users/corey/.codex/skills/stop-slop/SKILL.md`. Check applicable repository and environment instructions before making code changes. Keep credentials and tokens out of documentation, logs, and commits.
