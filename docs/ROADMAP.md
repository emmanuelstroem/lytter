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
- [x] ~~**F2. Fill in the tvOS Brand Assets.**~~ Done in #8, which grew to cover every
      platform. All 27 images are rendered by `Tools/RenderBrandAssets.swift`, which draws
      the transistor-radio mark with CoreGraphics so it stays vector-exact at any size.
      Depth is baked for the flat icons and left to the system where the platform composites
      it — tvOS parallax layers and Icon Composer both get material shading only. Also
      fixed a latent App Store blocker: the iOS icons had transparent corners, which is a
      rejection. Regenerate with `swift Tools/RenderBrandAssets.swift .`
- [x] ~~**F3. Fix the TopShelf/deep-link identifier mismatch.**~~ Confirmed against the
      live v5 payload — `id` is `urn:dr:radio:channel:5fa156d1…` while `slug` is `p1`, so
      every Top Shelf play action was a no-op. Fixed in #7 with
      `DRServiceManager.channel(forDeepLinkIdentifier:)`, which accepts either form; all
      four duplicated resolution sites now call it.
- [x] ~~**F4. Decide the fate of `tvOSNowPlayingView` V1/V2/original.**~~ Done in #2:
      V1/V2 preserved in `e1d7bd6`, then all three dead variants deleted and `V3` renamed
      to `tvOSNowPlayingView`. −1,432 lines.
- [x] ~~**F5. Remove the SwiftData launch gate.**~~ Done in #9. `Item.swift`, the
      `ModelContainer`, the `"Starting app..."` gate and its error screen are gone, along
      with `@Query` / `@Environment(\.modelContext)` in `ContentView`. Nothing in the app
      read any of it, yet it stood between launch and the first frame.
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
- [x] ~~**F13. Reconcile the URL scheme.**~~ Done in #16 — and note that **F27 was a
      duplicate of this entry**, written without spotting that the same bug was already on
      the list. Both are closed by the same change. Worth the lesson: search the roadmap
      before adding to it.
- [ ] **F14. Add a README.** Nineteen commits and no entry point for a reader.

### P2 — expansion

- [ ] **F15. Adopt AppIntents** (`PlayChannelIntent`, `AppShortcutsProvider`) and retire
      the legacy `NSUserActivity` donation path. Unlocks Spotlight, the Action Button,
      Control Centre controls and Shortcuts automations.
- [ ] **F16. On-demand playback.** Wire up `fetchScheduleSnapshot` and
      `isAvailableOnDemand` for catch-up listening.
- [x] ~~**F17. Schedule / EPG view.**~~ Done in #14, reached from the full player's list
      button. Note the original entry was wrong about the source: `/schedules/all/now`
      only carries what is on air *now*, so the rest of the day comes from
      `/schedules/snapshot/{slug}` — which `DRNetworkService` had implemented all along
      and nothing had ever called. It decodes into the existing models unchanged.
- [ ] **F18. Widgets + Live Activity** for the currently playing channel.
- [ ] **F19. iPhone Duo support.** See [IPHONE-DUO.md](IPHONE-DUO.md).
- [ ] **F20. Decide on macOS/visionOS.** Either implement `ContentView` branches and make
      `AudioPlayerService` platform-clean, or drop `macosx`/`xros` from `SUPPORTED_PLATFORMS`.
- [ ] **F21. CarPlay.** A live-radio app without CarPlay is leaving its best use case unserved.
- [x] ~~**F22. Move the iOS deep-link handler up to `ContentView`.**~~ Done in #17. The
      `.onChange(of: shouldNavigateToChannel)` was copy-pasted onto `HomeView`,
      `SearchView` and `iOSRadioView`, so a link arriving while the **Shortcuts** tab was
      active was observed by nobody and silently dropped — and had more than one been
      alive, the channel would have been played once per copy. One handler on
      `ContentView`, which outlives every tab.
      The larger bug found while doing it: `clearTarget()` also cleared `pendingChannelId`,
      and the views called it on the *first* failed attempt — which is the attempt that
      happens before the catalogue loads. So a link opened from cold cleared itself and
      the retry it was waiting for could never fire. That is the normal case for a shared
      link, i.e. links were broken for exactly the people receiving them.
      Verified end to end on the simulator: a cold-start link to `p3` now plays P3; the
      same link against the previous code left the app on "Not Playing".
      The three views no longer take a `DeepLinkHandler` at all.
