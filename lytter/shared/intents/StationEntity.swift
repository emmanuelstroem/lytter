//
//  StationEntity.swift
//  lytter
//

#if os(iOS)
import AppIntents

/// A channel, as the Shortcuts app's actions see it (F15).
///
/// One entity per channel rather than per station: "P4 Fyn" has to be something a
/// shortcut can name. A spoken "P4" is narrowed to the listener's region by
/// `StationQuery`, through `StationLookup`.
///
/// `nonisolated`, as everything AppIntents looks up is — see `PlaybackIntents.swift`.
nonisolated struct StationEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Station")
    static let defaultQuery = StationQuery()

    /// The channel's id, which DR keeps stable; a saved shortcut stores it.
    let id: String
    /// "P4 - Fyn", or "P3" for a channel with no district.
    let name: String

    /// The name as it is: a station's name is a proper noun, not a catalogue key.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }

    @MainActor
    init(channel: DRChannel) {
        id = channel.id
        name = channel.qualifiedName
    }
}

nonisolated struct StationQuery: EntityStringQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [StationEntity] {
        let channels = await StationCatalogue.channels()
        return identifiers.compactMap { id in
            channels.first { $0.id == id }.map(StationEntity.init(channel:))
        }
    }

    @MainActor
    func entities(matching string: String) async throws -> [StationEntity] {
        let manager = DRServiceManager.shared
        return StationLookup.channels(answering: string,
                                      in: await StationCatalogue.channels(),
                                      region: manager.userPreferences.preferredDistrict)
            .map(StationEntity.init(channel:))
    }

    /// Every channel, in the order the app lists them — what the Shortcuts editor offers
    /// and what Siri learns the names from.
    @MainActor
    func suggestedEntities() async throws -> [StationEntity] {
        GroupedChannel.grouped(from: await StationCatalogue.channels())
            .flatMap(\.channels)
            .map(StationEntity.init(channel:))
    }
}

#endif
