//
//  Tabs.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
extension XCUIApplication {
    /// One of the app's tabs, by its title, on iPhone or iPad.
    ///
    /// On iPhone the tabs are a tab bar along the bottom. On iPad with iOS 26 they float at
    /// the top of the window, and XCUITest sees no tab bar at all: each tab is a button named
    /// for it, twice over (the item and the view inside it), so the first is taken.
    @MainActor
    func tab(_ title: String) -> XCUIElement {
        UIDevice.current.userInterfaceIdiom == .pad
            ? buttons[title].firstMatch
            : tabBars.buttons[title]
    }
}
#endif
