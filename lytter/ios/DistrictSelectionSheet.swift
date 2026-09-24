//
//  DistrictSelectionSheet.swift
//  lytter
//

import SwiftUI

#if os(iOS)
/// Picks which regional variant of a station to play.
///
/// A plain `List` rather than a stack of capsules. This is a chooser, and the system already
/// knows what a chooser looks like: separators, touch targets, swipe actions, Dynamic Type
/// and the scrolling navigation title all arrive for free, and match every other sheet the
/// listener has ever seen.
///
/// The rows carry artwork and what is on air, because that is what makes the choice. Ten
/// place names tell you nothing about which one you want to listen to now.
struct DistrictSelectionSheet: View {
    let groupedChannel: GroupedChannel
    @ObservedObject var serviceManager: DRServiceManager
    let onChannelSelect: (DRChannel) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(groupedChannel.channels) { channel in
                        Button {
                            select(channel)
                        } label: {
                            row(for: channel)
                        }
                        // Without this the row's text takes the button tint and turns blue.
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            favouriteButton(for: channel).tint(.yellow)
                        }
                        .contextMenu { favouriteButton(for: channel) }
                    }
                } footer: {
                    // A section footer rather than a safe-area inset: an inset floats over
                    // the list, and at the medium detent it sat on top of the last row.
                    // This scrolls with the content, which is also where a listener looks
                    // for an explanation of what the list just did.
                    Text("Your region is remembered for other regional stations.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(groupedChannel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Opens half-height — ten districts do not fit, and a sheet that starts at half
        // says it can be dragged in a way a full-height one does not.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(for channel: DRChannel) -> some View {
        HStack(spacing: 12) {
            artwork(for: channel)

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.district ?? channel.name)
                    .font(.body)
                    .foregroundStyle(Color.primary)

                Text(subtitle(for: channel))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isPreferredRegion(channel) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }

            if serviceManager.userPreferences.isFavourite(channel.id) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
            }

            if isPlaying(channel) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        // Composed rather than a phrase, so no "%@, %@" reaches the catalogue.
        .accessibilityLabel(Text(verbatim: "\(channel.district ?? channel.name), \(subtitle(for: channel))"))
        .accessibilityAddTraits(isPlaying(channel) ? [.isButton, .isSelected] : .isButton)
    }

    private func artwork(for channel: DRChannel) -> some View {
        CachedAsyncImage(url: serviceManager.artworkURL(for: channel),
                         maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(Color(.tertiarySystemFill))
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func subtitle(for channel: DRChannel) -> String {
        serviceManager.getCurrentProgram(for: channel)?.programmeName ?? String(localized: "Live")
    }

    private func isPlaying(_ channel: DRChannel) -> Bool {
        serviceManager.playingChannel?.id == channel.id
    }

    private func isPreferredRegion(_ channel: DRChannel) -> Bool {
        guard let districtID = channel.districtID else { return false }
        return serviceManager.userPreferences.preferredDistrict?.id == districtID
    }

    /// Plays the district, and remembers it as the listener's region.
    ///
    /// Choosing here is the only signal the app gets about where someone is, and it is a
    /// reliable one — nobody picks Bornholm by accident. Recording it means the next
    /// regional station plays the right signal without asking again.
    private func select(_ channel: DRChannel) {
        if let name = channel.district {
            serviceManager.userPreferences.rememberDistrict(District(name: name))
        }
        onChannelSelect(channel)
        dismiss()
    }

    /// Pinning a district is only meaningful here, where you have said which one you mean —
    /// the card on Home stands for all ten.
    @ViewBuilder
    private func favouriteButton(for channel: DRChannel) -> some View {
        let isFavourite = serviceManager.userPreferences.isFavourite(channel.id)
        Button {
            serviceManager.userPreferences.toggleFavourite(channel.id)
        } label: {
            Label(isFavourite ? "Remove from Favourites" : "Add to Favourites",
                  systemImage: isFavourite ? "star.slash" : "star")
        }
    }
}
#endif
