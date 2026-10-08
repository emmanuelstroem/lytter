//
//  visionOSContentView.swift
//  lytter
//

#if os(visionOS)
import SwiftUI

/// The app on Apple Vision Pro: the iPhone's screens, in a window of glass.
///
/// The same three tabs as the phone, which visionOS draws as an ornament down the window's
/// leading edge. What differs is the chrome. There is no tab-bar accessory to hold the mini
/// player, so it floats below the window in an ornament of its own. There is no page
/// background either: the window's glass is the background (see `AppBackground`).
///
/// Deep links and the full player are handled by `ContentView`, around this, exactly as
/// they are around the phone's tabs.
struct visionOSContentView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @Binding var selectedTabIndex: Int

    /// The ornament's corner. The artwork inside it is 10 and inset 10 from its edge, and
    /// meets this corner, so this is 10 + 10 (AGENTS.md, concentricity).
    static let miniPlayerCornerRadius: CGFloat = 20

    var body: some View {
        TabView(selection: $selectedTabIndex) {
            Tab("Home", systemImage: "house", value: 0) {
                HomeView(serviceManager: serviceManager, selectionState: selectionState,
                         preferences: serviceManager.userPreferences)
            }
            Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) {
                SearchView(serviceManager: serviceManager, selectionState: selectionState,
                           preferences: serviceManager.userPreferences)
            }
            Tab("Settings", systemImage: "gearshape", value: 3) {
                iOSSettingsView(preferences: serviceManager.userPreferences,
                                channels: serviceManager.availableChannels)
            }
        }
        // The phone's accent, which its TabView sets the same way.
        .tint(.purple)
        // Below the window, and only once something has been chosen: an empty bar under a
        // window that has not played anything yet is chrome with nothing to say.
        .ornament(visibility: serviceManager.playingChannel == nil ? .hidden : .visible,
                  attachmentAnchor: .scene(.bottom),
                  contentAlignment: .top) {
            // No AirPlay button: visionOS has no route picker for an app to show, and
            // sends audio elsewhere from Control Centre.
            MiniPlayerComponents(playingChannel: serviceManager.playingChannel, config: .minimized)
                .environmentObject(serviceManager)
                .environmentObject(selectionState)
                .id(serviceManager.playingChannel?.id ?? "no-channel")
                .frame(width: 460)
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Self.miniPlayerCornerRadius,
                                                            style: .continuous))
                .padding(.top, 16)
        }
    }
}
#endif
