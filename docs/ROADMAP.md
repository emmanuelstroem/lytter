# Lytter — Status, Plan & Todo

_Last updated: 2026-09-23. Baseline `50cc776` — PRs #1–#6 merged._
_Companion docs: [OVERVIEW-AND-ARCHITECTURE.md](OVERVIEW-AND-ARCHITECTURE.md) · [IPHONE-DUO.md](IPHONE-DUO.md)_

---

## 1. Where the project stands

A **working but unshipped** v1. Both platforms build clean on Xcode 26.5. Live playback,
now-playing metadata, system playback integration, deep links and Top Shelf all function.
What is missing is not core capability — it is the last mile: real search, favourites,
localisation, accessibility, tests, icons, and a pass over the config that would let it
pass App Review.

Roughly: **feature-complete for "listen to a DR channel", ~40% of the way to shippable.**

> **The v4 outage.** For some period before 2026-09-23 the app did not work at all: DR
> retired API v4 and `api.dr.dk` answered 401 to everything, so no channel list and no
> playback. All 24 hardcoded `live-icy.gss.dr.dk` stream URLs had also gone 404. Fixed in
> #6 by moving to v5 and deleting the hardcoded fallbacks — v5 supplies working HLS and ICY
> URLs in `audioAssets`.
>
> Nothing detected this; it was found by running the app. `api.dr.dk` answers 401 for any
> version it does not serve, so the next bump will look identical. A scheduled job that
> asserts a 200 **and** a successful decode is the standing gap — deliberately deferred,
> not forgotten.

### Timeline read from git

| | |
|---|---|
| First commit | 2025-08-07 |
| Burst of work | Aug 2025 (17 of 19 commits) — iOS, then tvOS, then Top Shelf |
| Last commit | 2026-04-22 — "tvos: fix radio layout and update nowPlaying screen to be more minimal" |
| Working tree | 4 modified, 2 untracked — a coherent in-progress change set, not stray edits |

The project went quiet for ~5 months and was picked up again for a tvOS now-playing
redesign plus an offline/cold-start reliability pass. That pass is **unfinished and
uncommitted**.

---

## 2. What was in progress

Four related threads found uncommitted in the working tree on 2026-09-23. **All are now
merged** — #1 landed the first three, #2 resolved the fourth. Kept here as the record of
what that change set was and what it left behind.

### 2.1 Offline-first cold start — `DRModels.swift`

A new `DRLocalCache` singleton persists the `/schedules/all/now` payload to
`Caches/dr_schedules_cache.json`. `DRServiceManager.init()` now calls `loadDiskCache()`
*before* `loadChannels()`, so the UI is populated instantly on launch. `loadChannels()`
was reworked so the spinner only appears when there is genuinely nothing to show, and
network errors are swallowed when cached data exists.

**Remaining:** no cache versioning or schema-migration guard (a model change makes
`decode` fail silently and the cache is permanently dead); no staleness check on load, so
a week-old cache renders as if it were live; encode/decode of the whole array is
synchronous.

### 2.2 "Restored channel won't start from the lock screen" fix — `AudioPlayerService.swift`

Adds `hasLoadedItem` (is there an `AVPlayerItem`?) and an `onRequestPlay` callback.
`playCommand` and `togglePlayPauseCommand` now call back into `DRServiceManager` to start
a fresh stream when the channel was restored from cache but never actually played this
session. `DRServiceManager.togglePlayback(for:)` mirrors the same branch.

**Remaining:** untested; `onRequestPlay` is a stored mutable closure on a non-isolated
class — a data race under Swift 6.

### 2.3 tvOS now-playing polish — `tvOSNowPlayingViewV3.swift`, `tvOSComponents.swift`

- `NowPlayingBadge` on the channel card, matched by **base channel name** so any regional
  variant counts as "this channel".
- `.focusEffectDisabled()` on `tvOSMusicCardButtonStyle` to stop tvOS creating a
  `_UIReplicantView` that fights the custom focus visuals.
- `setTabBarVisible` now toggles `isUserInteractionEnabled` as well as `alpha`, so the
  focus engine stops cycling to invisible tab-bar items (was causing show/hide flicker).
- **`RemoteInteractionDetector`** — a `UIGestureRecognizer` subclass installed on the
  `UIWindow` that sets `state = .failed` immediately, so it observes every touchpad swipe
  and button press without consuming it. Replaces `.onMoveCommand` / `.onPlayPauseCommand`
  for waking the auto-hiding controls.

