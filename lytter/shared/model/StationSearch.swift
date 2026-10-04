//
//  StationSearch.swift
//  lytter
//

import Foundation

/// Why something answered a search, best reason first.
enum SearchMatch: Int, Comparable {
    /// The station's own name: "P4" means P4, all of it.
    case station
    /// One channel's name or district: "Fyn" means P4 Fyn and P5 Fyn.
    case channel
    /// What is on air there: its title, series, description or categories.
    case programme

    static func < (lhs: SearchMatch, rhs: SearchMatch) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One line of search results: a station or a single channel, and why it is there.
struct SearchHit: Identifiable {
    let group: GroupedChannel
    let match: SearchMatch
    var id: String { group.id }
}

/// What Search lists, on every platform.
///
/// Before anything is typed: every station once, P4 and P5 as single entries rather than ten
/// districts each. Once something is typed, every word has to be found, in any order and
/// ignoring case and accents, in the station's name, a channel's name or district, or what is
/// on air. In a name, anywhere: Danish places are compounds, and "jylland" should find
/// Nordjylland. In a programme, only at the start of a word, or "er" would find every Danish
/// description there is.
///
/// A district answers as the channel it is, so "Fyn" lists P4 Fyn and P5 Fyn to play rather
/// than P4 and P5 to pick a district from all over again. A programme on every one of a
/// station's districts at once answers as the station.
enum StationSearch {

    /// The results for `query`, best first.
    ///
    /// - Parameter programme: what is on air on a channel, as searchable text.
    static func results(for query: String, in channels: [DRChannel],
                        programme: (DRChannel) -> [String] = { _ in [] }) -> [SearchHit] {
        let stations = GroupedChannel.grouped(from: channels)
        let terms = Self.terms(query)
        guard !terms.isEmpty else {
            return stations.map { SearchHit(group: $0, match: .station) }
        }

        let hits = stations.flatMap { hits(in: $0, terms: terms, programme: programme) }
        let folded = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        // Best reason first; then a name that begins with what was typed — "P1" before
        // anything merely containing it; then alphabetical, as the stations are listed.
        return hits.enumerated().sorted { a, b in
            if a.element.match != b.element.match { return a.element.match < b.element.match }
            let aPrefix = fold(a.element.group.displayTitle).hasPrefix(folded)
            let bPrefix = fold(b.element.group.displayTitle).hasPrefix(folded)
            if aPrefix != bPrefix { return aPrefix }
            return a.offset < b.offset
        }.map(\.element)
    }

    private static func hits(in station: GroupedChannel, terms: [String],
                             programme: (DRChannel) -> [String]) -> [SearchHit] {
        if matches(terms, names: [station.name] + station.channels.compactMap(\.stationTitle)) {
            return [SearchHit(group: station, match: .station)]
        }

        var byName: [DRChannel] = []
        var byProgramme: [DRChannel] = []
        for channel in station.channels {
            let names = [channel.displayName, channel.qualifiedName, channel.slug, channel.name]
                + [channel.district].compactMap { $0 }
            if matches(terms, names: names) {
                byName.append(channel)
            } else if matches(terms, names: names, text: programme(channel)) {
                byProgramme.append(channel)
            }
        }

        let single = { (channel: DRChannel) in GroupedChannel(channels: [channel]) }
        var hits = byName.map { SearchHit(group: single($0), match: .channel) }
        if station.hasMultipleDistricts && byProgramme.count == station.channels.count {
            hits.append(SearchHit(group: station, match: .programme))
        } else {
            hits += byProgramme.map { SearchHit(group: single($0), match: .programme) }
        }
        return hits
    }

    // MARK: - Matching

    /// The words of a query, folded.
    static func terms(_ query: String) -> [String] {
        fold(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// Whether every term is found in one of `names`, or begins a word of `text`.
    static func matches(_ terms: [String], names: [String], text: [String] = []) -> Bool {
        let names = names.map(fold)
        let words = text.flatMap { field in
            fold(field).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        }
        return terms.allSatisfy { term in
            if names.contains(where: { $0.contains(term) }) { return true }
            // A term of punctuation alone, the "&" of "Midt & Vest", has no word to begin.
            let bare = term.filter { $0.isLetter || $0.isNumber }
            return !bare.isEmpty && words.contains { $0.hasPrefix(bare) }
        }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

extension DREpisode {
    /// What Search looks at in a programme.
    var searchableText: [String] {
        [title, series?.title, description].compactMap { $0 } + (categories ?? [])
    }
}
