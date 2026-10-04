//
//  StationSearchTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// What Search lists, against the channel list DR actually serves: every station once before
/// anything is typed, and a single district when the words name one.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct StationSearchTests {

    private func channel(_ title: String) -> DRChannel {
        DRChannel(id: title.lowercased(), title: title, slug: title.lowercased(),
                  type: "Channel", presentationUrl: nil)
    }

    /// Every channel title DR served on 2026-09-24.
    private static let live = [
        "P1", "P2", "P3",
        "P4 Bornholm", "P4 Esbjerg", "P4 Fyn", "P4 København", "P4 Midt & Vest",
        "P4 Nordjylland", "P4 Sjælland", "P4 Syd", "P4 Trekanten", "P4 Østjylland",
        "P5 Bornholm", "P5 Esbjerg", "P5 Fyn", "P5 København", "P5 Midt & Vest",
        "P5 Nordjylland", "P5 Sjælland", "P5 Syd", "P5 Trekanten", "P5 Østjylland",
        "P6", "P8"
    ]

    private func hits(_ query: String,
                      onAir: [String: [String]] = [:]) -> [SearchHit] {
        StationSearch.results(for: query, in: Self.live.map(channel)) { onAir[$0.title] ?? [] }
    }

    private func titles(_ query: String, onAir: [String: [String]] = [:]) -> [String] {
        hits(query, onAir: onAir).map(\.group.displayTitle)
    }

    // MARK: - Before anything is typed

    @Test func emptyListsEveryStationOnceWithoutDistricts() {
        #expect(titles("") == ["P1", "P2", "P3", "P4", "P5", "P6", "P8"])
        #expect(titles("   ") == titles(""), "whitespace is not a search")
        #expect(hits("").allSatisfy { $0.match == .station })
    }

    // MARK: - Names

    @Test func aStationNameIsTheWholeStation() {
        #expect(titles("P4") == ["P4"])
        #expect(hits("p4").first?.group.hasMultipleDistricts == true)
    }

    @Test func aDistrictNameListsEachDistrictAsAChannel() {
        #expect(titles("Fyn") == ["P4 - Fyn", "P5 - Fyn"])
        #expect(hits("Fyn").allSatisfy { $0.match == .channel && !$0.group.hasMultipleDistricts })
    }

    /// Words in any order, each beginning a word somewhere.
    @Test func stationAndDistrictTogetherFindOneChannel() {
        #expect(titles("P4 Fyn") == ["P4 - Fyn"])
        #expect(titles("fyn p5") == ["P5 - Fyn"])
        #expect(titles("nord") == ["P4 - Nordjylland", "P5 - Nordjylland"])
        // Danish places are compounds: a name matches anywhere inside it.
        #expect(titles("jylland") == ["P4 - Nordjylland", "P4 - Østjylland",
                                      "P5 - Nordjylland", "P5 - Østjylland"])
    }

    @Test func caseAndAccentsAreIgnored() {
        #expect(titles("sjaelland").isEmpty, "æ is a letter of its own, not an accented a")
        #expect(titles("SJÆLLAND") == ["P4 - Sjælland", "P5 - Sjælland"])
        #expect(titles("midt & vest") == ["P4 - Midt & Vest", "P5 - Midt & Vest"])
    }

    @Test func nothingMatchesNothing() {
        #expect(titles("zzz").isEmpty)
    }

    // MARK: - What is on air

    @Test func aProgrammeFindsItsChannel() {
        let onAir = ["P1": ["Orientering", "Nyheder og baggrund", "News"]]
        #expect(titles("orientering", onAir: onAir) == ["P1"])
        #expect(titles("baggrund", onAir: onAir) == ["P1"], "the description is searched")
        #expect(titles("news", onAir: onAir) == ["P1"], "categories are searched")
        #expect(hits("orientering", onAir: onAir).first?.match == .programme)
        #expect(titles("p1 orientering", onAir: onAir) == ["P1"], "words may span name and programme")
        #expect(titles("heder", onAir: onAir).isEmpty, "inside a programme, words match from their start")
        #expect(titles("ntering", onAir: onAir).isEmpty)
    }

    /// A regional programme is on one district; a national one is on all of them at once.
    @Test func aProgrammeOnSomeDistrictsListsThoseDistricts() {
        let regional = ["P4 Fyn": ["Morgen på Fyn"]]
        #expect(titles("morgen", onAir: regional) == ["P4 - Fyn"])

        let national = Dictionary(uniqueKeysWithValues: Self.live
            .filter { $0.hasPrefix("P4 ") }.map { ($0, ["Formiddag"]) })
        let found = hits("formiddag", onAir: national)
        #expect(found.map(\.group.displayTitle) == ["P4"])
        #expect(found.first?.group.hasMultipleDistricts == true)
    }

    // MARK: - Order

    @Test func namesComeBeforeProgrammes() {
        // "Fyn" names two districts, and P1 is airing something about Fyn.
        let onAir = ["P1": ["Fynske fortællinger"]]
        #expect(hits("fyn", onAir: onAir).map(\.match) == [.channel, .channel, .programme])
    }
}
