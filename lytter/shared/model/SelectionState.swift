//
//  SelectionState.swift
//  lytter
//

import Foundation
import Combine

// MARK: - Selection State
class SelectionState: ObservableObject {
    @Published var selectedChannel: DRChannel?

    /// Whether the full player is presented.
    ///
    /// This cannot live in the mini player. The mini player is the tab bar's bottom
    /// accessory, and `LiquidGlassMiniPlayer` switches on
    /// `tabViewBottomAccessoryPlacement` — so SwiftUI rebuilds it from a different
    /// branch whenever the placement changes, which is exactly what covering the tab bar
    /// with a sheet does. A `@State` flag there was destroyed on that rebuild and the
    /// sheet dismissed itself the moment it appeared. The `.id(playingChannel?.id)` on
    /// the accessory threw the same state away whenever the channel changed.
    @Published var isShowingFullPlayer = false
    
    func selectChannel(_ channel: DRChannel, showSheet: Bool = false) {
        selectedChannel = channel
    }
}
