# Lytter — Status, Plan & Todo

_Last updated: 2026-10-05. Completed entries have been removed; their write-ups live in the
pull requests that closed them and in this file's git history._
_Companion docs: [OVERVIEW-AND-ARCHITECTURE.md](OVERVIEW-AND-ARCHITECTURE.md) · [IPHONE-DUO.md](IPHONE-DUO.md)_

---

## 1. Where the project stands

Live DR radio on iOS, iPadOS, tvOS and macOS, with Top Shelf, search, favourites, recently
played, a schedule, a sleep timer, Siri and Shortcuts, SharePlay, Danish localisation and an
accessibility pass. The build is warning-free under Swift 6 on all three SDKs, with unit
tests and tvOS UI tests.

What is left is listed below. Three gaps are not entries of their own:

- **No CI.** There is no `.github` directory; builds and tests run only by hand.
- **The API can be retired under the app again.** DR retired v4 before 2026-09-23 and the
  app stopped working; nothing detected it. F49 covers both the fix and the detection.
- **An orphaned `AppIcon Watch.appiconset`** with no watch target. Delete it or build one.

---

## 2. Todo — Feature

### P1 — quality of the core experience

- [ ] **F33. Favourite shows, not just channels.** Store series ids and surface a
      favourited programme with when it is next on. Needs the per-channel schedule snapshot
      that #14 wired up. Deliberately deferred: favourites are channels for now.
      Checked 2026-10-04: not started; favourites are still channels only.
      **Feasible. How far ahead depends on a decision about DR's terms.** Probed 2026-10-05:
      - Every episode carries `series.id` (`urn:dr:radio:series:…`), stable across airings
        — "Sorte tal" airs 07:05 and 22:03 under one id. That is the thing to store.
      - **Without a key**, `schedules/{slug}/{date}` answers reliably only for the current
        broadcast day. Other dates, and `schedules/all/{date}`, come back 200 *sometimes*:
        the same URL fetched three times in a row gave 401, 200, 401. The 200s carry
        `cache-control: public` with a different `max-age` each time — copies held by
        caches in front of the API, filled by dr.dk's keyed requests and handed out without
        checking the key. Building on that would be building on a cache leak that DR can
        close at any time. `series/{id}`, `series/{id}/episodes` and search always 401.
        Keyless, "next on" can only mean *later today*, *earlier today — listen from the
        start* (F16's catch-up) or *not on again today*.
      - **DR has a week each way.** The guide at `dr.dk/lyd/oversigt/{yyyy-MM-dd}` lists
        all 25 channels for seven days back and seven ahead, in the same v5 shape. dr.dk's
        own client calls the same `api.dr.dk/radio/v5` with an `x-apikey` header, which is
        what unlocks other dates. The data exists; it is gated, not missing.
      - **Where to get it, in order of preference:**
        1. *Ask DR for a key* — the honest route, and it belongs with S11 (terms) and S1
           (keeping a key out of source).
        2. *Read the guide page* — no credential; one request per day covers every channel
           (≈43 KB gzipped). But it means parsing a Next.js page's embedded JSON, which can
           change without notice, and dr.dk's robots.txt and terms are part of S11 too.
           Planned below as an optional source, behind S11.
        3. *Lift dr.dk's web key* — no. It is DR's credential for their own site, can be
           rotated at any time (taking the feature down), and is exactly the kind of thing
           S11 has to settle before submission.
        Whatever the source, the today-only API stays the fallback, so the feature degrades
        to *later today* rather than to nothing.
      - **The week repeats, so a template covers most of it keylessly.** Compared slot by
        slot (start time and `series.id`) across three Mondays — 28 Sep, 5 Oct, 12 Oct:
        - *Each channel repeats itself, regions included.* P1, P3 and every P4 district
          were identical between 28 Sep and 5 Oct, all 11 slots. The P4 districts share
          one grid — the regional shows (*P4 Morgen København*, *P4 Morgen Aarhus*) sit in
          the same slots — so they change together, not separately.
        - *The misses are one-offs, not rotation.* P5 on 5 Oct had a special (*Giro 413 –
          80 år*) in two slots; 28 Sep and 12 Oct match each other around it. P4's 12 Oct
          shows three different programmes (*LIGA* in place of *P4 Aften*), and DR's
          future days may themselves still change.
        - *It is the weekday that repeats.* Monday against Tuesday on P1 differs in 24
          slots, so the template is per weekday.
        - Only today's entries have episode detail (title, description); a future day has
          just series titles, which is all a template needs.
      - **So: a weekly schedule, kept on the device, of what repeats.** The app has to keep
        itself current — nothing outside it can correct what a phone or an Apple TV has
        stored — so the schedule is built, kept and refreshed on the device, from the day
        schedules the app fetches itself. Decided 2026-10-05:
        - *Shape.* Per channel, per weekday, per start time (Copenhagen time): series id,
          title, artwork, duration, and the dates it was seen there — the last three weeks
          only. Each day's real schedule is folded into that weekday's slots. Saved in the
          app group beside the disk cache, so a later widget or the Top Shelf could read it.
        - *Only a slot that has repeated is predicted.* A slot predicts a series once that
          series has held it, on that weekday, in two of the last three weeks: *Usually
          Mondays 07:05*. A slot seen once predicts nothing and is shown nowhere. "Two of
          three" rather than "two in a row", so a one-off like the P5 special neither gets
          predicted nor knocks the regular programme out of its slot. Only today's real
          schedule earns *07:05 today*. Channels that do not repeat simply end up with few
          or no predicted slots; no per-channel switch is needed.
        - *Refreshed at 05:05 Copenhagen time.* DR's broadcast day starts at 05:00 (today's
          day runs from 03:00 UTC, i.e. 05:00 CEST); five minutes later the new day is
          there to fetch. Kept as 05:05 in `Europe/Copenhagen`, not as a UTC offset, so it
          follows DR across the change to CET on 25 Oct 2026 — check after that date that
          DR's day then starts at 04:00 UTC. iOS and tvOS will not run an app at an exact
          time, so 05:05 is the `earliestBeginDate` of a `BGAppRefreshTask`, and launch
          and foreground check the date of what is stored: anything fetched before the
          latest 05:05 is stale. macOS has no `BGTaskScheduler`: launch, becoming active,
          and an `NSBackgroundActivityScheduler` while running.
        - *What it fetches.* Today, once per broadcast day, for every channel: about 7 KB
          per channel compressed, so ≈180 KB a day for all 25. All of them, so a show
          favourited on any channel already has its weeks behind it. Spread over the
          refresh rather than 25 requests at once, and skipped on a constrained network
          (Low Data Mode), where only channels with favourite shows are fetched.
        - *The cost.* A fresh install predicts nothing for a show until its slot has
          repeated — at least a week, usually two. Until then the shelf shows today's real
          airings only.
      - **Optional: the next seven days from DR's guide page — only once S11 allows it.**
        Reading `www.dr.dk/lyd/oversigt/{yyyy-MM-dd}` on the device is technically
        straightforward and better than the template, but it is reading DR's website rather
        than their API, so it ships only if S11 finds DR's terms permit it. Until then, the
        template above is the whole of F33.
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
      Plan:
      1. **Model.** `FavouriteShows`, shaped like `Favourites`: ordered, deduplicated,
         persisted in `UserPreferencesService`. Each entry stores the series id, its title,
         and the slugs of the channels it has been seen on. The title is stored, unlike a
         channel's, because nothing in the catalogue can supply it when the show is not on
         today. The channel slugs are what Low Data Mode still fetches.
      2. **Airings.** A `WeeklyTemplate` (pure, `Codable`, unit-testable on fixtures) that
         folds in a day schedule and answers `next(for:after:)` with a confirmed or a
         predicted airing. Today comes from the existing `fetchDaySchedule`, merged with
         the snapshot as the schedule sheets already do, fetched once per channel per
         broadcast day. The order of answers: on now, else later today, else the next
         predicted airing this week, else the last one today (for catch-up).
      3. **Pinning.** "Add Show to Favourites" in the context menu of a schedule-sheet row
         (iOS, tvOS, macOS) and on the full player's programme info. Not on a station card:
         that pins the channel, and two meanings on one button would be confusing.
      4. **Surface.** A "Shows" shelf on Home under Favourites: series artwork, title, and
         one line — *On now on P1*, *22:03 on P1*, *Usually Tuesdays 07:05*, *Earlier
         today · Listen*, *Not on again today*. Tapping plays live, plays the catch-up from its start, or opens the
         channel's schedule sheet. Remove from the shelf's context menu; "Remove All
         Favourite Shows" in Settings beside the channel one.
      5. **Tests.** Unit: `FavouriteShows` order and dedup, `ShowAirings` across the
         05:00 day boundary and repeat airings. A tvOS UI test if the shelf scrolls on tvOS
         (it does; see `TVScrollingCoverageTests`). New strings need their Danish.
      Reminders when a favourite show starts are F51, built on this.
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