- [ ] **F23. Silence the `AppIcon.icon` actool warning.** Every build, on both platforms,
      emits `None of the input catalogs contained a matching App Icon & Top Shelf Image
      brand assets collection named "AppIcon"`, attributed to the Icon Composer file. It
      declares `squares: shared` / `circles: watchOS` and cannot supply tvOS brand assets,
      which now come from `Brand Assets.brandassets`. Likely fixed by excluding
      `AppIcon.icon` from the tvOS target; needs care not to disturb the iOS icon.
- [x] ~~**F24. Three buttons in the iOS full player do nothing.**~~ Done in #14. The
      ellipsis is now a share button — its menu had exactly one live item, a `ShareLink`,
      so it cost a tap for nothing. The list button opens the channel schedule (F17). And
      AirPlay was never broken: `PlayerActionsView` already renders the same
      `AirPlayButtonView` the mini player uses, an `AVRoutePickerView` that presents the
      picker itself. What was dead was the `onAirPlayTap` callback, which nothing ever
      invoked; it has been removed.
- [x] ~~**F25. The iOS full player ignored the system appearance.**~~ Done in #15. It drew
      a hardcoded black gradient with fixed white and grey content, so in light mode the
      play/pause glyph — `.primary`, i.e. black — was invisible against it, and the AirPlay
      button, already `UIColor.label`, was black on black too. It now uses
      `systemBackground`/`secondarySystemBackground` with `Color.primary`/`Color.secondary`
      content. Note the concrete `Color.` prefix: the hierarchical `.primary`/`.secondary`
      shape styles resolve against the *current tint*, so inside a `Button` or `ShareLink`
      they render in the accent colour, not the label colour.
- [x] ~~**F26. The rest of the iOS app was hardcoded dark too.**~~ Done in #15. `HomeView`,
      `iOSRadioView` and `SearchView` each carried their own copy of the same
      `Color.black`/`0.95`/`0.9` gradient, which is why the player could be fixed alone
      without the mismatch being obvious — there was no single place to change. All four
      now share `AppBackground`. Content follows with `Color.primary`/`Color.secondary`,
      and the two hand-mixed white fills (5% for the radio rows, 10% for the retry button)
      became `tertiarySystemFill`; as written they were invisible in light mode. White that
      sits on saturated artwork placeholders, and the scrim over the channel cards, stayed.
- [x] ~~**F28. The full player dismissed itself the moment it opened.**~~ Done in #15.
      Reported from use, and the screen was effectively unreachable. Its `isPresented`
      flag was `@State` inside `MiniPlayerComponents`, which is the tab bar's bottom
      accessory: `LiquidGlassMiniPlayer` switches on `tabViewBottomAccessoryPlacement`, so
      SwiftUI rebuilds the accessory from a different branch whenever the placement
      changes — and covering the tab bar with a sheet *is* a placement change. The
      presentation destroyed its own state. `.id(playingChannel?.id)` on the accessory did
      the same on every channel change. The flag now lives in `SelectionState` and the
      sheet is presented from `ContentView`, above the `TabView`.
- [x] ~~**F27. Shared deep links could not open the app.**~~ Done in #16. The share sheet
      emitted `lyt:///channel/<id>` while `Info.plist` registered only `lytter`, so iOS
      delivered those URLs to nobody and every shared link was inert. The generator now
      emits the registered scheme. The handler used to accept `lyt` as well, which is why
      this survived review — round-tripping a link through the app worked perfectly, and
      only the system ever refused it; that arm is gone.
      Checked Top Shelf first, as the entry asked: it already used `lytter://`, and its
      `radio` authority is dropped by `URLComponents`, leaving the `/channel/<slug>` path
      the handler wants. Left alone, and pinned by a test.
      `lytterTests/DeepLinkTests.swift` asserts the generated scheme against the shipping
      Info.plist, and both link shapes against the handler. Confirmed the tests fail when
      the old generator is put back, rather than only passing against the fix.
      Worth knowing for any future link: the empty authority is load-bearing.
      `lytter://channel/<id>` parses `channel` as the host and matches nothing, failing
      silently. There is a test for that too.
