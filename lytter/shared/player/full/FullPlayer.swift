//
//  FullPlayer.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

// MARK: - Full Player Sheet
/// Platform shim for the full player.
///
/// Everything else this type used to hold — channel colour and icon, the title and
/// subtitle, the programme description, and four `@State` values — was an unused copy of
/// what `iOSFullPlayerSheet` computes for itself. The body has only ever forwarded, so
/// none of it could appear on screen. It went when the strings were localised, rather
/// than have the catalog carry translations for text nothing can display.
struct FullPlayerSheet: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState

    var body: some View {
        #if os(iOS)
        iOSFullPlayerSheet(serviceManager: serviceManager, selectionState: selectionState)
        #endif
    }
}

#Preview {
    FullPlayerSheet(
        serviceManager: DRServiceManager(),
        selectionState: SelectionState()
    )
}
