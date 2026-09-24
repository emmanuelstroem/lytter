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
curves are ever adjacent.

**Check it whenever you add a rounded shape inside another.** New views, new sheets, new
cards. It is a design principle for this app, not a one-off fix.

### Radii in use

| Where | Radius |
| --- | --- |
| iOS featured shelf card | 14 |
| iOS standard shelf card | 12 |
| iOS list-row thumbnail | 8 |
| tvOS channel card | 16 |
| tvOS now-playing artwork | 24, badge 12 |
| tvOS panels | 28 |
| Mini-player artwork | 10 |

Prefer `style: .continuous` — it is the curve the system uses, and it is visibly different
from the circular default at larger radii.

## Two things that have bitten this project

**Hierarchical shape styles resolve against the tint.** `.foregroundStyle(.primary)` inside a
`Button` renders blue, not the label colour. Use concrete `Color.primary` outside materials;
hierarchical styles are correct *on* a material, where they give vibrancy.

**A nested `ObservableObject` does not republish through its owner.** Observe
`UserPreferencesService` directly rather than reaching it through `DRServiceManager`, or the
view will not redraw when it changes.

## Conventions

- **Commits and PR descriptions carry no Claude attribution and no co-author line.**
- **Never `git add .`** — stage only the files belonging to the change.
- Verify by running the app, not only by building it. A green build has shipped a crash here
  before.
- Every new test gets a negative control: break it deliberately, watch it fail, restore it.
- Localisation lives in one String Catalog; see [docs/LOCALISATION.md](docs/LOCALISATION.md).
  New user-facing strings need their Danish.
