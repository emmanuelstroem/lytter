# Lytter — Status, Plan & Todo

_Last updated: 2026-10-06. Completed entries have been removed; their write-ups live in the
pull requests that closed them and in this file's git history._
_Companion docs: [OVERVIEW-AND-ARCHITECTURE.md](OVERVIEW-AND-ARCHITECTURE.md) · [IPHONE-DUO.md](IPHONE-DUO.md)_

---

## 1. Where the project stands

Live DR radio on iOS, iPadOS, tvOS and macOS, with Top Shelf, widgets on iPhone
and iPad, CarPlay (in the simulator
until Apple grants the entitlement; F21), search, favourites, recently played, a schedule,
a sleep timer, Siri and Shortcuts, SharePlay, Danish localisation and an accessibility
pass. The build is warning-free under Swift 6 on all three SDKs, with unit
tests and tvOS UI tests.

What is left is listed below. Three gaps are not entries of their own:

- **No CI.** There is no `.github` directory; builds and tests run only by hand.
- **The API can be retired under the app again.** DR retired v4 before 2026-09-23 and the
  app stopped working; nothing detected it. F49 covers both the fix and the detection.
- **An orphaned `AppIcon Watch.appiconset`** with no watch target. Delete it or build one.

---

## 2. Todo — Feature

### P1 — quality of the core experience

- [ ] **F52. The next seven days from DR's guide page — only once S11 allows it.**
      Favourite shows (F33) say when a show is next on from today's real schedule and a
      weekly template the app learns on the device, which predicts a slot once it has
      repeated in two of the last three weeks. DR's own guide would do better: reading
      `www.dr.dk/lyd/oversigt/{yyyy-MM-dd}` on the device is technically straightforward,
      but it is reading DR's website rather than their API, so it ships only if S11 finds
      DR's terms permit it.
      - *What the template learns from today.* Checked 2026-10-05 while building F33:
        keyless, even today's `schedules/{slug}/{date}` 401s for most P4 and P5 districts
        (`p4kbh` 401 where `p1`, `p3` and `p6beat` answered 200) — the same cache effect as
        other dates. Those channels fall back to the snapshot, which runs from the
        programme before the one on air to the end of the day: nearly the whole day from
        the 05:05 background refresh, only the rest of it from a refresh in the afternoon.
        The guide page has every channel's whole day either way.
      - *How.* Each date's page embeds the full day for all 25 channels as JSON in
        `<script id="__NEXT_DATA__">`, at `props.pageProps.schedules`: one entry per
        channel with `channel`, `items` and `scheduleDate`, in nearly the shape
        `DRScheduleResponse` already decodes (items carry `hasAudioAssets` rather than
        `audioAssets`). Find the tag, decode the JSON, never pick at the HTML. Pages
        exist from seven days back to seven ahead; the next day after that is a 404.
        `www.dr.dk` is HTTPS and already covered by the ATS note in Info.plist.
      - *Why it is better.* It is DR's own plan, so it has the one-offs the template
        gets wrong — next week's *LIGA* on P4, this week's P5 special — and it is useful
        from the first launch instead of after two weeks. Future days carry series titles
        but not episode detail, which is all favourites and reminders need.
      - *Precedence.* Today's real schedule from the API, then the guide page for the
        days ahead, then the template's repeated slots where the guide has nothing. The
        template keeps learning from the API either way, so it is ready when the guide
        is not.
      - *Cost and courtesy.* About 43 KB compressed per day, so ≈300 KB for the week
        ahead; fetched once a day, not once per day ahead each day. The pages are sent
        `cache-control: no-store`, so every request reaches DR's servers: spread each
        device's fetch over a random point in the half hour after 05:05 rather than every
        install at once, and skip it in Low Data Mode.
      - *When it breaks.* The embedded JSON is an implementation detail of DR's Next.js
        site and can disappear in a redesign with no notice, and only a release could
        follow it. So a failure to find or decode it is logged and falls back to the
        template silently — never an error on screen. A unit test decodes a saved page
        as a fixture, which catches decoding mistakes; it cannot catch DR changing the
        site.
- [ ] **F53. Show the channel's logo when Show Images is off.** With the setting off (F43),
      every picture is replaced by `StationArtworkPlaceholder`: the station's colour and name.
      DR's own logos for P1–P8 and DR LYD now sit in `SharedAssets/Logos.xcassets`, compiled
      into the app as well as the widgets (F18), so the placeholder can draw `DRP1Logo` for P1
      and so on, keeping the colour and name only for a channel with no logo. A P4 or P5
      district needs its district beside the logo, as the Favourites widget's tiles have it,
      since every district shares the one logo. The logos are 120-point bitmaps, sized for
      widgets: sharp up to card size on iPhone, but tvOS's larger cards would want them
      re-exported larger from DR's files (see `ChannelLogo` in `FavouritesWidget.swift`).
- [ ] **F14. Add a README.** Nineteen commits and no entry point for a reader.
      Checked 2026-10-04: not started; there is still no README.
