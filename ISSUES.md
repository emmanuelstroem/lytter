# Lytter — Known Issues

_Gathered 2026-10-10 from `main` at `c848260`. A full run of the unit and UI tests on
every supported device type (below), plus what turned up while fixing the full player on
small iPhones (#105, #106). Features, security and performance work live in
[docs/ROADMAP.md](docs/ROADMAP.md); this file is for what is broken._

Each entry is one of:

- **Bug**: the app does the wrong thing.
- **Test**: the app is fine; a test assumes something that is not true on that device.
- **Tooling**: something stops the tests running at all.
- **Investigate**: a test fails and the cause is not yet pinned down.
- **Decide**: behaviour that may be intended; needs a call before it is fixed or closed.

---

## Fix one device, test them all

A fix for one device type has to be tested on every device type the app supports, because
most of the views are shared. #106 changed how the full player divides its height to give
the iPhone SE its artwork back, and that same view draws the player on every iPhone, every
iPad and on Vision Pro. A fix is done when the matrix below has run and nothing that passed
before fails.

### The matrix

The smallest and largest of each kind, and the oldest OS that has a simulator runtime installed:

| Device | OS | Why |
| --- | --- | --- |
| iPhone SE (3rd generation) | iOS 26.5 | Smallest iPhone screen, 375×667. Not created by default: `xcrun simctl create "iPhone SE (3rd generation)" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-26-5` |
| iPhone 17e | iOS 26.5 | The standard iPhone size |
| iPhone 17 Pro Max | iOS 26.5 | Largest iPhone screen |
| iPhone 16e | iOS 18.5 | Oldest iOS with a runtime here; tests cannot run on it yet (B13) |
| iPad mini (A17 Pro) | iOS 26.5 | Smallest iPad |
| iPad Pro 13-inch (M5) | iOS 26.5 | Largest iPad |
| My Mac | macOS 26 | |
| Apple TV 4K (3rd generation) (at 1080p) | tvOS 26.5 | |
| Apple TV 4K (3rd generation) (at 1080p) | tvOS 18.5 | Oldest tvOS with a runtime here |
| Apple Vision Pro | visionOS 26.5 | |

No iOS 17 or tvOS 17 runtime is installed, so the oldest supported versions (iOS 17.6,
tvOS 17.6, macOS 14.6) go untested.

### Running it

Build once per platform, then test each device from that build. Give every run a time
limit and its own log and result bundle: `xcodebuild test` sometimes hangs after the last
test (AGENTS.md), and the result bundle keeps a screenshot and UI hierarchy for every failure.

```
xcodebuild build-for-testing -scheme lytter -destination 'generic/platform=iOS Simulator'
xcodebuild test-without-building -scheme lytter -parallel-testing-enabled NO \
  -destination 'platform=iOS Simulator,name=iPhone 17e,OS=26.5' \
  -resultBundlePath results/iphone-17e.xcresult > results/iphone-17e.log 2>&1
```

Repeat the second command for each iOS device, then do the same with
`generic/platform=tvOS Simulator`, `generic/platform=visionOS Simulator` and
`platform=macOS`. `xcrun xcresulttool export attachments --path <bundle> --output-path <dir>`
pulls out the failure screenshots.

### Baseline, 2026-10-10

The unit tests are Swift Testing, so they report separately from the XCTest UI tests.

| Device | Unit tests | UI tests | Failing |
| --- | --- | --- | --- |
| iPhone SE, iOS 26.5 | 386 passed | 36 of 38 | Region picker (B2) |
| iPhone 17e, iOS 26.5 | 386 passed | 38 of 38 | — |
| iPhone 17 Pro Max, iOS 26.5 | 386 passed | 37 of 38 | Broadcaster reordering (B14) |
| iPhone 16e, iOS 18.5 | could not run | could not run | B13. The app launches and Home draws correctly |
| iPad mini, iOS 26.5 | 386 passed | 18 of 37 | B4–B7 |
| iPad Pro 13-inch, iOS 26.5 | 386 passed | 18 of 37 | B4–B7 |
| Mac, macOS 26 | 384 passed | did not start | B8 |
| Apple TV, tvOS 26.5 | — | 27 of 27 | — |
| Apple TV, tvOS 18.5 | — | 24 of 27 | Schedule focus (B10) |
| Vision Pro, visionOS 26.5 | 376 passed | 11 of 15 | Launch test screenshot (B12) |

The unit-test target is not built for tvOS, so Apple TV runs only the UI tests.

---

## iPhone, small screens (SE, mini)

- [x] **B1. The connection banner covers the grab handle at the largest text sizes. Bug.**
      On an iPhone SE at Accessibility XL, with the banner up (offline, or the stream
      failed), the full player has more content than height. The rows below the artwork
      are centred in the space they are given, so they spill upwards past the 40pt top
      inset, and the banner's top edge runs over the sheet's grab handle. The artwork
      shrinks to nothing first, which is right (text before artwork). Seen while fixing
      #106: it was there before that change too, and #106 made it smaller (the old layout
      also pushed the actions row off the bottom of the screen). A likely fix is to let the
      player scroll when it does not fit, and keep it fixed when it does.
      *Fixed:* the player scrolls when it does not fit and stays put when it does
      (`PlayerOverflowUITests`).
