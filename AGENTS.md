# Working on lytter

## Concentricity

**Nested rounded shapes share a centre.** When a shape sits inside another and meets its
corner, the inner radius is the outer radius minus the inset between them:

```
inner radius = outer radius − inset
```

A 24-radius card with a badge inset 12 from its edge wants a 12-radius badge. Get this wrong
and the gap between the two curves changes as it goes round the corner — which is what makes
a square-cornered button inside a rounded panel look like a mistake rather than a choice.

Where the inset is large enough that the arithmetic gives something tiny, the answer is a
capsule, not a rectangle. That is why the system's sidebar rows are pills, and why the
district picker's options are `.buttonBorderShape(.capsule)` rather than `.card` buttons.

**It applies to shapes that meet a corner.** A thumbnail inset on all sides of a list row
does not share the row's corner, so it is not governed by this — forcing it to
`16 − 12 = 4` would be applying the letter against the intent. Ask first whether the two
curves are ever adjacent. Home's chips (*For you · All · DR…*) are the same case: capsules
standing free on the page, with no shape around them to share a corner with.

**Check it whenever you add a rounded shape inside another.** New views, new sheets, new
cards. It is a design principle for this app, not a one-off fix.

### Radii in use

| Where | Radius |
| --- | --- |
| iOS featured shelf card | 14 |
| iOS standard shelf card | 12 |
| iOS list-row thumbnail | 8 |
| tvOS featured shelf card | 22 |
| tvOS channel card | 16 |
| macOS featured station card | 10 |
| macOS standard station card | 8 |
| tvOS now-playing artwork | 24, badge 12 |
| tvOS panels | 28 |
| Mini-player artwork | 10 |
| visionOS mini-player ornament | 20 (artwork 10, inset 10 on every side) |
| visionOS full-player panel | 40 — stands free in the window, clear of its corners |
| visionOS cards | the iPhone's (14 featured, 12 standard); the hover highlight takes the card's radius |
| Widget artwork | `ContainerRelativeShape` — the widget's own curve, less the inset |
| Favourites widget tile | 6 (widget ≈ 22, inset 16), the same on every tile |

Prefer `style: .continuous` — it is the curve the system uses, and it is visibly different
from the circular default at larger radii.

## Things that have bitten this project

**Hierarchical shape styles resolve against the tint.** `.foregroundStyle(.primary)` inside a
`Button` renders blue, not the label colour. Use concrete `Color.primary` outside materials;
hierarchical styles are correct *on* a material, where they give vibrancy.

**On tvOS, a list scrolls only if something in it can take focus.** A `ScrollView` or `List`
of plain text looks right and sits still under the remote; the schedule sheet and the info
sheet's description both shipped that way. Every scrolling surface on tvOS has a UI test in
`lytterUITests/TVScrollingUITests.swift` that drives it with remote presses, on fixture data
(`UITestFixtures`), and `TVScrollingCoverageTests` fails if a tvOS file gains a scrolling
container that is not listed against one. Add the test when you add the scroll view. Run them:

```
xcodebuild test -scheme lytter -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation) (at 1080p)' -only-testing:lytterUITests/TVScrollingUITests -parallel-testing-enabled NO
```

**An Icon Composer layer needs a filled shape.** `AppIcon.icon/Assets/*.svg` must use
`fill="black"`, not `fill="none" stroke=…`: the layer's `fill` in `icon.json` colours the
shape's filled area, and with none the radio renders as hairline outlines. Two icon systems
ship — on iOS/macOS 26 the `.icon` wins and the `appiconset` PNGs are only the fallback — so
fixing one does not fix the other. A build passing proves nothing here; render the `.icon`
with `ictool` and look at it, in Default and Dark (`--rendition Dark`). Simulators older
than iOS 26 show the PNG fallback, so they cannot show this class of bug:

```
"/Applications/Xcode-beta.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" AppIcon.icon --export-image --output-file out.png --platform iOS --rendition Default --width 512 --height 512 --scale 1
```

**A nested `ObservableObject` does not republish through its owner.** Observe
`UserPreferencesService` directly rather than reaching it through `DRServiceManager`, or the
view will not redraw when it changes.

**`xcodebuild test` can hang after the tests have finished.** Now and then it never exits —
seen tearing down a simulator clone, on both the unit and the tvOS UI tests — and it looks
exactly like a test that is stuck. Before suspecting the code, check whether every result
was already printed; rerunning the same command usually finishes in under a minute. Run
tests with a time limit, and write the log to a file rather than piping it through a filter
that only flushes at the end.

**On tvOS, XCUITest reports an app that has just left as still in front.** For a moment
after Back exits to the Apple TV home screen, `app.state` is `runningForeground` with nothing
focused, which reads as "stuck on Home" (F35). Take a screenshot before believing it.

## Broadcasters

**A broadcaster's own code lives in its own folder.** Anything that exists only because of
one broadcaster's API goes in `lytter/shared/broadcasters/<id>/` — DR's is `dr/`. Anything
another broadcaster would use too stays in `lytter/shared/`. A broadcaster is a
`BroadcasterSource` in its folder plus one line in `BroadcasterRegistry`; removing one is
deleting both, because the target compiles every file on disk. `DRChannel`, `DREpisode` and
`DRServiceManager` are the exception for now — DR's types, but also the whole app's model
and core service — until F54d renames and splits them.

**Station ids are stored.** Favourites, recently played, widgets and Siri shortcuts keep
them, so a new source's ids must be URNs in its own namespace (`urn:lytter:<id>:…`) and
must never change. A channel with no `broadcasterID` is DR's.

## Conventions

- **Commits and PR descriptions carry no Claude attribution and no co-author line.**
- **Never `git add .`** — stage only the files belonging to the change.
- **No new warnings.** The build is warning-free; keep it so unless a warning is truly
  unavoidable, and then say why. Check a *clean* build on iOS, tvOS and macOS
  (`xcodebuild clean build-for-testing`): an incremental build reports only the files it
  recompiles, and tvOS-only files never appear in an iOS build (S16).
- Verify by running the app, not only by building it. A green build has shipped a crash here
  before.
- Every new test gets a negative control: break it deliberately, watch it fail, restore it.
- Localisation lives in one String Catalog; see [docs/LOCALISATION.md](docs/LOCALISATION.md).
  New user-facing strings need their Danish.
