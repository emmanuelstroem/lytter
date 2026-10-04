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

- [x] ~~**F1. Implement iOS search.**~~ Done in #18. The tab shipped as "Search
      functionality coming soon...". It now searches channel names, districts, slugs *and
      what is on air* — "debat" finds P1 while P1 Debat is running, which the Radio tab's
      filter could not do. `role: .search` was already declared, so `.searchable` gets the
      system presentation. Home, Radio and Search now share one `GroupedChannel.grouped`
      rather than three copies.
      Later laid out as Music's Search is: before typing, Recently Searched (stations
      chosen from a search) and Browse Categories tiles; once typing, a plain list of
      rows rather than the Radio grid. A district name now lists the districts —
      "Fyn" gives P4 Fyn and P5 Fyn — not P4 and P5 to choose from again
      (`GroupedChannel.searchResult`).
      Superseded note, kept for history — the original entry read: Port `tvOSSearchView`'s filter logic behind
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
- [x] ~~**F6. Delete or wire up `ChannelView.swift`.**~~ Done in #18 — deleted. Note for
      anyone doing the same elsewhere: it was *not* the pure orphan it looked like.
      `ChannelView` and `ChannelCard` were referenced by nothing, but `SearchBar` in the
      same file is used by the Radio tab, and the project carried a platform filter for the
      path — so removing the file broke the build twice over. `SearchBar` now has its own
      file.
- [x] ~~**F6b. Stop deriving channel identity from the display title.**~~ Done, and not by
      keying off the slug as first planned. DR's `/channels` endpoint, which the app had
      never called, lists every station with its districts, and each district names its
      parent (`parentChannelSlug`) and itself (`districtName`). It is fetched beside
      `schedules/all/now` and applied to each channel as a `ChannelDirectory`, so station
      and district are DR's statement rather than a guess. The directory also showed the
      case this entry predicted is real: DR lists a national channel called "P7 MIX",
      which the title split would have filed as station P7, district "MIX". Grouping now
      keys on the station slug. The title split remains only as the fallback for a channel
      the directory does not describe, and the last directory seen survives in the disk
      cache, so an unreachable `/channels` does not mean going back to guessing.
      **Not done: Top Shelf** still splits titles, since the extension has its own copy of
      the model (see P14).
