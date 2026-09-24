//
//  District.swift
//  lytter
//

import Foundation

/// A region a station broadcasts a separate signal for.
///
/// DR sends no district identifier — only a name buried in the channel title, and the same
/// name appears on two stations: "P4 København" and "P5 København". Deriving a stable id
/// from that name is the whole reason this type exists. Without one a region is just a
/// display string, and "the København one" cannot be asked for across stations, so a
/// listener has to choose their own region again on every station that has them.
struct District: Identifiable, Hashable, Sendable, Codable {

    /// Stable across launches and, more importantly, across stations.
    let id: String

    /// As DR writes it. This is what the listener reads.
    let name: String

    init(name: String) {
        self.name = name
        self.id = District.identifier(for: name)
    }

    /// Lowercased, with runs of anything that is not a letter or digit collapsed to a
    /// single hyphen.
    ///
    /// Folded rather than taken verbatim so a stored region survives DR restyling a name:
    /// "Midt & Vest", "Midt og Vest" and "midt-vest" are not all one region, but "MIDT &
    /// VEST" is not a new one either. Danish letters are letters as far as `isLetter` is
    /// concerned, so Østjylland keeps its Ø and does not collide with anything.
    static func identifier(for name: String) -> String {
        var parts: [String] = []
        var current = ""

        for character in name.lowercased() {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                parts.append(current)
                current = ""
            }
        }
        if !current.isEmpty { parts.append(current) }

        return parts.joined(separator: "-")
    }
}

extension DRChannel {

    /// The identifier of the region this channel serves, where it serves one.
    ///
    /// Kept alongside `district` rather than replacing it: that stays the name to show,
    /// this is the thing to compare.
    var districtID: String? {
        district.map(District.identifier(for:))
    }
}
