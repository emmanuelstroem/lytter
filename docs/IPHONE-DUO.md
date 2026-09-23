# iPhone Duo support — notes & adoption plan

_Captured 2026-09-23 for later implementation. Source: Apple HIG,_
_[Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)_
_(new page, 9 Sept 2026) and_
_[Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)._

---

## 1. What iPhone Duo is

A book-style folding iPhone with **two displays**, each with its own front-facing camera,
joined by a **centre hinge**.

- **Outer display** — what you use when the device is closed. It is **wider and shorter**
  than a normal iPhone, so **the system moves toolbars, tab bars and navigation controls
  to the side (a vertical axis)** to preserve vertical space for content.
- **Inner display** — the large display when open. Controls **stay on the side in
  landscape** to keep continuity with the outer display; **in portrait there is enough
  vertical space, so standard horizontal bars return**.
- **Poses** — closed, fully open, partially folded like a book, laid flat, stood on edge,
  in either orientation, plus Split View multitasking on the inner display.

Apple's framing: *"you're still designing for iPhone"*. There is no separate layout per
pose. **Size classes carry it**: compact width ≈ outer display, regular width ≈ inner
display. An app that already resizes well mostly adapts for free.

### Reserved regions

Beyond normal safe areas, three regions content must avoid:

| Region | When active |
|---|---|
| Outer front camera | Always. Expands into the Dynamic Island for Live Activities. |
| Inner front camera | Only while the camera is in use — the UI moves aside to reveal it. |
| **The fold** | Only when the device is partially folded. Divides the inner display into two usable regions with a dead zone at the centre. Width is **zero when flat**. |

System components (alerts, sheets, context menus, split views) adapt automatically.
Custom layouts query them via `ReservedRegion`.

---

## 2. Where Lytter stands today

Honest assessment: **not adaptive at all.** Nothing would crash, but the outer display and
the partially-folded pose would both look wrong.

| Signal | Count in the codebase |
|---|---|
| `horizontalSizeClass` / `verticalSizeClass` | **0** |
| Deprecated `NavigationView` | **7** (`HomeView`, `iOSRadioView`, `ChannelView`, `ShortcutsView` ×2, `iOSFullPlayerSheet` ×2) |
| `NavigationStack` / `NavigationSplitView` | **0** |
| Hardcoded `.frame(width: <number>)` | **~30** |
| `.padding(.bottom, 100) // Space for bottom tab bar` | **3** |
| `UIDevice.userInterfaceIdiom` / `UIScreen.main` / `UIInterfaceOrientation` | **0** ✅ |
| Orientations allowed (iPhone) | portrait + both landscapes ✅ |

Two genuine positives: the app never branches on idiom or screen bounds, and it does not
lock to portrait. Those are the two things that are painful to undo.

### The specific risks

1. **The mini player is a `tabViewBottomAccessory`.** On iOS 26 `ContentView` hosts
   `MiniPlayer` via `.tabViewBottomAccessory` with `.tabBarMinimizeBehavior(.onScrollDown)`.
   When the system moves the tab bar to the **side** on the outer display, what happens to
   a *bottom* accessory is the single most important unknown in this whole adoption. **Test
   this first, before designing anything else.**

2. **`.padding(.bottom, 100)` to clear the tab bar.** Three screens reserve bottom space
   by hand. The moment the bar is vertical this is 100 pt of dead space at the bottom and
   zero clearance at the side. Replace with `safeAreaInset` / layout margins.

3. **`PlayerControlsView` sizes everything off `GeometryReader` fractions** —
   `min(width, height) * 0.8` for the play button, `* 0.3` for skip. On a short, wide outer
   display these collapse; on the inner display they balloon. Use fixed, Dynamic
   Type-relative sizes.

4. **The full player is a `.sheet`.** Sheets move to avoid the fold automatically, but the
   partially-folded pose needs a visual check.

5. **`NavigationView` has no defined behaviour on Duo.** It must go regardless.

---

## 3. The opportunity

The HIG's worked example is Mail: list of emails (primary) on the outer display, list +
message side by side on the inner. **Lytter maps onto that almost exactly:**