**Remaining:** reaching into `UIApplication.shared.connectedScenes.first` and walking the
view-controller tree to find a `UITabBarController` is fragile and breaks under multiple
scenes; the recogniser is installed per view appearance with no de-duplication.

### 2.4 Design exploration — `tvOSNowPlayingViewV1.swift`, `V2.swift` (untracked)

Three parallel now-playing designs (side-by-side / full-bleed artwork / centred card).
**V3 won** — it is the one wired into `tvOSHomeView`. V1, V2 and the original
`tvOSNowPlayingView.swift` were all still compiled into the tvOS binary and referenced by
nothing.

> **Resolved.** V1 and V2 were committed in `e1d7bd6` so the exploration survives in
> history, then all three dead variants were deleted and `V3` renamed to the canonical
> `tvOSNowPlayingView` in #2 — 1,432 lines out of the tvOS build.

---

## 3. What is pending (never built)

| Area | Status |
|---|---|
| **iOS search** | Stub. `SearchView.swift:37` literally renders `"Search functionality coming soon..."`. tvOS has a real implementation to port. |
| **Favourites / recents** | Not started. Only "last played channel" exists. |
| **On-demand / podcasts** | Not started. The API exposes `isAvailableOnDemand` and `/schedules/snapshot/{slug}`; `fetchScheduleSnapshot` is written but never called. |
| **Schedule / EPG view** | Not started. The data is already fetched and cached. |
| **Sleep timer** | Not started. Obvious fit for a radio app. |
| **AppIntents** | Not started. Siri is legacy `NSUserActivity`/`INShortcut` only. Build warns `No AppIntents.framework dependency found`. |
| **Widgets / Live Activity / CarPlay / watchOS** | Not started. There is an orphaned `AppIcon Watch.appiconset` with no watch target. |
| **Localisation** | Not started. No `.xcstrings`, no `.lproj`. Every one of ~62 `Text(...)` literals is hardcoded English — in an app for Danish public radio. |
| **Accessibility** | Effectively absent: exactly **one** `accessibilityLabel` in the entire codebase (the AirPlay button). |
| **Tests** | Xcode template stubs only — one empty `@Test`, one empty UI test, one launch-performance measure. |
| **CI** | None. |
| **README** | None. |
| **macOS / visionOS** | In `SUPPORTED_PLATFORMS` but `ContentView` has no branch for either → blank window. `AudioPlayerService` imports UIKit and `AVAudioSession`, so a macOS build would not compile regardless. Either implement or remove from the platform list. |

---

## 4. Plan

Four phases. Phase 0 is the "stop the bleeding" set; nothing ships without it.

| Phase | Theme | Outcome |
|---|---|---|
| **0 — Unblock** | Config correctness, commit the WIP | The tvOS build is submittable; the working tree is clean |
| **1 — Foundation** | Single service instance, DI seams, tests, CI | Changes can be made safely |
| **2 — Complete v1** | Search, favourites, localisation, accessibility | Actually shippable to the App Store |
| **3 — Expand** | Adaptive layout / iPhone Duo, AppIntents, on-demand, widgets | Competitive with DR's own app |

---

## 5. Todo — Feature

### P0 — blocks release

- [ ] **F1. Implement iOS search.** Port `tvOSSearchView`'s filter logic behind
      `.searchable`. Replace the `"coming soon"` stub in `lytter/ios/SearchView.swift`.
- [ ] **F2. Fill in the tvOS Brand Assets.** Every `Content.imageset` under
      `lytter/Assets.xcassets/Brand Assets.brandassets` is empty — App Icon (400×240 and
      1280×768 layered stacks), Top Shelf Image (1920×720), Top Shelf Image Wide
      (2320×720). This is the build warning and a hard App Store rejection.
- [x] ~~**F3. Fix the TopShelf/deep-link identifier mismatch.**~~ Confirmed against the
      live v5 payload — `id` is `urn:dr:radio:channel:5fa156d1…` while `slug` is `p1`, so
      every Top Shelf play action was a no-op. Fixed in #7 with
      `DRServiceManager.channel(forDeepLinkIdentifier:)`, which accepts either form; all
      four duplicated resolution sites now call it.
- [x] ~~**F4. Decide the fate of `tvOSNowPlayingView` V1/V2/original.**~~ Done in #2:
      V1/V2 preserved in `e1d7bd6`, then all three dead variants deleted and `V3` renamed
      to `tvOSNowPlayingView`. −1,432 lines.
- [ ] **F5. Remove the SwiftData launch gate.** `Item.swift` and the `ModelContainer` are
      template leftovers, yet `lytterApp` shows `ProgressView("Starting app...")` until the
      container initialises and an error screen if it fails. Delete both.
