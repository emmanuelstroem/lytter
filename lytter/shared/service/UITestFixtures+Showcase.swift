//
//  UITestFixtures+Showcase.swift
//  lytter
//

import Foundation

#if DEBUG
/// The App Store screenshots' data: the fixtures with programmes a listener would recognise
/// as radio, in place of "Fixture-program 16".
///
/// Every title, description, artist and track is invented, generic Danish, and none is a
/// DR programme's: the screenshots show what Lytter does, not a claim about what DR airs.
/// No artwork either, so every tile is its station's name on its colour. P1 to P6 only:
/// see `channels`.
///
/// Switched on by `LYTTER_UITEST_SHOWCASE`, beside `LYTTER_UITEST_FIXTURES`. Only
/// `AppStoreScreenshotsUITests` and `Tools/export-screenshots.sh` set it; every other test
/// sees the plain fixtures it was written against.
extension UITestFixtures {

    static var isShowcase: Bool {
        isActive && ProcessInfo.processInfo.environment["LYTTER_UITEST_SHOWCASE"] == "1"
    }

    /// A station's programmes, ten of them, which a day's schedule cycles through. The one
    /// at `onAirIndex` is on air now.
    struct ShowcaseStation {
        let programmes: [String]
        let description: String
        /// What is playing now: artist and title. Nil on a talk station.
        let track: (artist: String, title: String)?
    }

    /// Which of a station's programmes is on air: the schedule's sixteenth slot, the one on
    /// air in `schedule(for:)`, is number 15 of the cycle, and 15 % 10 is 5.
    static let showcaseOnAirIndex = 5

    /// P4 and P5 are one entry each for every region: regional radio sounds the same
    /// everywhere, and the region is in the station's name.
    static func showcaseStation(for slug: String) -> ShowcaseStation {
        switch slug {
        case "p1":
            ShowcaseStation(
                programmes: ["Nyheder og analyse", "Videnskab i dag", "Bøger og forfattere",
                             "Verden rundt", "Debatten", "Dagens samtale", "Penge og arbejde",
                             "Historiens time", "Sundhed og krop", "Aftenens nyheder"],
                description: "Ugens gæster i en lang samtale om det, der fylder lige nu. "
                    + "Med nyheder hver halve time.",
                track: nil)
        case "p2":
            ShowcaseStation(
                programmes: ["Klassisk morgen", "Koncertsalen", "Klaverets verden",
                             "Opera i aften", "Korsang", "Klassisk formiddag", "Kammermusik",
                             "Ny musik for orkester", "Symfonien", "Natklassisk"],
                description: "Klassisk musik fra barok til i dag, med historien bag værkerne "
                    + "og musikerne.",
                track: ("Nordlys Strygekvartet", "Strygekvartet nr. 2"))
        case "p3":
            ShowcaseStation(
                programmes: ["Morgen på vej", "Ny musik nu", "Eftermiddagen", "Hjem fra arbejde",
                             "Ugens album", "Hits og hverdag", "Live i studiet", "Aftenhits",
                             "Listen", "Natradio"],
                description: "Ny musik, gode gæster og det, alle taler om.",
                track: ("Ida Holm", "Sommer i byen"))
        case "p6":
            ShowcaseStation(
                programmes: ["Alternativ morgen", "Rock fra kælderen", "Nye albums",
                             "Singer-songwriter", "Elektronisk aften", "Ny indie",
                             "Live-optagelser", "Indie-klassikere", "Ugens opdagelse",
                             "Natlyd"],
                description: "Indie, rock og alternativ musik, med plads til opdagelser.",
                track: ("Faro Lights", "Northern Line"))
        case let slug where slug.hasPrefix("p5"):
            ShowcaseStation(
                programmes: ["Morgenmusik", "Gode gamle hits", "Dansktop", "Eftermiddagsmusik",
                             "Ønsker fra lytterne", "Danske klassikere", "Aftenmusik",
                             "Swing og standards", "Folkemusik", "Natmusik"],
                description: "Musik og minder fra 60'erne, 70'erne og 80'erne.",
                track: ("Bølgerne", "Kom hjem igen"))
        default:
            ShowcaseStation(
                programmes: ["Morgen i regionen", "Musik til frokost", "Eftermiddag i regionen",
                             "Sport i weekenden", "Ønskekoncert", "Formiddag i regionen",
                             "Danske toner", "Aftenradio", "Lokale stemmer", "Nattevagten"],
                description: "Nyheder, trafik og musik fra din egn.",
                track: ("Marie Lund", "Hjem til dig"))
        }
    }

    /// The shows *For you* starts with, in order, as (station, programme number in its
    /// cycle). Each airs on that station, so its card says when.
    static let showcaseFavouriteShows: [(slug: String, index: Int)] = [
        ("p1", 5), ("p3", 6), ("p6", 8), ("p2", 1), ("p4københavn", 4),
    ]

    /// A programme's series, so favourite shows find their airings. In the station's own
    /// namespace: P1's fifth programme is not P3's.
    static func showcaseSeries(_ index: Int, slug: String) -> DRSeries {
        let title = showcaseStation(for: slug).programmes[index % 10]
        return DRSeries(id: showcaseSeriesID(index, slug: slug), title: title,
                        slug: "showcase-\(slug)-\(index % 10)", type: "Series",
                        isAvailableOnDemand: true, presentationUrl: nil, learnId: "")
    }

    static func showcaseSeriesID(_ index: Int, slug: String) -> String {
        "urn:fixture:series:\(slug):\(index % 10)"
    }

    /// What every showcase stream plays: twenty minutes of silence, written on first use,
    /// longer than any screenshot run. The
    /// plain fixtures' address has nothing behind it, so playback fails there, and the
    /// screenshots would show "Could not play P3".
    static let showcaseStreamURL: String = {
        let url = FileManager.default.temporaryDirectory
            // Its length in its name: a file left by a build that wrote a shorter one is
            // not this one.
            .appendingPathComponent("lytter-showcase-silence-20min.wav")
        if !FileManager.default.fileExists(atPath: url.path) {
            // 8-bit mono PCM at 8 kHz, where silence is 128.
            let rate = 8_000, samples = rate * 20 * 60
            var wav = Data()
            func append(_ text: String) { wav.append(Data(text.utf8)) }
            func append32(_ value: Int) {
                withUnsafeBytes(of: UInt32(value).littleEndian) { wav.append(contentsOf: $0) }
            }
            func append16(_ value: Int) {
                withUnsafeBytes(of: UInt16(value).littleEndian) { wav.append(contentsOf: $0) }
            }
            append("RIFF"); append32(36 + samples); append("WAVE")
            append("fmt "); append32(16); append16(1); append16(1)
            append32(rate); append32(rate); append16(1); append16(8)
            append("data"); append32(samples)
            wav.append(Data(repeating: 128, count: samples))
            try? wav.write(to: url)
        }
        return url.absoluteString
    }()
}
#endif
