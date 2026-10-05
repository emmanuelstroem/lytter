# Lytter — Status, Plan & Todo

_Last updated: 2026-10-04. Completed entries have been removed; their write-ups live in the
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
F18 (widgets, Live Activity) → F21 (CarPlay) → F33 (favourite shows)
→ F19 (iPhone Duo).

**Housekeeping, whenever it is cheap**
S15 (default main-actor isolation) → P17 (brand-asset size).