- [ ] **F50. Choose the region in Settings.** Settings shows the remembered region and can
      only forget it; the only way to set one is to pick a district on P4 or P5. A new
      listener who wants København everywhere has to find a regional station first.
      Replace the read-only row in `SettingsSections` with a `Picker` of every district,
      plus "Not Chosen":
      - **Listed from the catalogue, not hardcoded.** The union of `districtID`s across
        `availableChannels` (P4's and P5's share an id — that is what `District` is for),
        named as DR writes them, sorted. DR adds and renames districts.
      - **One list, not one per station.** A region only P4 has is still a valid choice;
        P5 then falls back as it does today. Say so in the footer.
      - **A remembered region the catalogue no longer has** stays selected and readable
        rather than silently snapping to "Not Chosen".
      - Same row on iOS, tvOS and macOS, since `SettingsSections` is shared. On tvOS a
        long picker pushes a list that must scroll under the remote — it needs its entry
        in `TVScrollingUITests`.
      - "Forget Region" goes: "Not Chosen" in the picker does the same job.

### P2 — expansion

- [ ] **F51. Remind me when a favourite show starts.** A Settings toggle, off by default,
      that notifies a few minutes before a favourite show (F33) goes on air, with a tap
      that opens the app playing that channel. Depends on F33.
      - **Local notifications, not push.** Real push needs APNs and a server that knows
        every device's favourites and polls DR for them; this app has no server and should
        not grow one for this. `UNUserNotificationCenter` with a calendar trigger does the
        job. Permission is asked when the toggle is first switched on, not at launch; if it
        is refused, the toggle explains and links to the app's notification settings.
      - **What it can promise.** Each pass schedules the coming seven days from F33's
        weekly schedule — today's real airings plus the slots that have repeated — so a
        device that runs the app once a week still rings. Passes run with F33's refresh:
        the 05:05 `BGAppRefreshTask`, launch and returning to the foreground.
      - **Predicted airings ring too, but say so.** With F33's weekly template, a
        reminder for a predicted airing (a *Usually* slot) reads *Sorte
        tal is usually on P1 now*; a real one reads *Sorte tal is on P1 now*. When that
        day's real schedule is fetched, it is confirmed, moved or removed.
      - **Replace, do not accumulate.** Each pass removes the app's pending reminders and
        schedules afresh from today's airings, identified by broadcast id, so a moved
        programme does not ring twice. Stay well under iOS's 64 pending notifications.
      - **Platforms.** iOS, iPadOS and macOS. tvOS supports only badges, so the toggle does
        not appear there. macOS has no `BGTaskScheduler`; schedule on launch and on
        becoming active, and from `NSBackgroundActivityScheduler` while running.
      - **Tests.** The scheduling decision as a pure function of airings, now and lead time
        (unit-tested, with the day boundary); the notification centre behind a protocol so
        the replace-all pass can be checked without the system. Adds the `fetch`
        background mode — exercised, unlike the `remote-notification` mode removed earlier.

- [ ] **F18. Widgets + Live Activity** for the currently playing channel.
      Checked 2026-10-04: not started; no widget extension, no WidgetKit or ActivityKit.
- [ ] **F19. iPhone Duo support.** See [IPHONE-DUO.md](IPHONE-DUO.md).
      Checked 2026-10-04: not started beyond those notes.
- [ ] **F21. CarPlay.** A live-radio app without CarPlay is leaving its best use case unserved.
      Checked 2026-10-04: not started; no CarPlay entitlement or templates.

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
      Also settle whether the app may read the radio guide at `www.dr.dk/lyd/oversigt`
      for the week ahead (F33's optional source): it is DR's website rather than their
      API, and that part of F33 waits on the answer.
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
F50 (region in Settings; small, and useful at once) → F18 (widgets, Live Activity)
→ F21 (CarPlay) → F33 (favourite shows) → F51 (reminders for them) → F19 (iPhone Duo).

**Housekeeping, whenever it is cheap**
S15 (default main-actor isolation) → P17 (brand-asset size).
