# Submitting to the App Store

Everything App Store Connect asks for, in the order it asks, with the answers. Lytter 1.0
goes out on iPhone, iPad, Mac, Apple TV and Apple Vision Pro at once, as one app record:
one bundle ID (`com.eopio.lytter`), so it is one purchase everywhere (universal purchase).

## 0. The blocker: DR's permission

Lytter plays DR's streams and shows DR's programme information and artwork. It uses no
DR logos: each station is its name on DR's colour for it. That DR is free to listen to
does not make it free to redistribute: App Review rejects radio apps under guideline
5.2.3 (and 5.2.1/5.2.2 for third-party trademarks and services) and asks for
"documentary evidence … that you have all necessary rights or permissions". DR has an app
of its own (DR LYD), so a reviewer will notice.

**Do not submit before DR has answered in writing.** The request is drafted in
[§ 9](#9-the-request-to-dr). Their answer goes in App Review Information → Attachment,
and into ROADMAP S11. If DR attaches conditions (wording, a logo, a link), they go into
`AboutSection` and into the store text below before submitting.

Faking or overstating permission can end the developer account. If DR says no, the app
does not ship with DR's content.

## 1. Checklist

- [ ] DR's written permission (§ 0, § 9)
- [ ] Pages live: Settings → Pages → Source **GitHub Actions**, then
      <https://emmanuelstroem.github.io/lytter/privacy.html> and `/support.html` load
- [ ] App record created (§ 2), name reserved
- [ ] Store text in English and Danish (§ 3)
- [ ] Age rating (§ 4), App Privacy (§ 5), content rights (§ 6)
- [ ] Screenshots for all five platforms in both languages (§ 7)
- [ ] Archives for iOS, tvOS, macOS and visionOS uploaded from Xcode Organizer; build
      number (`CURRENT_PROJECT_VERSION`) raised before each new upload
- [ ] App Review notes and attachment (§ 8)
- [ ] A Danish speaker has read the Danish (store text and the app's catalog)

## 2. The app record

| Field | Value |
| --- | --- |
| Platforms | iOS, macOS, tvOS, visionOS |
| Name | Lytter (check it is free; App Store names are unique) |
| Primary language | Danish (the content is Danish; English is the second localisation) |
| Bundle ID | `com.eopio.lytter` |
| SKU | `lytter` |
| Price | Free, no in-app purchases |
| Availability | Every territory, or Denmark only if DR's permission is limited to it |
| Category | Music (secondary: News) |
| Copyright | © 2026 Emmanuel Opio |
| Privacy Policy URL | https://emmanuelstroem.github.io/lytter/privacy.html |
| Support URL | https://emmanuelstroem.github.io/lytter/support.html |
| Marketing URL | https://emmanuelstroem.github.io/lytter/ |

Export compliance is answered in the binary (`ITSAppUsesNonExemptEncryption = NO`): HTTPS
only, which is exempt.

## 3. Store text

Limits: name and subtitle 30 characters, keywords 100, promotional text 170,
description 4000.

**Keywords must not name DR, its stations or DR LYD** (guideline 2.3.7: no other
companies' trademarks or app names in keywords) unless DR's permission covers it.

### Dansk

- **Undertitel:** Dansk radio live
- **Promotional text:** Alle DR's radiokanaler live – med det, der sendes nu og bagefter,
  favoritter, widgets og Siri.
- **Søgeord:** radio,dansk radio,live,nyheder,musik,kanaler,sendeplan,sove-timer,widget,airplay
- **Beskrivelse:**

  Lytter spiller dansk radio live, på iPhone, iPad, Mac, Apple TV og Apple Vision Pro.

  • Alle DR's radiokanaler, også P4's og P5's regionale udsendelser
  • Se, hvad der sendes nu og bagefter, og hele dagens sendeplan
  • Gem dine foretrukne kanaler og programmer, og få en påmindelse, før et program starter
  • Widgets og en knap i Kontrolcenter
  • Siri: sig “Spil P3”, “Stop Lytter om 30 minutter” eller “Hvad sendes der i Lytter?”
  • Sove-timer, der stopper efter et bestemt tidsrum eller efter programmet
  • Lyt sammen med SharePlay, og send lyden videre med AirPlay
  • Top Shelf på Apple TV

  Gratis, uden reklamer og uden konto. Lytter indsamler ingen data.

  Lytter er en uafhængig app. Den er hverken lavet eller godkendt af DR. Programmer,
  logoer og billeder tilhører DR.

### English

- **Subtitle:** Danish radio, live
- **Promotional text:** All of DR's radio stations live, with what's on now and next,
  favourites, widgets and Siri.
- **Keywords:** radio,danish,denmark,live,news,music,stations,schedule,sleep timer,widget,airplay
- **Description:**

  Lytter plays Danish radio live, on iPhone, iPad, Mac, Apple TV and Apple Vision Pro.

  • Every DR radio station, including P4's and P5's regional broadcasts
  • See what's on now and next, and the whole day's schedule
  • Keep your favourite stations and programmes, with a reminder before a programme starts
  • Widgets, and a control in Control Centre
  • Siri: say “Play P3”, “Stop Lytter in 30 minutes” or “What's on Lytter?”
  • A sleep timer that stops after a set time or at the end of the programme
  • Listen together with SharePlay, and send the sound on with AirPlay
  • Top Shelf on Apple TV

  Free, with no ads and no account. Lytter collects no data.

  Lytter is an independent app. It is not made or endorsed by DR. Programmes, logos and
  artwork belong to DR.

Before submitting, check every claim against the build: a feature listed but missing is a
guideline 2.3.1 rejection.

## 4. Age rating

Live radio is broadcast as it happens, so answer for what DR may air, not for the app:

| Question | Answer |
| --- | --- |
| Profanity or crude humour | Infrequent/Mild |
| Mature or suggestive themes | Infrequent/Mild |
| Violence, horror, drugs, gambling, contests | None |
| Medical or wellness topics | None |
| Unrestricted web access | No (the app opens only its own two pages) |
| User-generated content, messaging, chat | No |
| Advertising | No |
| Parental controls, age assurance | No |

## 5. App Privacy

**Data Not Collected.** This matches `lytter/PrivacyInfo.xcprivacy`: no tracking, no
collected data types. The only API declarations are UserDefaults (CA92.1) and file
timestamps for the artwork cache (DDA9.1). Requests to DR's servers carry the device's IP
address, as any web request does; Lytter neither receives nor keeps it, and Apple does not
count that as collection by the developer.

## 6. Content rights

"Does your app contain, show, or access third-party content?" **Yes.** "Do you have all
necessary rights to that content?" Answer **Yes** only once DR's permission is in hand,
and attach it (§ 8).

## 7. Screenshots

Made from fixture data by `Tools/export-screenshots.sh` (PR 4), into a gitignored
`screenshots/<locale>/<display type>/NN-<screen>.png`:

| Folder | App Store Connect slot | Simulator | Pixels |
| --- | --- | --- | --- |
| `iphone-6.9` | iPhone 6.9" | iPhone 17 Pro Max | 1320×2868 |
| `ipad-13` | iPad 13" | iPad Pro 13-inch (M5) | 2064×2752 |
| `apple-tv` | Apple TV | Apple TV 4K (at 1080p) | 1920×1080 |
| `mac` | Mac | window, padded | 2880×1800 |
| `vision-pro` | Apple Vision Pro | Apple Vision Pro | 3840×2160 |

`NN` is the upload order. Locales are `da` and `en-US`; upload each folder to the
matching localisation.

## 8. App Review Information

- **Sign-in required:** No.
- **Contact:** your name, phone and email (App Store Connect asks; Apple does not publish them).
- **Attachment:** DR's written permission.
- **Notes:**

  > Lytter is a free radio player for DR (Danmarks Radio), the Danish public broadcaster.
  > There is no account and no in-app purchase. Content is in Danish; the app's interface
  > is in English and Danish.
  >
  > DR's permission to stream its stations and show their programme information is attached.
  >
  > To try it: tap any station card to play. The mini player opens the full player, with
  > the schedule and the sleep timer. Favourites: long-press a station. Siri: Settings →
  > Siri & Shortcuts → Allow Siri, then say "Play P3". Widgets: add "Lytter" from the
  > widget gallery. Apple TV: the Top Shelf shows what's on once Lytter is in the top row.
  > SharePlay: start playing during a FaceTime call.

## 9. The request to DR

Send through DR's official contact channel (start at dr.dk → Kontakt, or DR's press or
rights department); don't guess an address. Danish first, English below for the record.

**Emne: Tilladelse til at afspille DR's radiokanaler i en uafhængig app**

> Hej
>
> Jeg har udviklet Lytter, en gratis app til iPhone, iPad, Mac, Apple TV og Apple Vision
> Pro, som afspiller DR's radiokanaler live. Den bruger DR's offentlige streams og
> programdata uændret, optager og gemmer intet, viser ingen reklamer og indsamler ingen
> data. I appen og i App Store står der, at Lytter er uafhængig og hverken lavet eller
> godkendt af DR.
>
> Før jeg lægger appen i App Store, vil jeg gerne have DR's skriftlige tilladelse til:
>
> 1. at afspille DR's radiokanaler live i appen,
> 2. at vise programdata og programbilleder. Appen bruger ingen af DR's logoer: hver
>    kanal vises med sit navn i appens egen skrift på kanalens farve, og
> 3. at bruge DR's navn i beskrivelsen i App Store.
>
> Har DR krav til kreditering, ordlyd eller logobrug, retter jeg mig naturligvis efter
> dem. Jeg vil også gerne vide, om appen må læse ugeoversigten på
> www.dr.dk/lyd/oversigt.
>
> Apple kræver dokumentation for tilladelsen, så et svar på mail er nok.
>
> Venlig hilsen
> Emmanuel Opio

**Subject: Permission to play DR's radio stations in an independent app**

> Hello,
>
> I have built Lytter, a free app for iPhone, iPad, Mac, Apple TV and Apple Vision Pro
> that plays DR's radio stations live. It uses DR's public streams and programme data
> unchanged, records and stores nothing, shows no ads and collects no data. The app and
> its App Store page say that Lytter is independent and neither made nor endorsed by DR.
>
> Before publishing it on the App Store, I would like DR's written permission:
>
> 1. to play DR's radio stations live in the app,
> 2. to show programme data and programme artwork. The app uses none of DR's logos: each
>    station is shown as its name, in the app's own type, on the station's colour, and
> 3. to use DR's name in the App Store description.
>
> If DR has requirements for credit, wording or logo use, I will follow them. I would also
> like to know whether the app may read the week's guide at www.dr.dk/lyd/oversigt.
>
> Apple asks for evidence of permission, so a reply by email is enough.
>
> Kind regards,
> Emmanuel Opio