- [ ] **F6. Delete or wire up `ChannelView.swift`.** A complete iOS screen referenced by
      nothing.
- [ ] **F6b. Stop deriving channel identity from the display title.** `DRChannel.name` /
      `.district` split the title on the first space. Checked against the live v5 payload
      (25 channels, 2026-09-23): every channel parses correctly today — `P6` and `P8` have
      single-word titles despite the slugs `p6beat` / `p8jazz`. So this is **latent, not
      currently broken**, and is lower priority than first recorded. It stays on the list
      because the day DR renames a national channel to two words, tvOS grouping, the
      variant overlay, the iOS grouped cards, Top Shelf consolidation and the now-playing
      badge all mis-file it as a regional variant. Key off `slug`.

### P1 — quality of the core experience

- [ ] **F7. Favourites.** Pin channels; surface them first on Home and on the tvOS shelf.
- [ ] **F8. Recently played.** More than one entry; the data is already in `UserDefaults`.
- [ ] **F9. Sleep timer.** Fade out and pause after 15/30/45/60 min.
- [ ] **F10. Localisation.** Migrate to a String Catalog (`.xcstrings`), add **Danish**,
      and localise channel/programme strings that the app synthesises (`"Live"`, `"Not
      Playing"`, `"DR Radio"`).
- [ ] **F11. Accessibility pass.** VoiceOver labels on every control, Dynamic Type support
      (all typography is currently hardcoded `.system(size:)`), Reduce Motion for the
      marquee and focus animations, and a contrast check on the white-on-artwork text.
- [ ] **F12. Replace `NavigationView` with `NavigationStack`/`NavigationSplitView`.**
      Seven uses, all deprecated. Prerequisite for the iPhone Duo work.
- [ ] **F13. Reconcile the URL scheme.** `Info.plist` registers only `lytter`, but
      `DeepLinkHandler` also accepts `lyt` and `generateDeepLinkURL` *emits* `lyt://` —
      so links the app generates are not registered to it.
- [ ] **F14. Add a README.** Nineteen commits and no entry point for a reader.

### P2 — expansion

- [ ] **F15. Adopt AppIntents** (`PlayChannelIntent`, `AppShortcutsProvider`) and retire
      the legacy `NSUserActivity` donation path. Unlocks Spotlight, the Action Button,
      Control Centre controls and Shortcuts automations.
- [ ] **F16. On-demand playback.** Wire up `fetchScheduleSnapshot` and
      `isAvailableOnDemand` for catch-up listening.
- [ ] **F17. Schedule / EPG view.** Today's programming per channel, from data already cached.
- [ ] **F18. Widgets + Live Activity** for the currently playing channel.
- [ ] **F19. iPhone Duo support.** See [IPHONE-DUO.md](IPHONE-DUO.md).
- [ ] **F20. Decide on macOS/visionOS.** Either implement `ContentView` branches and make
      `AudioPlayerService` platform-clean, or drop `macosx`/`xros` from `SUPPORTED_PLATFORMS`.
- [ ] **F21. CarPlay.** A live-radio app without CarPlay is leaving its best use case unserved.

---

## 6. Todo — Security, privacy & compliance

### P0

- [ ] **S1. Get the API key out of source *before* there is one.**
      `DRAPIConfig.subscriptionKey` is a `static var` in `DRModels.swift` waiting for an
      Azure APIM key. If a key is ever assigned there it is committed to git and shipped in
      the binary. Move it to a gitignored `.xcconfig` (or, better, proxy the API server-side)
      and add a secret-scanning hook now.
- [ ] **S2. Remove unused entitlements.** `lytter.entitlements` declares
      `aps-environment: development`, a CloudKit container (`iCloud.Lytter`) and an app
      group — none of which the app uses. `Info.plist` declares the `remote-notification`
      background mode with no push registration anywhere. Unused background modes and a
      development APNS entitlement are both App Review flags. Either use them (see S3) or
      delete them.
- [x] ~~**S3. Fix the extension deployment target.**~~ Done in #7: `TopShelfExtension`
      lowered from `TVOS_DEPLOYMENT_TARGET = 26.0` to `17.6` to match the host app. Verified
      in the built product — both `lytter.app` and `TopShelfExtension.appex` now report
      `MinimumOSVersion 17.6`.
- [ ] **S4. Replace `print()` with `os.Logger`.** 50+ call sites compiled into release
      builds, including `DeepLinkHandler` printing full incoming URLs and channel IDs to the
      device console. Use `Logger` with `privacy:` annotations, or strip in release.

