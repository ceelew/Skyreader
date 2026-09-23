# Skyreader

Skyreader collects the external links people share in your Bluesky home timeline and turns them into a single chronological reading list. Instead of scrolling the timeline for articles, you open Skyreader and see article headlines and publication names, grouped by when they appeared in your feed.

## Requirements

- Xcode 16 or later
- iOS 17 or later (device or simulator)
- A Bluesky account and an app password (create one at bsky.app under Settings > App Passwords)

## Building

Install XcodeGen if you don't already have it, then generate the Xcode project from `project.yml`:

```sh
xcodegen generate
open BlueskyReader.xcodeproj
```

To build and run the test suite from the command line instead:

```sh
xcodebuild test \
  -scheme BlueskyReader \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## Project layout

- `BlueskyReader/App` - app entry point and root view.
- `BlueskyReader/Views` - SwiftUI screens: login, reading list, article row, reader, settings.
- `BlueskyReader/ViewModels` - app-level state and session handling.
- `BlueskyReader/Ingest` - timeline paging, link extraction, URL normalization, headline and publication resolution, retention pruning, background refresh.
- `BlueskyReader/Networking` - AT Protocol client, response models, Keychain-backed credential storage.
- `BlueskyReader/Models` - SwiftData models for stored link items and ingest state.
- `BlueskyReader/Theme` - shared colors, type, and spacing.
- `BlueskyReader/Resources` - Info.plist and asset catalog.
- `BlueskyReaderTests` - unit tests.

## Privacy

Your Bluesky handle and app password are stored only in the iOS Keychain on your device. Skyreader has no server of its own. To show a headline and publication name for a shared link, Skyreader fetches that article's page directly from the publisher; no link or reading data is sent anywhere else.
