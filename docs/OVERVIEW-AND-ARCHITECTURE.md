# Lytter — Overview & Architecture

_Last updated: 2026-09-23. Derived from the code at `d6cc610` plus uncommitted working-tree changes._

## 1. What this is

**Lytter** is a SwiftUI client for **DR (Danmarks Radio) live radio**. It streams DR's
public radio channels (P1–P8 and their regional P4/P5 variants), shows what programme
and which track is on air right now, and integrates with the system playback surfaces
(Control Centre, lock screen, Siri Remote, AirPlay).

| | |
|---|---|
| Bundle ID | `com.eopio.lytter` |
| Shipping platforms | iOS (17.6+) and tvOS (17.6+) |
| Declared but not implemented | macOS 14.6+, visionOS 26.0+ |
| UI | 100% SwiftUI, with UIKit/TVUIKit escape hatches |
| Dependencies | None — no SPM, CocoaPods or Carthage |
| Backend | DR's public API at `api.dr.dk/radio/v4` (no auth today) |
| Repo | 19 commits, Aug 2025 → Apr 2026, `main` only, no CI |

## 2. Repository layout

```
lytter.xcodeproj          objectVersion 77, folder-synced groups (Xcode 16+)
├── lytter/                       ← app target
│   ├── lytterApp.swift           @main; SwiftData container gate; onOpenURL
│   ├── ContentView.swift         platform fork: iOS TabView / tvOS tvOSHomeView
│   ├── Item.swift                ⚠ unused SwiftData template leftover
│   ├── ios/                      iOS-only screens (platform-filtered in pbxproj)
│   ├── tvos/                     tvOS-only screens (guarded by #if os(tvOS))
│   └── shared/
│       ├── model/DRModels.swift  API DTOs + DRServiceManager + misc state
│       ├── service/              network, audio, image cache, preferences, Siri
│       ├── player/               MiniPlayer + FullPlayer component set
│       ├── views/                MarqueeText, AirPlayButton, KnockoutText
│       ├── deeplink/             DeepLinkHandler
│       └── icons/lytter.xcf      ⚠ 32 MB GIMP source committed to git
├── TopShelfExtension/            tvOS Top Shelf provider (own models + client)
├── lytterTests/ lytterUITests/   Xcode template stubs, no real tests
└── AppIcon.icon/                 Icon Composer source (SVG layers)
```

**Note on target membership:** the project uses `PBXFileSystemSynchronizedRootGroup`,
so *every* file under `lytter/` is compiled into *every* platform slice. Platform
separation is achieved with `#if os(...)` inside the files plus a small
`platformFiltersByRelativePath` exception list for the `ios/` folder. Adding a file to
the folder adds it to the build automatically — including dead files.

## 3. Runtime architecture

```
                         ┌─────────────────────────┐
                         │      lytterApp          │  @main
                         │  (SwiftData gate ⚠)     │
                         └───────────┬─────────────┘
                                     │ .environmentObject
                         ┌───────────▼─────────────┐
                         │      ContentView        │
                         └───┬─────────────────┬───┘
              #if os(iOS)    │                 │   #elseif os(tvOS)
          ┌──────────────────▼──┐        ┌─────▼──────────────────┐
          │ TabView             │        │ tvOSHomeView (TabView) │
          │  Home │ Radio │     │        │  Radio │ Now Playing │ │
          │  Search │ Shortcuts │        │  Search                │
          │ + MiniPlayer as     │        │                        │
          │   tabViewBottom-    │        │ V3 now-playing screen  │
          │   Accessory (iOS26) │        │ + variant overlay      │
          └──────────┬──────────┘        └───────────┬────────────┘
                     └──────────┬────────────────────┘
                                ▼
              ┌──────────────────────────────────────────┐
              │  DRServiceManager : ObservableObject     │  ← the god object
              │  availableChannels, playingChannel,      │
              │  currentTrack, currentLiveProgram,       │
              │  cachedSchedules, isLoading, error       │
              └───┬────────┬────────┬────────┬───────────┘
                  │        │        │        │
    ┌─────────────▼─┐ ┌────▼─────┐ ┌▼───────┐ ┌▼───────────────────┐
    │DRNetwork      │ │AudioPlayer│ │Image   │ │UserPreferences     │
    │Service        │ │Service    │ │Cache   │ │Service             │
    │URLSession +   │ │AVPlayer   │ │Service │ │UserDefaults        │
    │Codable, retry │ │AVAudio    │ │NSCache │ │(last played)       │
    │+ backoff      │ │Session    │ │+ disk  │ └────────────────────┘
    └───────────────┘ │MPRemote   │ └────────┘
                      │Command    │          ┌────────────────────┐
                      │MPNowPlay- │          │DRLocalCache  (NEW, │
                      │ingInfo    │          │ uncommitted) JSON  │
                      │+ MPNow-   │          │ schedule snapshot  │
                      │PlayingSes-│          └────────────────────┘
                      │sion (tvOS)│
                      └───────────┘

 Cross-cutting: DeepLinkHandler · SelectionState · SiriShortcutsService
 Separate process: TopShelfExtension (duplicate models + duplicate client) ⚠
```