### P1

- [ ] **S5. Validate deep links before acting on them.** `handleDeepLink` accepts any
      channel id from any URL and the views immediately call `playChannel`. Low impact (it
      only starts a public radio stream) but it should resolve against `availableChannels`
      first, and `pendingChannelId` should expire rather than being retried indefinitely.
- [ ] **S6. Move the image cache out of `Documents`.** `ImageCacheService` writes to
      `.documentDirectory`; caches belong in `.cachesDirectory`. As written it is backed up
      to iCloud, never purged under disk pressure, and would be user-visible if file sharing
      is ever enabled.
- [ ] **S7. Use a stable cache-key hash.** Disk filenames are `NSString.hash.description`.
      `NSString.hash` is not stable across launches and collides — collisions serve the
      *wrong* image, and instability means the disk cache silently never hits. Use SHA-256
      of the URL.
- [ ] **S8. Harden ATS explicitly.** All endpoints are HTTPS today, but set
      `NSAllowsArbitraryLoads = false` explicitly and consider pinning `api.dr.dk`.
- [ ] **S9. Remove the force-unwrapped URLs.** `URL(string:)!` in `DRNetworkService`
      (×3), `TopShelfNetworkService`, plus `.first!` on grouped-channel arrays in `HomeView`
      and `iOSRadioView`, and `.first!` on the documents directory. Each is a crash waiting
      for an edge case.
- [ ] **S10. Adopt Swift 6 / strict concurrency.** `SWIFT_VERSION = 5.0` today.
      `DRServiceManager` mutates `@Published` state from background contexts;
      `AudioPlayerService` stores a mutable `onRequestPlay` closure on a non-isolated class.
      Move to `@MainActor` classes + `Sendable` DTOs.

### P2 — legal/operational, worth writing down before any public release

- [ ] **S11. Document the DR API posture.** The app consumes an undocumented public API,
      hardcodes 24 DR stream URLs, and displays DR-supplied artwork and trademarks. Confirm
      terms of use and attribution requirements before submitting to the App Store.
- [ ] **S12. Privacy manifest (`PrivacyInfo.xcprivacy`).** Required for App Store
      submission. Declares the `UserDefaults` required-reason API among others.
- [ ] **S13. Purge the 32 MB `lytter.xcf` from git history.** `lytter/shared/icons/lytter.xcf`
      is a GIMP source file; the `AppIcon.icon` Icon Composer sources supersede it. It is
      the single largest object in the repo.

---

## 7. Todo — Performance

Ordered by expected impact. The top three are, together, most of the cold-launch cost.

### P0 — measurable user-visible wins

- [ ] **P1. Collapse to one `DRServiceManager`.** There are three live instances:
      `ContentView` (`@StateObject`), `ShortcutsView` (its own `@StateObject`), and
      `SiriShortcutsService.getServiceManager()` — plus more in `#Preview` blocks.
      **Each `init()` triggers a full `/schedules/all/now` fetch *and* a full image
      preload.** Opening the Shortcuts tab today fires a second complete network + image
      storm. Inject one instance through the environment.

- [ ] **P2. Bound and scope image preloading.** `preloadImagesWithPriority` launches
      *three* concurrent `TaskGroup`s over every image URL in the entire schedule payload
      (primary → landscape → everything else), with no concurrency limit and no
      cancellation. On a cold launch that is hundreds of simultaneous
      `URLSession.shared.dataTask` calls. Cap concurrency (~4–6), prefetch only what is on
      screen plus a small lookahead, and cancel on disappear.

- [ ] **P3. Downsample images and set a real `NSCache` cost.**
      `memoryCache.totalCostLimit` is set to 50 MB but `setObject(_:forKey:)` is called
      **without a cost**, so the limit is inert and only `countLimit = 50` applies —
      meanwhile full-resolution artwork is decoded and held. Downsample with
      `CGImageSourceCreateThumbnailAtIndex` to the display size and pass a byte cost.

- [ ] **P4. Route every image load through `ImageCacheService`.** Today these all bypass
      it and re-download:
      - `tvOSNowPlayingArtworkCardV3` — `AsyncImage` **and** a second `URLSession.shared.data`
        of the same URL just to compute the pill colour;
      - `tvOSNowPlayingInfoSheetV3` — `AsyncImage`;
      - `TVPosterViewRepresentable.updateUIView` and `FocusableLockupUIView.setContent` —
        raw `dataTask` **from `updateUIView`**, which runs on every layout pass, so duplicate
        requests are unbounded;
      - `AudioPlayerService.loadImageForCommandCenter` — its own `dataTask` per metadata update.

