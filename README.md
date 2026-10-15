# Lytter

A radio app for DR's stations on iPhone, iPad, Mac, Apple TV and Apple Vision Pro: P1, P2,
P3, P6 Beat, P8 Jazz and the P4 and P5 districts, live or caught up, with what is on and the
song playing.

Lytter is an independent app. It is not made or endorsed by DR. Programmes, logos and
artwork belong to DR.

## What Lytter asks DR for

Everything comes from DR's public API at `api.dr.dk/radio/v5`, with artwork from
`asset.dr.dk`. There is no account and no server of Lytter's own in between.

| What | Request | When |
| --- | --- | --- |
| What is on now | `schedules/all/now`, with `channels` | At launch, as programmes end, and at least every 10 minutes, while the app is open or playing |
| The song playing | `indexpoints/live/{channel}` | While a station plays: just after each song ends; with no song playing, after 15 s, 30 s, then once a minute until one starts |
| A station's day | `schedules/snapshot/{channel}`, `schedules/{channel}/{date}` | When its schedule is opened, and once a day for favourite shows (below) |
| Artwork | `asset.dr.dk/drlyd/images/…` | As pictures are shown, then from the device's cache; never with Settings → Show Images off |
| Apple TV's Top Shelf | `schedules/all/now` | When tvOS refreshes the Top Shelf. Its pictures are loaded by tvOS itself |

Measured over one listening hour on 15 October 2026, the playing station and what-is-on
together:

| Listening to | Requests in the hour |
| --- | ---: |
| P1, mostly talk | 70 |
| P3, mostly music | 73 |

### Daily schedules: Settings → Network

Favourite shows say when a show is next on. For that, Lytter learns each station's week:
once per DR broadcast day, from 05:05 Copenhagen time, it fetches the day's schedule. It
does this at launch, on returning to the app, and from a background refresh on iPhone,
iPad and Apple TV. On the Mac it checks once an hour while the app runs.

**Daily Schedules** chooses which stations:

- **All Shows/Channels** (the default): every station, about 50 requests a day. A show
  favourited later already has its usual times.
- **Favourite Shows/Channels**: only your favourite stations and the stations your
  favourite shows are on. That is two requests a day for each, or none with nothing
  favourited. A show favourited on another station starts with no history and has its
  usual times after a week or two.

In Low Data Mode, only the stations your favourite shows are on are fetched, whichever is
chosen.

### How the requests identify themselves

Every request names the app in its **`User-Agent`** header:

```
User-Agent: Lytter/<version> (<platform>; build <build>)
```

For example `Lytter/1.0 (iOS; build 1)`. The platform is `iOS` (iPhone, iPad and CarPlay),
`tvOS`, `macOS` or `visionOS`. The version and build are the app's own, from its bundle. The
app's API and artwork requests send it, and so does the Top Shelf's request to the API. The
pictures tvOS loads for the Top Shelf go out with tvOS's own header. Nothing in it
identifies a person or a device.

The value is built in [`lytter/shared/service/UserAgent.swift`](lytter/shared/service/UserAgent.swift).
The Top Shelf extension, a separate target, builds the same string in
[`TopShelfExtension/TopShelfNetworkService.swift`](TopShelfExtension/TopShelfNetworkService.swift).

## Working on Lytter

- [AGENTS.md](AGENTS.md): the project's working rules.
- [docs/OVERVIEW-AND-ARCHITECTURE.md](docs/OVERVIEW-AND-ARCHITECTURE.md): how the app is put together.
- [docs/ROADMAP.md](docs/ROADMAP.md): what is planned.
- [docs/LOCALISATION.md](docs/LOCALISATION.md): English and Danish, in one String Catalog.
- [docs/APP-STORE.md](docs/APP-STORE.md): the App Store submission.
