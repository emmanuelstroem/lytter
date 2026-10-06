//
//  LytterWidgetsBundle.swift
//  LytterWidgets
//

import SwiftUI
import WidgetKit

/// Everything Lytter puts outside its own window on iPhone and iPad (F18).
@main
struct LytterWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
        FavouritesWidget()
        if #available(iOS 18.0, *) {
            ListeningControl()
        }
    }
}