- [ ] **P5. Fix the Combine subscription leak in `AudioPlayerService`.** Every `play(url:)`
      stores two new publishers in the same `cancellables` set and never clears it. After
      *n* channel switches there are *2n* live sinks all writing `isPlaying` / `isLoading`.
      Call `cancellables.removeAll()` at the top of `play(url:)`.

### P1

- [ ] **P6. Index the schedule by channel.** `getCurrentProgram(for:)` filters the full
      `cachedSchedules` array (~50–70 episodes) on every call, and it is called *from view
      bodies* — `tvOSChannelCard` for artwork, the now-playing views several times per
      render. Build `[String: [DREpisode]]` once per refresh.
- [ ] **P7. Hoist the `ISO8601DateFormatter`s.** `startDate`, `endDate` and `playedDate`
      each allocate a new formatter on every access, and `isCurrentlyPlaying` calls them
      inside filters over the whole array. One `static let` fixes it.
- [ ] **P8. Make polling cancellable.** `schedulePoll` uses bare
      `DispatchQueue.main.asyncAfter` with no handle, so `stopTrackPolling()` only flips a
      flag while pending closures still fire and re-schedule. `programRefreshTimer` is a
      repeating `Timer` that is never invalidated on background. Replace both with a single
      cancellable `Task` per channel, suspended in the background.
- [ ] **P9. Stop deactivating the audio session on pause.** `pause()` calls
      `setActive(false, .notifyOthersOnDeactivation)`, so every pause/resume tears down and
      rebuilds the session — audible resume latency, and it hands audio focus to whatever
      else is running. For live radio, keep the session active while the app is foregrounded.
- [ ] **P10. Drop the periodic time observer.** `addPeriodicTimeObserver` fires every 5 s
      to write a `currentTime` that no view displays, on a live stream with no meaningful
      elapsed time.
- [ ] **P11. Fix or disable skip/seek.** `skipForward()` seeks to `.positiveInfinity` and
      `skipBackward()` seeks to `CMTime.zero` on an ICY stream that has no seekable range —
      both are no-ops, yet the commands are advertised as enabled in Control Centre and on
      the lock screen. Either implement a real DVR window or set `isEnabled = false`.
- [ ] **P12. Cache `MarqueeText` measurements.** `widthOfString` / `heightOfString`
      construct a `UIFont` and measure on **every body evaluation** — and `MarqueeText` lives
      in the mini player, which re-renders on every player state change.

### P2

- [ ] **P13. Version and age-check the disk cache.** Add a schema version to
      `DRLocalCache`; a model change currently kills the cache silently and permanently. Add
      a max-age so a stale snapshot isn't presented as live.
- [ ] **P14. Share the cache with the Top Shelf extension** via the already-declared
      `group.com.eopio.lytter` app group, so the extension stops making its own cold network
      call on every Top Shelf refresh.
- [ ] **P15. Make channel ordering deterministic.** `Array(Set(...))` (in `loadChannels`,
      `loadDiskCache` and `Array.uniqued()`) produces unordered output; it happens to be
      sorted afterwards in some paths and not others.
- [ ] **P16. Move disk-cache encoding off the hot path.** `DRLocalCache.save` JSON-encodes
      the entire schedule array after every successful fetch. Debounce it, and write via a
      background-priority task.

---

## 8. Suggested sequence

**Sprint 1 — clean slate (≈2 days)**
~~F4~~, ~~S3~~, ~~F3~~ (done) → F2 (tvOS icons) → F5, F6 (delete dead code) → S2 (entitlements)
→ F14 (README). *Result: a submittable tvOS build and a clean tree.*

**Sprint 2 — foundation (≈3 days)**
P1 (single service manager) → extract protocols for the four services → S10 (Swift 6) →
first real unit tests against a stubbed network → GitHub Actions running both builds + tests.

**Sprint 3 — performance (≈3 days)**
P2, P3, P4, P5 → P6, P7, P8 → measure cold launch and steady-state memory before/after.

**Sprint 4 — shippable v1 (≈1 week)**
F1 (search) → F10 (Danish) → F11 (accessibility) → F12 (NavigationStack) → S12 (privacy
manifest) → F7/F8 (favourites, recents) → TestFlight.

**Sprint 5 — expansion**
F19 (iPhone Duo) → F15 (AppIntents) → F16/F17 (on-demand, EPG) → F18 (widgets) → F21 (CarPlay).
