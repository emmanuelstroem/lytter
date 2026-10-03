//
//  TVScrollingCoverageTests.swift
//  lytterTests
//

import Foundation
import Testing

/// Makes a new scrolling surface on tvOS impossible to add without a test that scrolls it.
///
/// On Apple TV, a list scrolls only if something in it can take focus, and a surface that
/// cannot scroll looks exactly like one that can until someone picks up a remote. Two
/// shipped that way. `TVScrollingUITests` drives each one with the remote; this suite keeps
/// that list complete by reading the tvOS sources and failing on any scrolling container
/// that is not listed below against a test that exists.
///
/// Adding a scroll view to a tvOS file? Add a test for it to `TVScrollingUITests`, then add
/// the file and the test's name here.
@MainActor
struct TVScrollingCoverageTests {

    /// Every tvOS file that contains something scrollable, and the UI tests that scroll it.
    private static let covered: [String: [String]] = [
        "tvOSHomeView.swift": ["testHomeScrollsDownToLowerShelves"],
        "tvOSChannelShelf.swift": ["testShelfScrollsSideways"],
        "tvOSVariantMenu.swift": ["testDistrictPickerScrolls"],
        "tvOSChannelScheduleSheet.swift": ["testScheduleScrolls"],
        "tvOSScrollingText.swift": ["testInfoDescriptionScrolls"],
        "tvOSRadioView.swift": ["testRadioShelfScrollsSideways"],
        "tvOSSearchView.swift": ["testSearchResultsScroll"],
        "tvOSSettingsView.swift": ["testSettingsScrolls"],
    ]

    /// What counts as a scrolling container: SwiftUI's, and UIKit's once it is told to scroll.
    private static let markers = ["ScrollView(", "ScrollView {", "List(", "List {", "Form {",
                                  "isScrollEnabled = true"]

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()        // lytterTests
            .deletingLastPathComponent()        // repository
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repository.appendingPathComponent(path), encoding: .utf8)
    }

    /// Code lines only: a comment that mentions `ScrollView(` is not one.
    private static func codeLines(of text: String) -> [String] {
        text.split(separator: "\n").map(String.init).filter { line in
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
    }

    @Test func everyScrollingSurfaceOnTVOSHasAUITest() throws {
        let folder = Self.repository.appendingPathComponent("lytter/tvos")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasSuffix(".swift") }
        #expect(!files.isEmpty, "found no tvOS sources at \(folder.path)")

        for file in files.sorted() {
            let lines = Self.codeLines(of: try Self.source("lytter/tvos/\(file)"))
            let scrolls = lines.contains { line in Self.markers.contains { line.contains($0) } }
            if scrolls {
                #expect(Self.covered[file] != nil,
                        "\(file) contains a scrolling container that no UI test scrolls. Add a test to TVScrollingUITests and list it in TVScrollingCoverageTests.covered.")
            }
        }
    }

    @Test func everyListedUITestExists() throws {
        let uiTests = try Self.source("lytterUITests/TVScrollingUITests.swift")

        for (file, tests) in Self.covered {
            for test in tests {
                #expect(uiTests.contains("func \(test)("),
                        "\(file) is listed against \(test), which TVScrollingUITests does not have.")
            }
        }
    }

    @Test func everyListedFileStillScrolls() throws {
        for file in Self.covered.keys {
            let lines = Self.codeLines(of: try Self.source("lytter/tvos/\(file)"))
            #expect(lines.contains { line in Self.markers.contains { line.contains($0) } },
                    "\(file) is listed as scrolling but no longer has a scrolling container; remove it, and its test if nothing else uses it.")
        }
    }
}