- [ ] **F49. Read the DR API version from a file the app fetches, not only from the
      binary.** When DR retired v4 the app stopped working entirely, and only a release
      could fix it. Publish a small JSON file on GitHub Pages
      (`https://emmanuelstroem.github.io/lytter/config.json`, e.g. `{"apiVersion": "v5"}`);
      Pages is HTTPS, so it needs no ATS exception.
      - **The version only, never a URL.** `https://api.dr.dk/radio/` stays in the app and
        the value must match `v` followed by digits. A remote base URL would let whoever
        controls that repository point every install at their own server.
      - **Never on the launch path.** Use the last version that worked, saved on the device,
        falling back to the built-in `DRAPIConfig.apiVersion`. Fetch the file in the
        background with a short timeout and apply it on the next refresh.
      - **On a 401, look again.** That is how `api.dr.dk` says a version is retired; the
        network layer already recognises it. Re-fetch the file and retry once.
      - **One value for the app and the Top Shelf.** `TopShelfNetworkService` keeps its own
        copy of `apiVersion` (the duplication `DRModels.swift` warns about). Both should
        read the version from the app group.
      - **Detect the next retirement.** Nothing noticed the v4 outage; it was found by
        running the app. A scheduled GitHub Actions job that asserts a 200 *and* a
        successful decode of `/schedules/all/now` would, and is the natural place to check
        that the published version still answers.
      What it cannot fix: a new version usually changes the response, and a changed shape
      still needs a release. Remote config covers the case where only the number moves.
      Preferred over having the app probe the next version itself on a 401, because the
      switch then happens when someone has checked the new version decodes.

### P2 — expansion

- [ ] **F18. Widgets on the Mac.** iPhone and iPad have them (2026-10-06): the
      `LytterWidgets` extension draws a Now Playing widget (small and medium, and the Lock
      Screen's rectangular, circular and inline), a Favourites widget (the pinned stations as
      their logos, four or twelve, each a tap from playing) and a Control Centre play/pause from iOS 18.
      All of them read what the app writes into the app group; the extension never asks
      DR. The broadcaster is shown with DR LYD's logo — see S11. No Live Activity: the system's Now Playing already fills the Lock Screen and the
      Dynamic Island for an audio app, and one of the app's own would only double it.
      Remaining: the Mac's desktop and Notification Centre widgets, which need the extension
      built for macOS and the app group's container to be the one the sandboxed app writes.
- [ ] **F19. iPhone Duo support.** See [IPHONE-DUO.md](IPHONE-DUO.md).
      Checked 2026-10-04: not started beyond those notes.
- [ ] **F21. CarPlay — ask Apple for the entitlement.** The CarPlay scene is built
      (2026-10-05): Home (favourites, then recent plays), Stations (P4 and P5 open their
      districts, the region first) and the system's Now Playing. It runs only in the
      simulator's CarPlay window (*I/O → External Displays → CarPlay*), because
      `com.apple.developer.carplay-audio` is granted by Apple on request and automatic
      signing cannot add it, so it sits in `lytter-simulator.entitlements` alone.
      Remaining: request it at developer.apple.com/contact/carplay; once granted, move the
      key into `lytter.entitlements`, delete `lytter-simulator.entitlements` and the
      `CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]` setting, flip
      `deviceEntitlementsDoNotClaimCarPlayYet`, and try it in a car or with Apple's CarPlay
      Simulator app against a phone.

---

## 3. Todo — Security

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
- [ ] **S15. Revisit what default main-actor isolation actually buys.** With
      `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, types are main-actor unless they say
      otherwise — including `InFlightTasks`, whose whole purpose is to be touched from
      several tasks. Its lock is then belt-and-braces rather than load-bearing. Worth
      deciding deliberately which types are nonisolated, rather than inheriting it.
      Checked 2026-10-04: not started. `InFlightTasks` is still main-actor by default.
- [ ] **S11. Document the DR API posture.** The app consumes an undocumented public API,
      hardcodes 24 DR stream URLs, and displays DR-supplied artwork and trademarks. Confirm
      terms of use and attribution requirements before submitting to the App Store.
      The widgets show DR LYD's logo beside each channel (F18), from DR's own logo pack;
      confirm that use is allowed, and on what terms.
      Also settle whether the app may read the radio guide at `www.dr.dk/lyd/oversigt`
      for the week ahead (F52): it is DR's website rather than their API, and F52 waits
      on the answer.
      Checked 2026-10-04: not started.

---

## 4. Todo — Performance

- [ ] **P17. The brand assets are the next-largest thing in history.** Five PNG blobs of
      1–4.5 MB under `lytter/Assets.xcassets/Brand`, re-committed several times while the
      icons were being iterated, are most of the 30 MB that remains. They are real shipped
      assets, so the fix is not deletion — it is checking whether the tvOS layered images
      need to be that large, and not re-committing regenerated variants.
      Checked 2026-10-04: not started. The Top Shelf images are still 4.3 MB (wide @2x),
      3.5 MB, 1.2 MB and 0.9 MB, and the packed history is 58.7 MB.

---

## 5. Suggested sequence

**Before submitting to the App Store**
S11 (DR's terms and attribution) → F14 (README) → CI: GitHub Actions building and testing
iOS, tvOS and macOS → S1, if DR ever asks for a key.

**Resilience**
F49 (API version from GitHub Pages, and a scheduled check that the API still answers).

**Expansion**
F18 (widgets on the Mac) → F21 (CarPlay) → F52 (DR's guide page, if S11 allows it)
→ F19 (iPhone Duo).

**Housekeeping, whenever it is cheap**
S15 (default main-actor isolation) → P17 (brand-asset size).