- [ ] **S1. Get the API key out of source *before* there is one.**
      `DRAPIConfig.subscriptionKey` is a `static var` in `DRModels.swift` waiting for an
      Azure APIM key. If a key is ever assigned there it is committed to git and shipped in
      the binary. Move it to a gitignored `.xcconfig` (or, better, proxy the API server-side)
      and add a secret-scanning hook now.
- [x] ~~**S2. Remove unused entitlements.**~~ Done in #9. Grepped first and found no
      push, CloudKit or app-group code anywhere. Removed `aps-environment` (a *development*
      APNS entitlement), the iCloud/CloudKit container, the app group, and the
      `remote-notification` background mode. `com.apple.developer.siri` stays — the Siri
      shortcuts are real. The app group should come back when the Top Shelf extension
      actually shares the cached schedule (P14), not before.
- [x] ~~**S3. Fix the extension deployment target.**~~ Done in #7: `TopShelfExtension`
      lowered from `TVOS_DEPLOYMENT_TARGET = 26.0` to `17.6` to match the host app. Verified
      in the built product — both `lytter.app` and `TopShelfExtension.appex` now report
      `MinimumOSVersion 17.6`.
- [x] ~~**S4. Replace `print()` with `os.Logger`.**~~ Done in #13. Every live `print` is
      gone; the eight that remain are inside `#Preview` and never ship. New `Log.swift`
      declares categories under the `com.eopio.lytter` subsystem, and the Top Shelf
      extension gets its own logger on the same subsystem since it cannot see the app's.
      Values that come from outside the app, or that reveal what someone is listening to,
      are marked `privacy: .private`; slugs and counts stay `.public` so the logs are
      still useful.

      It also paid for itself immediately: a `Log.network.debug` on every outbound request
      let me finally measure the P8 fix from #12, which I had been unable to verify —
      45s playing gave 4 `indexpoints` requests, 60s paused gave **0**, and 40s after
      resuming gave 4 again.
- [x] ~~**S5. Validate deep links before acting on them.**~~ Done in #17. Resolution
      against `availableChannels` now happens in one place rather than three, identifiers
      are rejected before being stored if they are empty, longer than 256 characters or
      carry control characters or newlines, and a pending link expires after 30 seconds
      instead of being retried on every catalogue refresh for the rest of the session.
      Impact was always low — the worst case starts a public radio stream — but deep links
      are attacker-supplied input: anything on the device can hand the app a URL.
- [x] ~~**S6. Move the image cache out of `Documents`.**~~ Done in #11 — now
      `.cachesDirectory`. Verified on the simulator: `Documents/ImageCache` is empty and
      `Library/Caches/ImageCache` holds the artwork.
- [x] ~~**S7. Use a stable cache-key hash.**~~ Done in #11 — SHA-256 of the URL. The old
      `NSString.hash` is seeded per process, so the disk cache never hit after a relaunch
      and every image was downloaded again. Memory is keyed by URL *and* decode size; disk
      is keyed by URL alone, since it stores the original bytes.
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
- [x] ~~**S12. Privacy manifest (`PrivacyInfo.xcprivacy`).**~~ Done in #9. Declares no
      tracking and no collected data, plus the two required-reason APIs actually used:
      `UserDefaults` (`CA92.1`, last played channel) and file timestamps (`DDA9.1`,
      `ImageCacheService` evicting its own oldest cached artwork).
- [ ] **S13. Purge the 32 MB `lytter.xcf` from git history.** `lytter/shared/icons/lytter.xcf`
      is a GIMP source file; the `AppIcon.icon` Icon Composer sources supersede it. It is
      the single largest object in the repo.

---

## 7. Todo — Performance

Ordered by expected impact. The top three are, together, most of the cold-launch cost.

### P0 — measurable user-visible wins

