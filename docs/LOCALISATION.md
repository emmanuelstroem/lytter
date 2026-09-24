# Localisation

The app ships **English** (source) and **Danish**. Adding a third language is a data change,
not a code change.

Everything lives in one String Catalog: [`lytter/Localizable.xcstrings`](../lytter/Localizable.xcstrings).
It is JSON, so it reviews and merges like source — no `.strings` files, no `Base.lproj`.

## Adding a language

1. **Register the language.** Add its code to `knownRegions` in `lytter.xcodeproj/project.pbxproj`
   (next to `en` and `da`), or add it in Xcode under *Project → Info → Localizations*.
2. **Translate.** Open `Localizable.xcstrings` in Xcode, pick the new language, and fill in
   the entries. Or edit the JSON directly — each key looks like:

   ```json
   "Today's schedule" : {
     "extractionState" : "manual",
     "localizations" : {
       "da" : { "stringUnit" : { "state" : "translated", "value" : "Dagens sendeplan" } }
     }
   }
   ```

   Keys **are** the English text. A key with no entry for a language falls back to the key
   itself, so a partial translation is safe to ship — verified by running with
   `-AppleLanguages (de)`, which has no translations and renders correctly in English.
3. **Build.** The catalog compiles into `<lang>.lproj/Localizable.strings` inside the app.

Nothing else. No code changes, no new files.

## Plurals

Two keys carry plural forms — `%lld districts` and `%lld minutes remaining`. Every language
needs the categories *its own* grammar uses, which are not the same everywhere: English and
Danish need `one` and `other`; Polish needs `one`, `few`, `many`, `other`; Japanese needs only
`other`. Xcode's editor offers the right set once the language is added.

```json
"%lld districts" : {
  "localizations" : {
    "da" : { "variations" : { "plural" : {
      "one"   : { "stringUnit" : { "state" : "translated", "value" : "%lld distrikt" } },
      "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld distrikter" } }
    } } }
  }
}
```

## Writing localisable code

- `Text("…")`, `Button("…")`, `navigationTitle("…")`, `.accessibilityLabel("…")` and friends
  take a `LocalizedStringKey`. A **literal** there is picked up automatically.
- A value assembled into a Swift `String` is **not**. Use `String(localized:)`:

  ```swift
  parts.append(String(localized: "\(count) districts"))
  ```

  This is the trap. `Text(someString)` compiles, runs, and silently never translates.
- Text that genuinely should not be translated — a composition like `"\(title) - \(programme)"`
  — takes `Text(verbatim:)`, which says so and keeps it out of the catalog.
- Dates, times and durations must go through `formatted(…)` or `Duration.formatted(…)`, never
  hand-built strings. They then follow the reader's locale on their own.

The compiler extracts every key on each build (`SWIFT_EMIT_LOC_STRINGS`). To see the current
list without opening Xcode:

```bash
find ~/Library/Developer/Xcode/DerivedData/lytter-*/Build -path "*Debug-iphonesimulator*" \
     -name "*.stringsdata" -exec plutil -p {} \; | grep '"key"'
```

## Two deliberate exceptions

- **The 401 error message** is not localised. It names a build setting and tells the reader to
  edit source; anyone who can act on it reads English, and translating it would only make the
  symbol harder to find.
- **`STRING_CATALOG_GENERATE_SYMBOLS` is `NO`.** Xcode 16 generates a Swift symbol per key and
  rejects keys differing only in case — this app legitimately has both `LIVE` and `Live`, and
  both `Siri & Shortcuts` and `Siri Shortcuts`. Nothing here uses the generated symbols, so the
  codegen went rather than the wording.

## Danish translations need a native review

They were written alongside the code rather than by a translator. The mechanism is verified;
the *wording* is not. Worth a pass by a Danish speaker before release — particularly the Siri
and Shortcuts strings, which should match Apple's own Danish terms (the Shortcuts app is
*Genveje*).