### Layer responsibilities

| Layer | Type | Responsibility |
|---|---|---|
| **View** | SwiftUI structs per platform | Rendering + focus/gesture handling. Talk directly to `DRServiceManager`. |
| **State** | `DRServiceManager` | Everything else: fetch orchestration, cache policy, playback commands, poll scheduling, now-playing metadata, preference writes. |
| **Service** | `DRNetworkService`, `AudioPlayerService`, `ImageCacheService`, `UserPreferencesService`, `DRLocalCache` | Single-concern helpers. Concrete types, no protocols. |
| **Model** | `DRChannel`, `DREpisode`, `DRTrack`, `DRSeries`, `DR*Asset` | `Codable` DTOs mapped 1:1 from the API, plus a lot of presentation logic as computed properties. |

## 4. Data flow

### API surface used

| Endpoint | Used by | Purpose |
|---|---|---|
| `GET /radio/v4/schedules/all/now` | app + Top Shelf | One call returns the current programme for every channel. This is the app's whole catalogue. |
| `GET /radio/v4/indexpoints/live/{slug}` | app | Currently playing track for one channel. |
| `GET /radio/v4/schedules/snapshot/{slug}` | — | Implemented in `DRNetworkService` but never called. |
| `https://asset.dr.dk/drlyd/images/{id}` | app + Top Shelf | Artwork. |
| `https://live-icy.gss.dr.dk/AAC{CHANNEL}` | app | ICY audio streams. |

### Cold start

1. `DRServiceManager.init()` → `loadDiskCache()` reads `Caches/dr_schedules_cache.json`
   synchronously and populates the UI immediately *(new, uncommitted)*.
2. `loadChannels()` fetches `/schedules/all/now` unless the in-memory cache is still
   valid. On success it replaces `cachedSchedules`, persists to disk, restores the last
   played channel, and kicks off image preloading.
3. `availableChannels` is derived as `Array(Set(schedules.map(\.channel))).sorted(by: title)`.

### Channel identity and grouping

`DRChannel` has no region field. Instead, `name` and `district` are parsed from the
**display title** by splitting on the first space:

```swift
"P4 København"  → name: "P4",  district: "København"    // correct
"P1"            → name: "P1",  district: nil            // correct
"P6 Beat"       → name: "P6",  district: "Beat"         // ⚠ false positive
"P8 Jazz"       → name: "P8",  district: "Jazz"         // ⚠ false positive
```

This drives tvOS channel grouping, the district/variant overlay, the iOS grouped cards,
Top Shelf consolidation, and the "is this the playing channel" badge
(`playingChannel?.name == channel.name`). Any two-word non-regional channel is mis-parsed
as a region — and `p6beat` / `p8jazz` are both in the app's own hardcoded stream map, so
this is live data, not a hypothetical. Channel identity should come from `slug` or a real
region field, not from splitting the display title.

### Stream URL resolution (`DREpisode.streamURL`)

1. Live audio asset (`isStreamLive == true`) on the current programme, else
2. any audio asset on any cached programme for that channel, else
3. a hardcoded `slug → live-icy.gss.dr.dk` map (24 entries), else
4. a guess: `https://live-icy.gss.dr.dk/AAC{SLUG.uppercased()}`.

### Track polling

Adaptive rather than fixed-interval: after fetching the current track,
`scheduleNextLivePoll` schedules the next fetch for `track.endTime + 5s`, or
`+15s` when no track is on air. Scheduling is done with bare
`DispatchQueue.main.asyncAfter` — there is no handle to cancel. A separate repeating
`Timer` refreshes the current programme every 5 minutes.

### System playback integration

`AudioPlayerService` owns `AVPlayer` and wires up:

- `AVAudioSession` (`.playback`) — activated on `play()`, **deactivated on `pause()`**.
- `MPRemoteCommandCenter` — play, pause, stop, togglePlayPause, skip ±, seek ±.
- `MPNowPlayingInfoCenter` — title/artist/album/artwork, `IsLiveStream = true`.
- On tvOS, an `MPNowPlayingSession` is created per `play()` and the command centre is
  rebound to it so PineBoard gets a playback queue.
- Interruption (`AVAudioSession.interruptionNotification`) and route-change handling,
  including pause-on-unplug.

## 5. Platform specifics

### iOS