- [ ] **B2. The mini player may cover the last rows of Settings. Investigate.**
      `SettingsAndSearchUITests.testChooseRegion` and `testRegionPickerListsEachDistrictOnce`
      fail on the SE alone: the Region picker never opens. In the failure snapshot the
      Region row sits at y 529–564 of 667, under the floating mini player (y ≈ 540–580), so
      the tap most likely lands on the mini player. Check whether Settings' list is inset
      for the mini player on every iPhone. If it is, the bug is in the test, which stops
      scrolling while the row is still under the bar.

## iPhone, all sizes

- [x] **B3. At accessibility text sizes the connection banner breaks its words. Bug.**
      The banner is one row (icon, text, Try Again), and at Accessibility XL the row is
      too narrow for it: the title truncates to "Could…" and the button wraps mid-word,
      "Try Agai / n". Seen in the full player on the SE; the same view
      (`ConnectionBanner` in `lytter/shared/views/ConnectionStatusView.swift`) is used on
      Home, so it is likely there too, and on wider phones at the largest sizes. Stack the
      button under the text at accessibility sizes (`dynamicTypeSize.isAccessibilitySize`,
      or `ViewThatFits`).
      *Fixed:* at accessibility sizes Try Again sits under the text, in its column
      (`ConnectionBannerDynamicTypeUITests`).

## iPad

The app itself passed every check that reached it. Every failure on iPad is a test that
was written against the iPhone's layout, which leaves the iPad with almost no UI coverage.

- [ ] **B4. Sixteen UI tests look for a tab bar the iPad does not have. Test.**
      `BroadcastersUITests`, `SettingsAndSearchUITests` and `AccessibilityAuditUITests`
      reach Settings and Search through `app.tabBars.buttons[…]`. On iPad with iOS 26 the
      tabs sit at the top of the window, not in a bar at the bottom, and the query finds
      nothing. Reach tabs with a query that works on both, such as `app.buttons["Settings"]`
      inside the tab container, or a helper that knows each idiom.
- [ ] **B5. `PlayerDynamicTypeUITests` opens the player and then closes it. Test.**
      It finds the station card with `label BEGINSWITH 'P1'`, which also matches the
      mini player once a station has been restored. Then it taps the mini player again to
      open the player. On iPhone the sheet covers the mini player, so the second tap is
      harmless. On iPad the player is a centred sheet, the mini player stays exposed, and
      the second tap lands outside the sheet and dismisses it. Exclude the mini player, as
      the newer player tests do (`AND identifier != 'miniPlayer'`).