- [x] ~~**F39. Remote play/pause does not resume, and there is no scrub.**~~ Done.
      **Resume** (#41). The root cause was neither of the two guessed from the code. On
      tvOS, with the app in front, the Siri Remote's Play/Pause button arrives as a press
      event in the focus hierarchy, not as an `MPRemoteCommand`, so the command-centre
      handlers never ran; nothing in the app handled the press. Found by driving
      `XCUIRemote.shared.press(.playPause)` in the simulator with `timeControlStatus`
      logged: neither press changed the player. The fix is an `.onPlayPauseCommand` on the
      root view in `lytterApp.swift`, routed through `togglePlayback`. Session activation
      on resume also moved off the main thread, which `AVAudioSession` warned about.
      **Scrubbing.** The premise that there was nothing to seek in held only for the ICY
      fallback. DR's HLS streams carry a sliding DVR window of about 34 minutes
      (`seekableTimeRanges` measured at `0+2027 s`, start advancing with the broadcast).
      `AudioPlayerService` now publishes `canSeek` and `isBehindLive` from a 1 s periodic
      observer, and offers `skip(by:)` and `seekToLive()`, clamped to the window.
      "Behind live" is measured against a projected live edge, not the window's raw end:
      the end jumps a segment at a time on each playlist reload (~7 s), so measured raw,
      one 15 s skip straddled the 10 s threshold and Live flickered on every refresh. On
      screen: ±15 s buttons and a Live control on the iOS full player and the tvOS Now
      Playing row, shown only when `canSeek`; forward is disabled at the live edge. On the
      lock screen, `skipBackward`/`skipForward` at 15 s, enabled only while `canSeek`.
      A pause is now a time-shift: resuming inside the window carries on from where it
      stopped; past it, or on ICY, it reloads at live (and still reloads if not playing
      4 s after resuming). **Track info behind live** — done afterwards: the
      now-playing track and programme had been picked for the live edge, so while behind
      live they described what was on air, not what was heard. `AudioPlayerService` now
      publishes `secondsBehindLive`, and `DRServiceManager` picks both for `listeningDate`
      (now less that offset): the track from the last fetched list (DR's runs back about an
      hour, newest first), the programme from the schedule snapshot — which starts with
      the programme before the one on air, so it covers a rewind across a boundary —
      fetched only once the listener is earlier than the programme on air. A skip, pause or jump to live picks
      again from what is cached, with no network. A failed snapshot fetch is retried after
      60 s, not cached for good. Covered by `HeardTrackTests` and `HeardProgrammeTests`.
- [x] ~~**F40. The app icon rendered near-black on iOS and macOS.**~~ Done in #40. Three
      stacked causes, found one at a time because each hid the next:
      1. **The field was too dark.** A near-black background is most of the pixels at Dock /
         Home Screen / Spotlight sizes, so the icon read as a black square. `db36afc` only
         lightened it to a dark maroon. The field is now warm cream (`Palette.light` in
         `Tools/RenderBrandAssets.swift`); `Palette.brand` is untouched because tvOS and Top
         Shelf still use it.
      2. **The fix went to the wrong asset.** On iOS 26 / macOS 26 the system shows
         `AppIcon.icon`; the `AppIcon.appiconset` PNGs are only the fallback, and that
         fallback is all `db36afc` changed. The `.icon` fill was near-black. It now has a
         light default fill and an explicit `dark` `fill-specializations` entry, so dark mode
         does not depend on the system darkening the cream.
      3. **The `.icon` layers had no area to paint.** The four SVGs in `AppIcon.icon/Assets/`
         were `fill="none" stroke="black"`. Icon Composer paints a layer's fill colour into
         the shape's *filled* area, so the radio rendered as hairline outlines, in dark mode
         too; the dark field had been hiding it. Paths are now `fill="black"` with no stroke
         (the layer's `fill` in `icon.json` supplies the real colour).
      **Check an `.icon` with `ictool`, not the Simulator.** Simulators older than iOS 26
      show the PNG fallback and will not show this class of bug. Icon Composer's renderer
      does, without a device:
      `"/Applications/Xcode-beta.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" AppIcon.icon --export-image --output-file out.png --platform iOS --rendition Default --width 512 --height 512 --scale 1`
      (`--rendition Dark` for dark). A green build proves only that the JSON parses; the
      PNGs are drawn by a separate tool and say nothing about the `.icon`.
- [x] ~~**F41. Selecting the station that is already playing restarts it.**~~ Done.
      Choosing the channel that was on — from a shelf card, search, Favourites — tore the
      stream down and started it again. The check now sits at the top of
      `DRServiceManager.playChannel`, so all its call sites get it, as
      `selectionAction(for:loaded:hasLoadedItem:isPlaying:)`: the same channel already
      playing is left alone, the same channel paused resumes, and anything else restarts —
      another channel, another district of the same station, or a channel with no usable
      item (restored at launch, or failed). Each district is its own `DRChannel` with its
      own `id`, so comparing ids is enough. Covered by `ChannelSelectionTests`.

### P1 — quality of the core experience

- [x] ~~**F29. The full player's schedule repeated the same programme.**~~ Done in #18.
      Reported from use: P1 showed "Debat: Skattelettelser eller velfærd?" three times, all
      at 12.15, each with its own "On air" badge. DR's `id` is an *episode* URN and a
      channel airs one episode several times a day — on 2026-09-24 P1 ran
      `…:episode:6a01c544` at 10:15, 16:05 and 17:03, giving 15 broadcasts and 10 distinct
      ids. `DREpisode` is `Identifiable` on that id, so `ForEach` saw duplicate identities
      and rendered the first match for each repeat. Rows key off `broadcastID` (channel +
      start time) now. The episode id is untouched — it is correct for what it names, and
      on-demand playback will want it.
- [x] ~~**F7. Favourites.**~~ Done in #26. Pinned channels appear above the catalogue on
      Home and first in the tvOS grid.
      **Channels, not stations.** P4 and P5 are ten district channels each, reached through
      a picker sheet — so pinning *P4 København* specifically is what removes the repeated
      interaction. Pinning "P4" would leave the picker in the way, which is why the card
      for a multi-district station offers no pin control and the district rows do.
      Order is insertion order and is preserved; a `Set` would reshuffle the list between
      launches, which is the trap `uniqued()` fell into (P15). Only ids are stored, so a
      channel DR renames does not keep a stale title, and ids DR retires are dropped rather
      than left as gaps.
      Worth knowing for the next screen that reads preferences: `userPreferences` is its own
      `ObservableObject`, and **a nested one does not republish through its owner**.
      Observing `serviceManager` alone meant pinning a channel wrote the list and redrew
      nothing — the section stayed empty. `FavouritesSection` observes the preferences
      object directly. Found by running it; the build was clean.
- [x] ~~**F8. Recently played.**~~ Done in #28. `RecentlyPlayed` keeps ten channels, newest
      first; replaying one moves it rather than duplicating it, because the common case is
      returning to the same two or three stations. Ids only — a name copied here would go
      stale when DR renames something. `lastPlayedChannel` stays as it was: it keeps a title
      and district so the mini player can be populated before the catalogue loads.
- [x] ~~**F9. Sleep timer.**~~ Done in #25. 15/30/45/60 minutes, plus **end of
      programme**, which is the one a listener actually wants on live radio and which the
      schedule loaded for #14 already supports. Playback fades over the last 20 seconds
      rather than cutting.
      `SleepTimer` stores a **deadline, not a countdown**: a `Date` survives the app being
      backgrounded and suspended, where a decrementing counter drifts or stalls. Everything
      is derived from the current time, so a tick that arrives late — or not at all — cannot
      put it out of step. Eight tests, no AVFoundation, so the hour-long cases run instantly.
      Verified end to end: a one-minute timer counted 55→0 in the log and playback stopped.
- [x] ~~**F10. Localisation.**~~ Done in #20. One String Catalog,
      `lytter/Localizable.xcstrings`, with 83 keys and Danish throughout, including plural
      forms for the district count and the minutes remaining. See
      [LOCALISATION.md](LOCALISATION.md) — adding a third language is a data change, no
      code.
      The catch worth knowing: `Text("…")` localises itself, but a value assembled into a
      Swift `String` does not, and fails silently. Those sites use `String(localized:)`
      now — the synthesised `"Live"`, `"Not Playing"`, the network errors, and the
      accessibility summaries.
      Verified by running the app under `-AppleLanguages (da)`, and under `(de)`, which has
      no translations and correctly falls back to English, plurals included.
      **The Danish wording has not been reviewed by a native speaker** — it was written
      alongside the code. The mechanism is verified; the phrasing is not.
- [x] ~~**F11b. Dynamic Type in the player.**~~ Done. Three things stood in the way:
      1. **The player sized its type off a `GeometryReader`**, so at AX3 the station and
         track stayed small while the progress row beneath — already on text styles — grew.
         `PlayerInfoView` now uses `.headline` / `.subheadline` and takes the height its text
         needs.
      2. **`MarqueeText` never measured its text.** It guessed 8pt a character and 16pt tall
         whatever the font, which would have clipped larger text to a strip. It now reads
         the real size from a hidden copy (`onGeometryChange`), which also closes P12.
      3. **The icon rows sized themselves from leftover space**, so bigger text shrank the
         play button and the action icons. Both rows have fixed heights now; the Spacers
         absorb the difference, and the artwork gives way at the largest sizes.
      The mini player is on text styles with the same sizes at the default setting, capped at
      `xxxLarge` as the system's own compact bars are. Checked by screenshots at the default
      size and AX3. Covered by `PlayerDynamicTypeUITests`.
- [x] ~~**F11. Accessibility pass.**~~ Done, with the system's accessibility audit
      (`performAccessibilityAudit`) run over Home, Radio, Search and the player as the
      checklist. Labels landed in #19 and the player's Dynamic Type in F11b; the rest:
      - **Hit targets.** The player's info, schedule and sleep icons were 19pt targets;
        they have 44pt frames now.
      - **Dynamic Type beyond the player.** The programme line under a station card scales
        (`@ScaledMetric`, so tvOS — which has no Dynamic Type — is unchanged). The station
        name on a card's artwork deliberately does not: it sits in a fixed card, sized so
        every name DR broadcasts fits (`StationCardTests`), and would only truncate.
      - **Contrast.** Secondary text on the page and the player sheet moved from
        `Color.secondary` (60%) to `Color.secondaryOnPage` (primary at 75%); 60% grey on the
        page's #1C1C1E and the lighter sheet sat at or under 4.5:1 for 11pt text. The
        audit still flags some of it — but it also flags full-strength white on the sheet,
        so its contrast check is not usable here; judged by the colours instead.
      - **Reduce Motion.** The marquee stops scrolling and truncates. The tvOS focus springs,
        which overshoot, become a short ease (`focusAnimation(value:)`).
      Guarded by `AccessibilityAuditUITests` (hit targets and element descriptions only — the
      checks the audit makes reliably). **Not done:** nobody has listened to the app through
      VoiceOver, and the marquee's Reduce Motion path was checked by reading, not on screen
      (no fixture title is long enough to scroll).
- [x] ~~**F12. Replace `NavigationView` with `NavigationStack`.**~~ Done in #21. Five
      containers across four files, and the useful finding was that **the app has no
      `NavigationLink` anywhere** — nothing was navigating. Three of the five had a title
      or toolbar and became `NavigationStack`; two (Home and the full player) had no title,
      no toolbar and nothing to push, so the container went entirely, taking
      `navigationBarBackButtonHidden` with it — it was hiding a back button that could
      never exist.
      `NavigationSplitView` was not used: it is for multi-column layouts, and this is a
      tab-based app with no master/detail anywhere. Reaching for it would have changed
      behaviour on iPad for no reason.
      Verified by screenshot on all four screens; every one renders as it did before.
- [x] ~~**F13. Reconcile the URL scheme.**~~ Done in #16 — and note that **F27 was a
      duplicate of this entry**, written without spotting that the same bug was already on
      the list. Both are closed by the same change. Worth the lesson: search the roadmap
      before adding to it.
- [x] ~~**F30. Playback could start on its own.**~~ Done in #22. Found by audit, not by
      report, and it is the kind that would be hard to report: the trigger is arbitrarily
      far from the cause.
      `wasPlayingBeforeInterruption` was set when an interruption began and cleared only
      when it resulted in a resume. An interruption that ended **without** `.shouldResume`
      left it set — and the route-change handler resumed on `.newDeviceAvailable`. So a
      call that ended quietly, then plugging in headphones an hour later, started the radio
      unprompted.
      Two further defects in the same place. `pause()` read
      `if !wasPlayingBeforeInterruption { wasPlayingBeforeInterruption = false }` — it
      assigns false only when already false, so it never cleared anything, which is exactly
      the escape hatch that would otherwise have masked the first bug. And resuming on
      `.newDeviceAvailable` is against Apple's guidance to begin with: a route becoming
      available is not a request to play.
      The flag is now an `InterruptionState` value type whose `ended(systemAllowsResume:)`
      clears the intent either way, with `pause(resumable:)` distinguishing a pause the
      system caused from one the listener asked for. Six tests; confirmed that the one
      encoding the reported sequence fails against the old behaviour and the other five
      still pass.
      Unchanged deliberately: `.oldDeviceUnavailable` still pauses. Audio must not carry on
      out of the speaker when headphones are unplugged.
- [x] ~~**P18. `ImageCacheService` in-flight map had a race.**~~ Done in #23. Cleanup was
      unconditional — `inFlight[key] = nil` — but two callers can await the same task, and
      by the time the second retires it a third may already have registered a new one under
      that key. The second wiped the third's entry and the next request downloaded an image
      that was already on its way. `release` now takes the task it is retiring and removes
      it only if it is still the registered one.
- [x] ~~**P19. Three Swift 6 concurrency warnings in `ImageCacheService`.**~~ Done in #23.
      The `NSLock` critical sections moved into a synchronous type, so the lock is never
      taken inside an `async` function — which is both what the warning was about and a
      structural guarantee it cannot be held across a suspension. The two size constants
      became `nonisolated`; under approachable concurrency a plain `static let` is inferred
      main-actor isolated, and they are read as default arguments of an async method.
      **Not done with an actor**, which is what P18/P19 originally proposed. An actor would
      have made every call `await`, including the synchronous memory-cache hit in
      `loadImage(from:completion:)` that exists specifically to avoid a flicker during
      layout. `NSCache` is already thread-safe, so the only state that needed protecting
      was the coalescing map, and `InFlightTasks` protects exactly that.
      The app's source now builds with **no Swift warnings** on either platform; the two
      that remain are the `AppIcon.icon` asset ones tracked as F23.
- [x] ~~**S10 remains open.**~~ Done. `SWIFT_VERSION` is 6.0 in all eight configurations
      (#24, recorded under S10 below). The escapes from the checker are two, and each says
      why in the code: `InFlightTasks` is `@unchecked Sendable` because its lock is held
      only inside synchronous methods, and `DRDate`'s formatter is `nonisolated(unsafe)`
      because `ISO8601DateFormatter` is documented thread-safe. The observable services are
      main-actor by the project's default isolation; whether that default is the right
      one is a design question, tracked separately as S15. The build has stayed
      warning-free since S16.
- [x] ~~**F31. The lock-screen artwork handler crashed the app.**~~ Done in #25 — and it
      was **introduced by #24**, the Swift 6 migration. `MPMediaItemArtwork`'s request
      handler was written inline in a main-actor method, so under
      `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` the closure was main-actor isolated.
      MediaPlayer calls it on its own queue, and Swift 6 enforces isolation at runtime:
      `dispatch_assert_queue` failed and the app took a `SIGTRAP` the moment the lock
      screen asked for artwork — which is to say, on every playback of a channel with an
      image.
      Builds were clean and 30 tests passed throughout. It took **running the app with
      playback** to find it, via crash reports in `~/Library/Logs/DiagnosticReports`. The
      handler is a `nonisolated static` helper now.
      The lesson is the cheap one: a language-mode change that moves checks from compile
      time to *runtime* cannot be signed off by a green build.
- [x] ~~**F32a. A broadcaster model.**~~ Done in #27. The home screen reads as one section
      per broadcaster rather than a section literally called "DR". While DR is the only
      source those are indistinguishable, which is exactly why the seam was worth building
      before the second one arrives: `Broadcaster.sections(from:)` groups and orders, a
      broadcaster with no channels is omitted rather than left as an empty heading, and
      `BroadcasterChannelsSection` takes its name from the model.
      Adding a source is now a `Broadcaster`, a network service returning its channels, and
      an entry in `registered` — no layout changes.
- [x] ~~**F32. Apple Music-style home, all four platforms (iOS, iPadOS, tvOS).**~~ *iOS and
      iPadOS done in #28.* Favourites, Recently Played and one shelf per broadcaster, each a
      horizontally scrolling row of square artwork cards. Every row is the same
      `ChannelShelf`, which takes `GroupedChannel` so a station and a single channel need one
      card. Radio and Search were converted onto the same card in #39, and every card fades
      into its caption now — a hard-edged band read as a lit strip on bright artwork, which a
      gradient has no edge to catch.
      *tvOS done in #32–#33.* The top tab bar is gone; navigation is the system sidebar
      (`.tabViewStyle(.sidebarAdaptable)`, tvOS 18+, with the old tab bar kept below it) the
      TV and Music apps use. The card was rewritten from nothing in #33 to match the Music
      app exactly — clean artwork, plain text underneath, the system's own focus lift rather
      than a hand-rolled glow — after the first pass (#32) turned out to be the phone's card
      carried across rather than a native tvOS design. Hold-select favourites; the player has
      a schedule sheet, matching iOS.
      **Only macOS remains (F20).**
      **Remaining: macOS**, which has no UI at all (F20).
      Still true, and worth repeating: other broadcasters do not exist. The shelves are
      broadcaster-shaped but DR is the only source, and a second one is a data change.
- [ ] **F33. Favourite shows, not just channels.** Store series ids and surface a
      favourited programme with when it is next on. Needs the per-channel schedule snapshot
      that #14 wired up. Deliberately deferred: favourites are channels for now.
      Checked 2026-10-04: not started; favourites are still channels only.
- [x] ~~**F34. tvOS: the sidebar opens expanded on every launch.**~~ Done. tvOS shows a
      `.sidebarAdaptable` sidebar expanded at launch and folds it away only once focus is
      in the content, which the system did some seconds later. There is no API to start it
      collapsed: `.prefersDefaultFocus`, `.defaultFocus` and disabling every tab
      (`Tab.disabled`, tvOS 18.4) all left it open. Home now puts focus on its first card
      itself (`placeLaunchFocus`, a `@FocusState` the shelves tag their cards with, retried
      until it lands — one attempt was dropped on a slower launch), and a plain cover hides
      the screen meanwhile, so the sidebar folding away is not seen as a glitch. The cover
      fades once a card has focus (about 1.2 s in the simulator), or after 5 s if no content
      arrives — a cold start on a slow connection — leaving the sidebar to take focus.
      Measured with screenshot bursts every ~0.35 s after launch. Covered by
      `TVLaunchFocusUITests`.
- [x] ~~**F35. tvOS: Back and the TV button should leave the app.**~~ Not reproducible
      on tvOS 26.5. Reported as Back getting stuck on the app's own Home instead of
      returning to the Apple TV home screen. Driven with `XCUIRemote` and a screenshot
      after each press: from Home, Back moves focus into the sidebar and the next press
      leaves the app; from Now Playing, Back goes Home, then the sidebar, then out — the TV
      and Music apps' behaviour. Most likely fixed by the move to the system sidebar
      (`.sidebarAdaptable`), which owns Back. Not checked: tvOS 17's top tab bar, the
      sheets, and the TV button, whose action is a system setting the app cannot change.
      Trap for whoever re-checks: just after the app leaves, XCUITest still reports it
      `runningForeground` with nothing focused, which looks exactly like "stuck" — look
      at the screen.
- [x] ~~**F36. tvOS: Search at the top of the sidebar.**~~ Done. Search is the first
      tab, above Home, as in the TV and Music apps; the tvOS 17 tab bar has the same order.
      Home is still where the app opens. `TVScrollingUITests.testSidebarOrder` walks the
      sidebar with the remote and checks the whole order.
- [x] ~~**F37. tvOS: Settings at the bottom of the sidebar.**~~ Done with F43: the last
      sidebar destination, holding the remembered region (shown, with Forget Region),
      Remove All Favourites and Clear Recently Played, each of the last two confirmed
      first. The same sections are on iOS and in the Mac's Settings window.
- [x] ~~**F38. An animated playing mark.**~~ Done. `PlayingMark` replaced
      `speaker.wave.2.fill` wherever it said "this one is playing": tvOS cards, the district
      pickers (the phone's sheet, the television's panel — through `itemIsPlaying`, since a
      moving mark is not a symbol name), the phone's search rows and the Mac's cards. A dot
      and two rings, like a speaker cone head on, that breathe in and out over 1.6 s, the
      outer ring a little behind the inner. It takes the box of a hidden `circle` symbol, so
      it sits where the symbol did and follows Dynamic Type, and draws in the foreground
      style, so it inverts with a focused pill like the marks beside it. The mark itself
      only appears while sound is actually playing: it used to stay on a paused channel and
      on the last-played channel restored at launch, fixed alongside this entry by
      `DRServiceManager.isAudible`. Reduce Motion draws the same rings still. Covered by
      `PlayingMarkAnimationTests` (it moves, repeats, stays inside its box, and holds still
      at rest); `StationCardTests` measures names against the new mark's box. Checked
      running on iPhone (search rows, district sheet, Reduce Motion on and off) and Apple
      TV (cards and picker); the Mac only built and unit-tested, not looked at.
- [x] ~~**F42. Network errors in the UI.**~~ Done. Each screen used to decide for itself
      from `DRServiceManager.error` and `playbackError`, in whatever words the error carried;
      tvOS Home showed nothing at all. Now:
      - **One answer.** `ConnectionProblem` — *offline*, *DR isn't answering*, *couldn't
        play P3*, most fundamental first — from `NWPathMonitor` (`NetworkMonitor`), how the
        last catalogue fetch failed (`RequestFailure`), and the stream. The path monitor is
        what tells the first two apart: `DRNetworkService` waits for connectivity, so an
        offline request does not fail as offline, it times out like a request to a DR that
        is down.
      - **One presentation.** `ConnectionBanner` over channels still on screen (cached or
        fresh), on every channel list on all three platforms; `CatalogueStateView` in their
        place when there are none — loading, the problem with Try Again, or empty. The
        players show only what stops audio (offline, the stream failing): a banner in the
        iOS full player, a line without a button on tvOS Now Playing (Play is the retry, and
        a button would join the transport's focus row), the programme line of the macOS
        player bar. DR's API being down is not shown there; the stream plays on.
      - **Recovery.** When the path returns, the catalogue is fetched and a stream that
        failed or stalled is restarted (`AudioPlayerService.wantsPlayback`,
        `reloadIfStalled`). While DR is down, retries run at 15 s, 30 s, 60 s, then every
        2 minutes. Concurrent `loadChannels()` calls — every screen's `onAppear` makes one —
        now share one fetch.
      - **Slow.** After 6 s with nothing on screen, "Still waiting for DR…" — after the 5 s
        tvOS launch hold (F34) lifts.
      - **Stale data.** The catalogue is the schedule, and it was fetched once at launch: a
        long listen kept showing the programme on then. The programme refresh now refetches
        it every 10 minutes while playing. A failed track poll drops a track that has ended
        instead of showing it indefinitely. The schedule sheets say the fetch failed, with
        Try Again, instead of "No schedule".
      Covered by `ConnectionProblemTests` and `ConnectionStatusUITests`, which simulate the
      conditions with `LYTTER_UITEST_NETWORK` (`offline`, `offline-cached`, `dr-down`,
      `dr-down-cached`, `reconnects`) so they never touch the machine's network. Not
      verified on a real dropped connection mid-stream: the simulator shares the Mac's
      network, so that path (`reloadIfStalled`) is checked by reading, not by running.
- [x] ~~**F43. Settings.**~~ Done. One set of sections (`SettingsSections`) in three
      containers: a Settings tab on iOS, which took the Shortcuts tab's place — Siri &
      Shortcuts is a row inside it now — the last sidebar destination on tvOS (F37), and
      the Settings window (⌘,) on the Mac.
      - **Show Images** (default on). Off, every picture is the station's colour and name
        (`StationArtworkPlaceholder`), and the catalogue's images are not preloaded. An
        environment value that `CachedAsyncImage` reads, so no screen has to remember it.
        The station colour replaced a hue taken from `hashValue`, which changed per launch.
      - **Screen Off** (default 30 s; never, 30 s, 1, 2 or 5 min). iOS and tvOS only.
        `ScreenOffController` watches the window with a recogniser that notices every touch
        and press and recognises none; after the delay, while playing, a black window goes
        up above the app's — above the full player sheet too, which an overlay would not
        be — and swallows the first touch or press, Menu included. VoiceOver sees one
        element that a double-tap dismisses. `preventScreenSleep` is untouched: the system
        still locks on its own schedule. Off under UI tests unless a test sets it.
        **Not covered by a UI test**: fixture streams never play, and the blackout only
        runs while playing. Checked by reading; check by hand on a real stream.
      Persisted through `UserPreferencesService`; the views observe it directly.
- [x] ~~**F44. Long district names overflow the Mac's standard card when playing.**~~ Done.
      The Mac card put the playing marker beside the name; at 160 points the six longest
      district names do not fit beside it ("P4 - Nordjylland": 125 points against 121), and
      widening does not help because the marker scales with the card. On the standard card
      the marker now leads the programme line beneath the card (`StationCard.Subtitle`'s
      `showsPlayingMarker`) and the name has the caption to itself; the featured card, where
      every name fits with it, keeps it beside the name. One rule decides it,
      `macOSStationCard.marksPlayingBesideName`, and
      `StationCardTests.everyNameFitsAMacCard` measures whichever layout it picks — the
      known-issue wrapper is gone.
- [x] ~~**F45. Search lists every station, and finds districts and programmes.**~~ Done.
      One answer for all three platforms, `StationSearch`. Before anything is typed: every
      station once, P4 and P5 as stations rather than ten districts each — on the phone under
      Recently Searched, in place of the browse categories, which a list of every station made
      redundant. Once something is typed, every word has to be found, in any order and
      ignoring case and accents: in a name anywhere ("jylland" finds Nordjylland and
      Østjylland), in what is on air — title, series, description, categories — from the
      start of a word. A station's name gives the station; a district's gives that channel,
      to play; a programme on every district at once gives the station. Names rank before
      programmes. Laid out as Music does on each: rows on the phone; on the television a
      grid, then a shelf per kind (Stations, On Air Now); on the Mac the field at the top of
      the sidebar, opening Search as you type, and the same sections as grids. Only the
      programme on air now is searched — upcoming ones would mean fetching every channel's
      schedule. Covered by `StationSearchTests`,
      `SettingsAndSearchUITests.testSearchOpensOnEveryStation` and
      `TVScrollingUITests.testSearchResultShelfScrollsSideways`. Checked running on iPhone
      and Apple TV; the Mac only built, not looked at.
- [x] ~~**F46. The Mac app crashed as it opened.**~~ Done. The same fault as F31, on the
      other platform: the fallback now-playing artwork was an `NSImage` with a drawing
      handler, which runs whenever the image is rendered — and MediaPlayer renders it on its
      own queue, turning it into JPEG data. The handler was main-actor isolated by the
      project's default, Swift's isolation check trapped there, and the app died before its
      window appeared. It took the unit-test host down with it, which read as "the test
      runner crashed before establishing connection". It is now drawn at once into a bitmap,
      as iOS's renderer always did. `DefaultArtworkTests` renders it from another queue (an
      `async` hop: a `sync` from the main thread runs on the main thread and passed against
      the bug) and checks it is the gradient. The Mac unit tests run again, all 199; the app
      was launched and stayed up, but not looked at — this machine gives no screen capture.
- [x] ~~**F47. SharePlay could be offered and never received.**~~ Done. tvOS activated an
      activity and nothing in the app ever asked for the sessions activation creates, so
      whoever accepted "listen together" heard nothing. Nor could it have: the app had no
      `com.apple.developer.group-session` entitlement, and the activity called itself
      `.watchTogether`. Now, in `shared/shareplay/SharePlay.swift` and on all three
      platforms: `SharePlayCoordinator` joins sessions and hands the session's channel to
      the deep-link path, waiting for the catalogue first, so each platform's existing
      resolve-and-navigate does the rest. Once a listener has caught up with the session,
      their channel changes move everyone (`SharePlayFollow`); joining while playing
      something else does not drag the session along. Pause stays personal — it is live
      radio. iOS and macOS share a `SharedChannel` carrying a
      `GroupActivityTransferRepresentation`, which puts SharePlay in the share sheet as in
      Music: the full player's share button on iOS, a new share button in the Mac's player
      bar. tvOS keeps its button, shown only while `GroupStateObserver` says there is a
      call to share into. Covered by `SharePlayTests`. A call cannot be placed in a
      simulator, so a session has not been seen end to end; that needs two devices.
- [x] ~~**F48. iOS opened on Search rather than Home.**~~ Done. The tab selection was
      `@SceneStorage`, which restores the last tab, so a listener who had last searched
      came back to Search — and the UI tests' launch check could not tell, because it
      waits for a button starting "P1" and Search's rows start that way too. It is plain
      `@State` now, so the app always opens on Home. Covered by
      `SettingsAndSearchUITests.testLaunchOpensOnHomeNotTheLastTab`, which leaves through
      the home screen (when scene state is saved) and relaunches; it failed before the fix.
- [ ] **F14. Add a README.** Nineteen commits and no entry point for a reader.
      Checked 2026-10-04: not started; there is still no README.

### P2 — expansion

- [x] ~~**F15. Siri and Shortcuts.**~~ Done. Two mechanisms, because App Shortcuts must
      name the app in every phrase and a radio app wants "Play P3":
      - **App Intents, iPhone** (`PlaybackIntents.swift`), each phrase naming the app:
        Resume ("Play Lytter"), Pause, sleep timer ("Stop Lytter in 30 minutes" — 15/30/45/60,
        the app's own choices; phrases take enums, not free numbers), Stop after this
        programme, What's On ("What's on Lytter?", for the station playing or last played).
        Danish phrases in `AppShortcuts.xcstrings`. In the Shortcuts app and for the Action
        Button too, alongside Play Station and What's On with a station picked from a list.
      - **SiriKit media intent, iPhone and Apple TV** (`PlayMediaIntentHandler`): playing a
        station by name — "Play P3", with or without "in Lytter". "P4" means the listener's
        own district (`StationLookup`). Handled in the app (no extension). Needs Siri
        permission, asked for from Settings (`SiriAccessRow`), and `com.apple.developer.siri`.
      - Retired: `SiriShortcutsService`, the old Siri screen and its donations, and the
        Siri prompt on opening it. Shortcuts saved the old way still run — their
        `PlayChannelActivity` goes through the deep-link handler.
      - **No App Shortcut takes a station, on purpose.** iOS 26 collapses an App Shortcut
        with an entity parameter into one tile in the Shortcuts app and one row in Spotlight,
        captioned with the *last* value and running the *first* — a "P8" tile that played P1,
        and a Spotlight search for "P3" listing "P8". A textbook two-value entity (no app
        code, no isolation, no custom presentation) does exactly the same on a fresh
        simulator, so it is the system. Tried first and ruled out: the title's localisation
        key, colon-free ids, `parameterPresentation` with an options provider, a `@Property`
        name, names without digits. Enum parameters are not affected — the sleep timer's
        four tiles are right. Revisit when a later iOS fixes it.
      - **Not verified:** anything spoken. The simulator has no Siri voice, so the media
        intent on iPhone and Apple TV, and the Danish phrases, need a device. Verified in
        the simulator: every App Shortcut registers and runs from the Shortcuts app.
      - Not done: Control Centre controls (a widget extension — F18), Spotlight indexing of
        each station (`IndexedEntity`), App Shortcuts on Apple TV (no evidence Siri runs
        them there), macOS.
      - **Trap:** App Shortcuts do not run from an ad-hoc signed simulator build — the
        Shortcuts app says "Couldn't find AppShortcutsProvider" and the station tiles never
        appear. `xcodebuild` signs simulator builds ad hoc; re-sign the `.app` with the
        team's Apple Development certificate (`codesign --force --sign … --entitlements
        <lytter.app.xcent>`) before testing intents in the simulator.
- [ ] **F16. On-demand playback.** Wire up `fetchScheduleSnapshot` and
      `isAvailableOnDemand` for catch-up listening.
      Checked 2026-10-04: not started. The schedule snapshot is used, for the schedule
      sheet and to show what is heard behind live, but `isAvailableOnDemand` is decoded
      and never read.
- [x] ~~**F17. Schedule / EPG view.**~~ Done in #14, reached from the full player's list
      button. Note the original entry was wrong about the source: `/schedules/all/now`
      only carries what is on air *now*, so the rest of the day comes from
      `/schedules/snapshot/{slug}` — which `DRNetworkService` had implemented all along
      and nothing had ever called. It decodes into the existing models unchanged.
- [ ] **F18. Widgets + Live Activity** for the currently playing channel.
      Checked 2026-10-04: not started; no widget extension, no WidgetKit or ActivityKit.
- [ ] **F19. iPhone Duo support.** See [IPHONE-DUO.md](IPHONE-DUO.md).
      Checked 2026-10-04: not started beyond those notes.
- [x] ~~**F20. macOS is unimplemented, not broken.**~~ Done. Step 2 landed as `e311164`: a
      `NavigationSplitView` styled like Music.app (sidebar of Home, Radio and Search, a
      player bar docked along the bottom), and `ContentView` now has its macOS case. Since
      then: Settings on every platform (#53), the search field at the top of the sidebar
      (#61), the card's playing marker (#58), and the app opening at all (#62, F46). The
      original entry follows.
      **Step 1 done** — the shared layer
      compiles for macOS (`CODE_SIGNING_ALLOWED=NO`; a separate, unrelated expired signing
      certificate on this machine blocks a *signed* build). `PlatformImage`/`PlatformColor`
      typealiases in `PlatformTypes.swift` cover `UIImage`/`UIColor`; every
      `AVAudioSession`, `AVRoutePickerView` (AirPlay) and iOS/tvOS-only SDK symbol is now
      behind `#if os(iOS) || os(tvOS)` rather than assumed to exist everywhere; three tvOS
      files had `import UIKit` sitting outside their own `#if os(tvOS)` guard, invisible
      until macOS tried to compile them too. iOS, tvOS and macOS all build clean; 112 tests
      pass.
      **`ContentView`'s `body` still has no macOS case** — `#if os(iOS)` /
      `#elseif os(tvOS)` / `#endif`, so the app opens an empty window there. That is step 2,
      deliberately not attempted alongside step 1:
      1. ~~*Make the shared layer compile for macOS.*~~ Done. Mechanical, no design
         decisions — the point was to stop the target being permanently red and make every
         later change to shared code verifiable on macOS instead of silently iOS-only.
      2. *Build a macOS UI.* From nothing — no view is shared with it. This should follow
         the sectioned home (F32) rather than precede it, or it gets built twice.
- [ ] **F21. CarPlay.** A live-radio app without CarPlay is leaving its best use case unserved.
      Checked 2026-10-04: not started; no CarPlay entitlement or templates.
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
- [x] ~~**F23. Silence the `AppIcon.icon` actool warning.**~~ Done in #25, and the cause
      was not the one guessed here. `AppIcon.icon` was a resource of **the Top Shelf
      extension**, which compiles with `--app-icon AppIcon --target-device tv`. An Icon
      Composer file declares `squares: shared` / `circles: watchOS` and cannot supply tvOS
      brand assets, so actool reported it could find none. The second warning followed from
      the same thing: the extension's asset compile was being thinned for an *iPhone*
      device configuration during iOS builds.
      An appex has no app icon of its own, so removing it from that target was the whole
      fix. Both app icons verified intact afterwards — iOS `CFBundleIconName = AppIcon`
      with its PNGs, tvOS Brand Assets in a 7.9 MB `Assets.car`.
      **Both platforms now build with no warnings at all.**
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
- [ ] **S1. Get the API key out of source *before* there is one.** *Partly addressed in
      #24: `subscriptionKey` is now an immutable value read from `DRSubscriptionKey` in
      Info.plist rather than a mutable `static var` in source, so an xcconfig can supply it
      without anyone editing a Swift file. It had to change — a mutable global is rejected
      outright under Swift 6 — and nothing had ever assigned it.*
      Checked 2026-10-04: the source half is done. `DRAPIConfig.subscriptionKey` is a
      `nonisolated static let` read from `DRSubscriptionKey` in Info.plist, nothing in the
      repository sets that key, and the API works without one. Remaining: a key placed in
      Info.plist or the project would still be committed to git and shipped in the binary.
      Supply it from a gitignored `.xcconfig` (or, better, proxy the API server-side), and
      add a secret-scanning hook. Neither exists yet.
- [x] ~~**S2. Remove unused entitlements.**~~ Done in #9. Grepped first and found no
      push, CloudKit or app-group code anywhere. Removed `aps-environment` (a *development*
      APNS entitlement), the iCloud/CloudKit container, the app group, and the
      `remote-notification` background mode. `com.apple.developer.siri` stays — the Siri
      shortcuts are real. (Since F15 it is for SiriKit's media intent, "Play P3".) The app group came back with P14, when the Top Shelf extension
      began reading the cached schedule.
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
      Checked 2026-10-04: not started. Neither Info.plist has `NSAppTransportSecurity`, so
      ATS is at its secure default but not stated, and nothing is pinned.
- [x] ~~**S9. Remove the force-unwrapped URLs.**~~ Done in #18. There were four, not one,
      and two of them interpolate a channel slug that comes from the API — a slug with a
      space would have crashed the app rather than failing a request. Those percent-encode
      and throw `invalidURL` now. Original entry: `URL(string:)!` in `DRNetworkService`
      (×3), `TopShelfNetworkService`, plus `.first!` on grouped-channel arrays in `HomeView`
      and `iOSRadioView`, and `.first!` on the documents directory. Each is a crash waiting
      for an edge case.
- [x] ~~**S10. Adopt Swift 6 / strict concurrency.**~~ Done in #24. `SWIFT_VERSION` is
      6.0 in all eight configurations, and both platforms plus the Top Shelf extension
      build with **no errors and no warnings**.
      The job was far smaller than the entry implied: a build with
      `SWIFT_STRICT_CONCURRENCY=complete` surfaced three warnings, and Swift 6 language
      mode exactly one hard error. What it found was mostly **cleanup that could not run**:
      `ImageCacheService.deinit` cancelled a task on a singleton that only deallocates at
      process exit; `AudioPlayerService.deinit` called main-actor command-centre cleanup
      whose targets already capture `self` weakly, and which `stop()` does anyway;
      `RemoteDetectorHostView.deinit` removed a gesture recognizer that `didMoveToWindow`
      had already removed on the way out of the hierarchy. All three deleted.
      Two real ones: `DRAPIConfig`'s members are read from the nonisolated network layer,
      so they are `nonisolated` now; and `RadioShareActivity` was declared *inside* a
      main-actor method, which made its `GroupActivity` conformance main-actor isolated and
      unusable from the concurrent task that awaits `activate()`. Hoisted to file scope.
      Test suites are `@MainActor`: the project sets
      `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so the types under test are main-actor by
      inference while suites are nonisolated by default.
- [x] ~~**S16. The build is not warning-free again.**~~ Done. A clean build on iOS, tvOS and
      macOS now has no Swift warnings. There were:
      - `AudioPlayerService` (three): `Log.playback` used from the audio-session queue —
        `Log` is `nonisolated` now, which `Logger` being `Sendable` allows — and the
        periodic time observer calling main-actor `refreshSeekState()` from a closure that
        is nonisolated by type though it runs on `.main`; it says so with
        `MainActor.assumeIsolated`.
      - `TVScrollingUITests` (~35): its helpers are `@MainActor`, as its tests already were.
      - `ConnectionStatusUITests`, shipped in #50 and fixed in #51.
      What is left is `appintentsmetadataprocessor` noting that there is no AppIntents
      dependency — a toolchain notice, not source; F15 removes it.
      **Check with a clean build on all three platforms.** Incremental builds report only
      the files they recompile, and tvOS-only test files never appear in an iOS build;
      that is how these went unnoticed.
- [x] ~~**S17. The test target does not build for macOS.**~~ Done. `StationCardTests` imported
      UIKit unconditionally (since #35); it now measures with AppKit on the Mac, so
      `xcodebuild clean build-for-testing -destination 'platform=macOS'` builds and the unit
      tests run there. Porting it found a bug the suite had never been able to see — F44.
- [ ] **S15. Revisit what default main-actor isolation actually buys.** With
      `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, types are main-actor unless they say
      otherwise — including `InFlightTasks`, whose whole purpose is to be touched from
      several tasks. Its lock is then belt-and-braces rather than load-bearing. Worth
      deciding deliberately which types are nonisolated, rather than inheriting it.
      Checked 2026-10-04: not started. `InFlightTasks` is still main-actor by default.
- [ ] **S11. Document the DR API posture.** The app consumes an undocumented public API,
      hardcodes 24 DR stream URLs, and displays DR-supplied artwork and trademarks. Confirm
      terms of use and attribution requirements before submitting to the App Store.
      Checked 2026-10-04: not started.
- [x] ~~**S12. Privacy manifest (`PrivacyInfo.xcprivacy`).**~~ Done in #9. Declares no
      tracking and no collected data, plus the two required-reason APIs actually used:
      `UserDefaults` (`CA92.1`, last played channel) and file timestamps (`DDA9.1`,
      `ImageCacheService` evicting its own oldest cached artwork).
- [x] ~~**S13. Purge the 32 MB `lytter.xcf` from git history.**~~ Done. The entry
      understated it: the file was not merely in history, it was being **copied into the
      shipped app bundle on both platforms**, because the app target is a folder-synced
      group and any non-source file in it is treated as a resource. 32 MB of a 40 MB iOS
      download did nothing at runtime.
      Removed with `git filter-repo` and force-pushed. One commit disappeared in the
      rewrite — `3113a71 add GIMP icons file` touched only that file, so it was pruned as
      empty; 70 commits became 69 and nothing else changed. The 13 merged branches were
      deleted too, otherwise GitHub would have kept the old objects alive and a fresh clone
      would still have pulled them.
      Measured: app bundle 40 MB → **7.7 MB**; fresh clone 47 MB → **30 MB** (the blob
      compresses to ~17 MB in the pack). Verified by cloning from scratch: no `.xcf` in any
      object, 113 files at HEAD, both platforms build, 19/19 tests pass.
      The file itself is **not lost** — it is at
      `/Users/emmanuel/Developer/Github/emmanuelstroem/lytter-icon-source.xcf`, outside the
      repo, and `.gitignore` now excludes `*.xcf`, `*.psd` and `*.sketch` so it cannot
      drift back in.
- [ ] **P17. The brand assets are the next-largest thing in history.** Five PNG blobs of
      1–4.5 MB under `lytter/Assets.xcassets/Brand`, re-committed several times while the
      icons were being iterated, are most of the 30 MB that remains. They are real shipped
      assets, so the fix is not deletion — it is checking whether the tvOS layered images
      need to be that large, and not re-committing regenerated variants.
      Checked 2026-10-04: not started. The Top Shelf images are still 4.3 MB (wide @2x),
      3.5 MB, 1.2 MB and 0.9 MB, and the packed history is 58.7 MB.
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

- [x] ~~**P6. Index the schedule by channel.**~~ Done. `getCurrentProgram(for:)` filtered
      the full `cachedSchedules` array (~50–70 episodes) on every call, and it is called
      *from view bodies* — `tvOSChannelCard` for artwork, the now-playing views several
      times per render. `cachedSchedules` now rebuilds a `[String: [DREpisode]]` index in
      its `didSet`, so every place that replaces it keeps the index current, and all four
      per-channel lookups read from it. Each channel keeps its programmes in schedule
      order, because the lookups take the first match. Covered by `ScheduleIndexTests`.
      Measured on the iPhone 17 simulator (Debug), against the live schedule: 25 channels,
      **one** episode each — `/schedules/all/now`, not the 50–70 assumed above. The lookup
      went from 8.8 µs to 0.16 µs; `liveProgram(for:)` from 60 µs to 50 µs. What is left is
      date parsing: `isPlaying` parsed `startTime` and `endTime` on every call, ~25 µs each.
      Now parsed once, when made or decoded (`DRTimestamp`, below P7); `liveProgram(for:)`
      went from 50 µs to 0.6 µs.
- [x] ~~**P7. Hoist the `ISO8601DateFormatter`s.**~~ Done. `startDate`, `endDate` and
      `playedDate` each allocated a new formatter on every access, inside filters over
      whole arrays — and picking the track being heard now runs every second while paused
      behind live. All three go through `DRDate.parse`, one shared formatter
      (`nonisolated(unsafe)`: `ISO8601DateFormatter` is documented thread-safe, which
      Swift cannot see). About 3x faster per parse (20,000: 2.6 s → 0.93 s). Covered by
      `DRDateTests`.
      Then parsed only once: `DRTimestamp` holds DR's string and its date, parsed when the
      programme or track is made or decoded, and encodes as the bare string, so DR's JSON
      and the disk cache are unchanged. `startDate`, `endDate` and `playedDate` are now
      reads. Measured as for P6: `liveProgram(for:)` 50 µs → 0.6 µs,
      `getCurrentProgram(for:)` 51 µs → 0.9 µs. Covered by `DRTimestampTests`.
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
- [x] ~~**P12. Cache `MarqueeText` measurements.**~~ Moot after F11b: the measuring
      functions were estimates that ignored the font, and are gone. `MarqueeText` now reads
      the real rendered size once per layout, from a hidden copy of its text.

### P2

- [x] ~~**P13. Version and age-check the disk cache.**~~ Done. F42 made the disk cache what
      an offline launch shows, which made its two gaps matter:
      - **Version.** The file is now a `Snapshot` (schema version, when it was saved, the
        schedules). One from another version is discarded and logged rather than failing to
        decode in silence. The bare array written before the version existed still loads,
        as version 1 dated by the file, so updating does not empty every install's cache.
        "Permanently" in the original note was too strong: the next successful fetch
        overwrites the file. The cost was an offline launch with nothing to show.
      - **Age.** A snapshot over 7 days old is not loaded.
      - **Not presented as live.** That was mostly not the cache's doing: `liveProgram(for:)`
        fell back to the channel's first cached programme, ended or not, so a day-old cache —
        or an hour of DR not answering — showed finished programmes as on air on every card,
        the player, the lock screen, and as the sleep timer's end. It now returns only a
        programme on air, or one DR gave no times for. The schedule is refetched as
        programmes end (just after the soonest end, between 1 and 10 minutes), while the app
        is in front or playing; before, it was refetched only every 5 minutes while playing,
        so Home kept showing what was on when it opened.
      Covered by `DiskCacheTests` and `ScheduleFreshnessTests`.
- [x] ~~**P14. Share the cache with the Top Shelf extension**~~ Done. The
      `group.com.eopio.lytter` app group is back, in `lytter.entitlements` and a new
      `TopShelfExtension.entitlements`. On tvOS, `DRLocalCache` now writes its snapshot to
      the group container's `Library/Caches` (moving the file an earlier version left in the
      app's own caches, once) and calls `TVTopShelfContentProvider.topShelfContentDidChange()`
      after each save. The extension's new `TopShelfSharedCache` decodes the same file —
      `/schedules/all/now` is exactly what both were fetching — and uses it without a request
      while it is under an hour old; past that it fetches as before, and if DR cannot be
      reached it falls back to any snapshot within the cache's seven days before the five
      bundled channels. The extension cannot see `DRLocalCache`, so the group, file name,
      schema version and maximum age are duplicated; `DiskCacheTests` pins them and decodes
      a saved file the way the extension does. Verified on the tvOS simulator with lytter
      moved into the top row: HeadBoard re-asks every 600 s, and the extension logged
      "using the app's cache, 41 s old", then "12 s old" on the redraw the app's save
      requested. iOS and macOS carry the entitlement but do not read the group.
      Measured against `main` on the same simulator, five refreshes each: `main` made one
      request per refresh (55 KB) and HeadBoard's fetch took 157–169 ms; now none, and
      105–109 ms. The time is measured on a Mac whose round trip to DR is 60–150 ms, so on
      an Apple TV the difference should be larger; offline, the old extension could wait
      out its 60 s timeout before showing the bundled channels.
- [x] ~~**P15. Make channel ordering deterministic.**~~ Done in #18, and smaller than
      recorded: `loadChannels` and `loadDiskCache` both already sort by title afterwards.
      The one that actually surfaced was `Array.uniqued()`, which was `Array(Set(self))` —
      so the district list under P4 and P5 came out in a different order on every launch.
      It is order-preserving now. `GroupedChannel.init` also sorts, since it takes its id
      and name from `channels.first` and `Dictionary(grouping:)` does not define that
      order.
- [x] ~~**P16. Move disk-cache encoding off the hot path.**~~ Done. `DRLocalCache.save`
      now returns at once: it cancels any save still waiting, and a detached
      background-priority task sleeps for `writeDelay` (1 s), then encodes the snapshot and
      writes it — and on tvOS asks the Top Shelf to redraw — off the main actor. Back-to-back
      fetches (launch, a retry, the network coming back) write once. For the encode to run
      there, the types the snapshot holds — `DREpisode`, `DRChannel`, `DRSeries`,
      `DRAudioAsset`, `DRImageAsset`, `DRTimestamp` and the `Snapshot` itself — are
      `nonisolated` against the project's main-actor default. `save` returns its task so
      `DiskCacheTests` can wait for the write; `aSaveThatIsReplacedIsNeverWritten` covers the
      debounce, and fails with the cancel removed. Verified on the tvOS simulator: from no
      cache file, launch wrote the group container's snapshot (25 schedules) and Home showed
      the channels. The cost of the delay: a fetch the app is killed within a second of
      finishing is not cached, and the next launch shows the one before.
      Measured against `main` on the tvOS simulator, Release builds, eight launches each,
      alternated, timing the `save` call in `fetchCatalogue` on live data (25 schedules,
      54 KB): `main` held the main actor for a median 1.29 ms (1.0–3.8 ms); now 5.7 µs
      (4.5–6.5 µs), about 225× less. The encode and write still cost a median 5.8 ms
      (3.4–6.7 ms), now off the main thread at background priority, which is why it takes
      longer than it did on the main actor. On an Apple TV both main-actor figures should be
      higher; the debounce did not come into it, since a launch fetches once.

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
