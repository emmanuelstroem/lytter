//
//  StationTileType.swift
//  WidgetShared
//

import SwiftUI

/// How a station's name is set on its tile — the app's `StationNameTile` and the widgets'
/// Favourites tiles — so the two cannot drift apart.
///
/// Sized to the tile: heavy, at 41% of its width and tracked in a little, the proportions
/// of the mockup the tiles were designed from (28 points on a 68-point tile). "P3" then
/// spans nearly half the tile. At 36% it sat small in the middle, with the space around it
/// doing nothing.
nonisolated enum StationTileType {
    /// The name's point size, as a share of the tile's width.
    static let sizeShare: CGFloat = 0.41
    /// Tracking, as a share of the point size: −0.5 at 28 points.
    static let trackingShare: CGFloat = -0.018
    /// Clear space on each side, as a share of the tile's width. A name too long for what
    /// is left — not one of DR's — shrinks rather than touching the edge.
    static let paddingShare: CGFloat = 0.08

    static func size(forWidth width: CGFloat) -> CGFloat { width * sizeShare }
}

extension Text {
    /// The station's name, set for a tile `width` points wide.
    nonisolated func stationTileName(width: CGFloat) -> some View {
        let size = StationTileType.size(forWidth: width)
        return self
            .font(.system(size: size, weight: .heavy))
            .tracking(size * StationTileType.trackingShare)
            .minimumScaleFactor(0.3)
            .lineLimit(1)
    }
}