```
Outer display (compact)          Inner display (regular)
┌────────────────────┐           ┌──────────────┬──────────────────┐
│ ▌  Channel list    │           │ ▌ Channels   │   Now Playing    │
│ ▌                  │           │ ▌  P1        │   ┌──────────┐   │
│ ▌  P1              │    open   │ ▌  P2        │   │ artwork  │   │
│ ▌  P2         ──────────────▶  │ ▌  P3  ◀──   │   └──────────┘   │
│ ▌  P3              │           │ ▌  P4 Kbh    │   Programme      │
│ ▌  P4 København    │           │ ▌  P5        │   Track          │
│ ▌ ───────────────  │           │ ▌ ─────────  │   ▶  ⏸  AirPlay  │
│ ▌ [mini player]    │           │ ▌            │                  │
└────────────────────┘           └──────────────┴──────────────────┘
 ▲ vertical tab bar               ▲ vertical bar (landscape)
```

A `NavigationSplitView` gives this for free: it expands on the inner display and collapses
to a single pane on the outer, exactly as it already does between regular and compact on
other iPhones. **And the same change fixes iPad**, where the app is currently a stretched
phone layout.

---

## 4. Adoption plan

### Phase 0 — prerequisites (do these anyway)

- [ ] **D1. Replace all 7 `NavigationView` with `NavigationStack`.** Deprecated since
      iOS 16; no defined Duo behaviour. _(Tracked as F12 in the roadmap.)_
- [ ] **D2. Remove the three `.padding(.bottom, 100)` tab-bar hacks.** Use `safeAreaInset`
      or let the system manage the inset.
- [ ] **D3. Replace hardcoded `.frame(width:)` with relative sizing** in the ~30 places
      that use it, especially artwork and the mini player row.
- [ ] **D4. Adopt Dynamic Type.** All typography is hardcoded `.system(size:)` today;
      the HIG asks that text sizes stay as consistent as possible while resizing.
      _(Overlaps with the accessibility work, F11.)_

### Phase 1 — make it adaptive

- [ ] **D5. Introduce `NavigationSplitView`** with the channel list as primary and Now
      Playing as secondary. Collapses to the list on the outer display; both panes on the
      inner. Also fixes iPad.
- [ ] **D6. Drive layout from `horizontalSizeClass`, never from device or screen.**
      Compact = one column, regular = two. Apple explicitly says **do not** use
      `UIDevice.userInterfaceIdiom` or `UIInterfaceOrientation` — the app is already clean
      here, keep it that way.
- [ ] **D7. Resolve the mini player question.** Depends entirely on the D-test below. If
      `tabViewBottomAccessory` degrades on a vertical bar, the fallback is to place the mini
      player as a `safeAreaInset(edge: .bottom)` on the detail column, or promote Now Playing
      into the secondary pane and drop the accessory on regular width.

### Phase 2 — Duo-specific polish

- [ ] **D8. Handle the fold with `ReservedRegion`.**
      ```swift
      GeometryReader { proxy in
          let regions = proxy.reservedRegions(kind: .all, options: .all)
          // keep the play button and artwork out of the fold's division region
          ChannelGrid()
      }
      ```
      Concretely: keep the **play/pause button** and the **now-playing artwork** clear of
      the centre when partially folded, and use an **even number of columns** in the
      channel grid so it divides cleanly.

- [ ] **D9. Consider `ArrangementView` for the player.** The now-playing layout is
      artwork-over-controls — a `ZStack`-shaped relationship, which maps to an
      **overlay arrangement**; a side-by-side artwork/metadata layout maps to a
      **split arrangement**.
      ```swift
      ArrangementView { ArtworkView() } secondary: { ControlsView() }
          .arrangementViewStyle(.split.axes(.horizontal))
      ```
      Keep navigation containers *around* an `ArrangementView`, never inside it.