- [ ] **B6. `PlayerLongTitlesUITests` checks the margin of the window, not the sheet. Test.**
      The margin it reads for stray text is the strip from the window's edge to the
      title's column. On iPhone that is the player's margin; on iPad it is a strip of Home,
      dimmed behind the sheet, with Home's own text in it. Measure from the sheet's edge,
      or run the check on iPhone only.
- [ ] **B7. `BroadcastersUITests` checks the order of stations by height alone. Test.**
      `testABroadcastersChipListsEachStationOnceInOrder` asserts each station sits lower
      than the one before it. iPad's wider grid puts P1 and P2 on the same row, so P1 is
      not "above" P2 (288 = 288). Compare reading order: row first, then column.

## Mac

- [ ] **B8. The UI tests cannot start on this Mac. Tooling.**
      The runner fails with *Timed out while enabling automation mode*. macOS needs
      automation mode approved once for UI testing:
      `automationmodetool enable-automationmode-without-authentication`, which asks for an
      administrator's password, or accept the prompt when Xcode shows it. The unit tests ran
      and passed.
- [ ] **B9. Long titles truncate in the player bar. Decide.**
      `macOSPlayerBar` shows the station and the programme on single lines that end in an
      ellipsis. The iPhone and iPad players scroll them since #105. A resizable window
      usually has the room, so this may be intended; decide, and either close it or use
      `MarqueeText` here too.

## Apple TV

- [ ] **B10. On tvOS 18, the schedule opens on the first programme. Bug.**
      The schedule sheet should open with the programme on air in focus. On tvOS 18.5 it
      opens on the day's first programme: three `TVScrollingUITests` fail
      (`testScheduleScrolls`, `testScheduleRowPinsItsShow`,
      `testScheduleCatchUpRowPlaysTheRecording`; *focus is on 1.03, Fixture-program 1*).
      All three pass on tvOS 26.5. The app supports tvOS 17.6 and up, so the initial
      focus or scroll position needs a path that works before tvOS 26.
- [ ] **B11. Long track titles truncate on Now Playing. Decide.**
      `tvOSNowPlayingView` sets the track on one line. A television is wide, and a marquee
      there would need focus to scroll (AGENTS.md), so this may be intended.

## Vision Pro

- [ ] **B12. The launch test fails on screenshots. Test.**
      `lytterUITestsLaunchTests.testLaunch` takes a screenshot, and the visionOS simulator
      cannot (*remote interface does not have this capability*). It fails once for each of
      its four launch configurations. Skip the screenshot on visionOS. `VisionLaunchUITests`
      all pass.

## Every platform

- [ ] **B13. No test can run on the older systems the app supports. Tooling.**
      The app supports iOS 17.6 and macOS 14.6, but `lytterTests` and `lytterUITests` are
      set to iOS 26.0 and macOS 26.0, so xcodebuild refuses to run them on anything older
      (*iOS Simulator 18.5 doesn't match lytterTests's iOS Simulator 26.0 deployment
      target*). Nothing has tested iOS 17–18 or macOS 14–15 automatically. Lower the test
      targets to match the app, then fix whatever then fails to compile against the older
      SDK. Checked by hand on iOS 18.5: the app launches, and Home draws as on iOS 26.
- [ ] **B14. `testReorderingChangesHome` does not wait for the drop. Test.**
      It drags Testradio above DR in Settings, then goes straight to Home. On the 17 Pro
      Max its own screenshot shows the drag still in flight, Testradio lifted over DR, and
      Home is then in the old order. It passed on the SE and the 17e. Wait for Settings to
      show the new order before leaving it.

Tracked in [docs/ROADMAP.md](docs/ROADMAP.md) rather than here: no CI (nothing runs these
tests but a person), the orphaned `AppIcon Watch.appiconset`, and an API retirement
going unnoticed (F49).
