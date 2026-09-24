import SwiftUI

#if os(iOS)
// MARK: - District Selection Sheet
struct DistrictSelectionSheet: View {
    let groupedChannel: GroupedChannel
    @ObservedObject var serviceManager: DRServiceManager
    let onChannelSelect: (DRChannel) -> Void
    @Environment(\.dismiss) private var dismiss
    
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

    var body: some View {
        ScrollView {
            if #available(iOS 26.0, *) {
                VStack(spacing: 16) {
                    ForEach(groupedChannel.channels, id: \.id) { channel in
                        Button(action: {
                            onChannelSelect(channel)
                            dismiss()
                        }) {
                            Text(channel.district ?? channel.name)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.glass) // shows background on buttons
                        .contextMenu { favouriteButton(for: channel) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            } else {
                // Fallback on earlier versions
                VStack(spacing: 16) {
                    ForEach(groupedChannel.channels, id: \.id) { channel in
                        VStack {
                            Text(channel.district ?? channel.name)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemBackground).opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .onTapGesture {
                            onChannelSelect(channel)
                            dismiss()
                        }
                        // A tap gesture on a VStack is not announced as anything
                        // actionable; the iOS 26 path above uses a real Button.
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .contextMenu { favouriteButton(for: channel) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
} 
#endif