- [ ] **D10. Prepare toolbar items for the vertical axis.**
      - Give every toolbar item **both a title and a symbol** — vertical bars show the
        symbol, overflow menus show both.
      - Set `visibilityPriority` so AirPlay and play/pause survive compression.
      - Set `axisBehavior` on items that must adapt.
      - Use the system overflow menu (`ToolbarOverflowMenu`) rather than a bespoke one.
      - Read `@Environment(\.toolbarVerticalEdge)` where the layout genuinely needs to know.
      - Choose `ToolbarVerticalCompressionBehavior`: Lytter is **navigation-focused**, so
        the default (compress the toolbar, keep the tab bar) is right.

- [ ] **D11. Avoid extreme rearrangement while folding.** The HIG is explicit: move only
      what must move. The tvOS auto-hide pattern (controls fading after 5 s) should **not**
      be ported to Duo.

- [ ] **D12. Consider `.backgroundExtensionEffect()`** so blurred channel artwork extends
      under the vertical bar instead of stopping at its edge — the same treatment the
      tvOS now-playing background already uses.

### Phase 3 — verification

- [ ] **D13. Build with Xcode 26+** (already on 26.5) and test every pose in **Device Hub**:
      closed → partially folded → fully open → each rotated. Walk the whole app: channel
      list, now playing, full-player sheet, variant overlay, search, settings.
- [ ] **D14. Check Split View multitasking** on the inner display — controls sit on each
      app's *outer* edge, so the leading app has controls on the left. Use safe areas so
      the opposite app's bar never covers Lytter's content.
- [ ] **D15. Verify continuity across the fold.** State, playback and scroll position must
      survive opening and closing. Background audio makes this a strict requirement, not a
      nicety.

---

## 5. Test first, before any design work

> **The one experiment that determines the shape of everything else:** run the current
> build in Device Hub on iPhone Duo, closed, and look at what happens to the
> `tabViewBottomAccessory` mini player when the tab bar goes vertical.
>
> If the accessory survives gracefully → Phase 1 is mostly `NavigationSplitView` + size
> classes and the work is small.
> If it does not → the mini player needs a different home on compact width, and that
> decision cascades through `ContentView`, `MiniPlayer` and the full-player presentation.

---

## 6. API reference

| Need | SwiftUI | UIKit |
|---|---|---|
| Adaptive two-pane | `NavigationSplitView` | `UISplitViewController` |
| Adaptive primary/secondary container | `ArrangementView` + `.arrangementViewStyle(.split/.overlay)` | `UIArrangementViewController` |
| Fold / camera avoidance | `GeometryProxy.reservedRegions(kind:options:)`, `ReservedRegion` | `UIView.reservedRegions(kind:options:)`, `UIView.ReservedRegion` |
| Which edge the bar is on | `@Environment(\.toolbarVerticalEdge)` | `traitCollection.verticalBarEdge` |
| Toolbar priority / adaptation | `.visibilityPriority(_:)`, `.axisBehavior(_:)`, `ToolbarItemGroup` | `UIBarButtonItem.visibilityPriority`, `.axisBehavior`, `UIBarButtonItemGroup` |
| Overflow | `ToolbarOverflowMenu` | `navigationItem.additionalOverflowItems` |
| Bar compression policy | `ToolbarVerticalCompressionBehavior` | `UIVerticalBarCompressionBehavior` |
| Opt a sheet out of vertical bars | `.toolbarVerticalBehavior(.disabled)` | `preferredVerticalBarBehavior = .disabled` |
| Background under a vertical bar | `.backgroundExtensionEffect()` | `UIBackgroundExtensionView` |
| Size adaptation | `horizontalSizeClass`, `verticalSizeClass` | same, via `traitCollection` |
| **Do not use** | `UIDevice.userInterfaceIdiom`, `UIInterfaceOrientation`, screen-derived sizes | — |

### Further reading

- [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) — HIG
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) — developer guide
- [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview) — SwiftUI reference
- [Get Ready for iPhone Duo](https://developer.apple.com/iphone-duo/) — landing page
- Tech Talks: [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) ·
  [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/) ·
  [Strike a pose with adaptive layouts](https://developer.apple.com/videos/play/tech-talks/111463/) ·
  [Leverage multiple displays and scenes](https://developer.apple.com/videos/play/tech-talks/111464/)
