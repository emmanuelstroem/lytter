//
//  AppGroup.swift
//  WidgetShared
//

import Foundation

/// The app group the app and its widgets share a container through. The Top Shelf
/// extension declares the same group and keeps its own copy of the name.
nonisolated enum AppGroup {
    static let identifier = "group.com.eopio.lytter"
}