- [x] ~~**P1. Collapse to one `DRServiceManager`.**~~ Done in #5 — this entry was simply
      never ticked. Verified on current `main`: one live instance in `lytterApp`, and every
      other `DRServiceManager()` is inside a `#Preview`.
- [x] ~~**P2. Bound and scope image preloading.**~~ Done in #11. The three unbounded
      task groups are one sliding window of four downloads, over the primary image per
      episode only, at thumbnail size, and cancellable. Landscape and "everything else"
      are no longer preloaded at all — they load on demand and are cached.
- [x] ~~**P3. Downsample images and set a real `NSCache` cost.**~~ Done in #11. DR serves
      1920×1080 artwork — roughly 8 MB once decoded — so a 50-image cache could reach
      several hundred megabytes. Everything is now decoded through
      `CGImageSourceCreateThumbnailAtIndex` at 512px for lists and 1024px for the player,
      and `setObject` passes the decoded byte cost so `totalCostLimit` (48 MB) is real.
- [x] ~~**P4. Route every image load through `ImageCacheService`.**~~ Done in #11. All
      eight bypassing call sites now go through the cache, including the tvOS pill-colour
      sampler that fetched the same artwork a second time just to read a few pixels, and
      the two `updateUIView` sites that re-downloaded on every layout pass. Requests for
      the same key are coalesced, so N views share one download.
- [x] ~~**P5. Fix the Combine subscription leak in `AudioPlayerService`.**~~ Done in #10.
      The set is now `playerObservations`, cleared in `play(url:)` and `stop()`. Worse than
      the memory alone: the sinks captured their `AVPlayerItem` and subscribed to their
      `AVPlayer`, so each channel switch retained one of each *and* left it writing
      `isPlaying` on the live service — a discarded player reaching `.paused` could flip
      the UI to paused during playback. Fixed alongside it: `stop()` nilled the player
      before `removeTimeObserver()`, so the periodic observer was never actually removed.

### P1

- [ ] **P6. Index the schedule by channel.** `getCurrentProgram(for:)` filters the full
      `cachedSchedules` array (~50–70 episodes) on every call, and it is called *from view
      bodies* — `tvOSChannelCard` for artwork, the now-playing views several times per
      render. Build `[String: [DREpisode]]` once per refresh.
- [ ] **P7. Hoist the `ISO8601DateFormatter`s.** `startDate`, `endDate` and `playedDate`
      each allocate a new formatter on every access, and `isCurrentlyPlaying` calls them
      inside filters over the whole array. One `static let` fixes it.
- [x] ~~**P8. Make polling cancellable.**~~ Done in #12, and the bug was worse than
      recorded. `getCurrentTrack` scheduled the next poll, which called `getCurrentTrack`
      again — a self-perpetuating `asyncAfter` chain with no handle, guarded only by
      `playingChannel` still matching. Pausing leaves `playingChannel` set so the mini
      player keeps its content, so **pausing never stopped the polling**: the app kept
      hitting `/indexpoints/live` every ~15s, foreground or background, until the channel
      changed or the app was killed. Now two cancellable `Task` loops started on play and
      cancelled on pause, stop and channel switch.
- [x] ~~**P9. Stop deactivating the audio session on pause.**~~ Done in #12. `pause()`
      no longer calls `setActive(false, .notifyOthersOnDeactivation)`; the session is
      released in `stop()`. Pausing live radio is momentary, and tearing the session down
      meant rebuilding it on every resume — audible delay, and audio focus handed to
      whatever else was running.
- [x] ~~**P10. Drop the periodic time observer.**~~ Done in #12. It fired every 5s to
      write `currentTime`, which I traced to nothing: the two views with a progress bar
      drive it from their own local `@State`. The observer, the `timeObserver` plumbing
      and the orphaned `currentTime` property are all gone.
- [x] ~~**P11. Fix or disable skip/seek.**~~ Done in #12 — disabled, not faked. These
      are live ICY streams with no seekable range, so `seek(to: .zero)` and
      `seek(to: .positiveInfinity)` did nothing while the commands were advertised as
      enabled: the lock screen and Control Centre showed skip buttons that ignored every
      press. Also removed the same two buttons from the iOS full player, which called the
      same no-ops.
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