- `TabView` with four tabs. On iOS 26+ it uses the `Tab(_:systemImage:value:role:)`
  API, `.tabBarMinimizeBehavior(.onScrollDown)` and `.tabViewBottomAccessory` to host
  the mini player; below 26 it falls back to a legacy `TabView` with the mini player
  stacked in a `ZStack`.
- Full player is a sheet (`iOSFullPlayerSheet`) composed from `PlayerArtworkView`,
  `PlayerInfoView`, `PlayerControlsView`, `PlayerVolumeView`, `PlayerActionsView`.
- `MarqueeText` scrolls long programme/track titles.
- Siri support is legacy `NSUserActivity` + `INShortcut` donation, surfaced in a
  "Shortcuts" tab. **No AppIntents.**

### tvOS

- Three tabs: Radio (horizontal focus shelf), Now Playing, Search.
- `tvOSChannelCard` + `tvOSMusicCardButtonStyle` implement a custom focus lift/scale
  and explicitly call `.focusEffectDisabled()` to suppress the system's
  `_UIReplicantView` effect.
- Channels with multiple regional variants open `tvOSVariantOverlay` instead of playing
  directly.
- Now Playing (V3) auto-hides its controls after 5 s and hides the tab bar with it,
  reaching into UIKit to find the `UITabBarController` and animate `alpha` +
  `isUserInteractionEnabled`.
- `TopShelfExtension` fetches live DR data and exposes deep-linked play actions.

## 6. Known architectural weaknesses

These are described here as facts about the design; fixes and priorities live in
[ROADMAP.md](ROADMAP.md).

1. **`DRServiceManager` is a god object.** ~400 lines mixing network orchestration,
   cache policy, playback control, timer scheduling, now-playing metadata and
   preference persistence. There are no protocol boundaries anywhere in the codebase,
   so nothing can be unit-tested without hitting the live DR API.

2. **Multiple live instances of it.** `ContentView` creates one; `ShortcutsView` creates
   a second as its own `@StateObject`; `SiriShortcutsService` lazily creates a third.
   Every `init()` triggers a full catalogue fetch *and* a full image preload.

3. **The Top Shelf extension duplicates the model and network layers.**
   `TopShelfChannel` / `TopShelfEpisode` / `TopShelfAPIConfig` / `TopShelfNetworkService`
   re-declare the DR contract. Two copies that will drift. The app group
   `group.com.eopio.lytter` is already declared in the entitlements and is unused — it
   is exactly the right mechanism for sharing the cached schedule instead.

4. **Presentation logic lives in the model.** `name`/`district` string-splitting,
   `cleanTitle()` doing `replacingOccurrences` of the channel title out of the programme
   title, and a 25-branch `categoryIcon` keyword matcher all sit on the DTOs.

5. **Dead view code.** `ChannelView.swift` is a complete, unreferenced iOS screen.
   `AppState` and `ProgramDescriptionSheet` are unused shells. `Item.swift` + the
   SwiftData `ModelContainer` are template leftovers that nonetheless gate the entire
   app's first render.

   _Partly resolved in #2:_ the three unused tvOS Now Playing variants
   (`tvOSNowPlayingView.swift`, `…V1.swift`, `…V2.swift` — 1,432 lines) were removed and
   the surviving `V3` renamed to `tvOSNowPlayingView`. The underlying cause remains:
   because the target uses folder-synced groups, any file left on disk is compiled, so
   dead code has to be deleted rather than merely unreferenced.

6. **No adaptivity primitives.** Zero uses of `horizontalSizeClass` / `verticalSizeClass`,
   seven uses of the deprecated `NavigationView`, ~30 hardcoded `.frame(width:)` values
   and three `.padding(.bottom, 100) // Space for the tab bar` magic numbers. See
   [IPHONE-DUO.md](IPHONE-DUO.md).

7. **Swift 5 language mode.** `SWIFT_VERSION = 5.0` with no strict concurrency, in a
   codebase that mutates `@Published` properties from background contexts and stores
   mutable closures on a non-isolated class.

## 7. Build & verification

```bash
xcodebuild -project lytter.xcodeproj -scheme lytter \
  -destination 'generic/platform=iOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

```bash
xcodebuild -project lytter.xcodeproj -scheme lytter \
  -destination 'generic/platform=tvOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

**Verified 2026-09-23 with Xcode 26.5 (17F5022i): both succeed.** The tvOS build emits
one meaningful warning — `None of the input catalogs contained a matching App Icon &
Top Shelf Image brand assets collection named "AppIcon"` — because every
`.imagestacklayer/Content.imageset` under `Brand Assets.brandassets` is empty.

Do not run both destinations concurrently against the same DerivedData; the second one
fails with `unable to attach DB: … database is locked`.
