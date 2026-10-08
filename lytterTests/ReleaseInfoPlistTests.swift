//
//  ReleaseInfoPlistTests.swift
//  lytterTests
//

import Foundation
import Testing

/// The Info.plist keys App Store Connect and App Review read, which nothing in the running
/// app would notice going missing:
///
/// - `ITSAppUsesNonExemptEncryption = false`. Lytter's only cryptography is HTTPS, which is
///   exempt; without the key every upload stops at the export-compliance question.
/// - `LSApplicationCategoryType`. A macOS upload is refused without one.
/// - `NSHumanReadableCopyright`, on the app and on both extensions, which shipped as `""`.
/// - `NSSiriUsageDescription`, with its Danish in `InfoPlist.xcstrings`. The Siri prompt is
///   the system's dialog, so a missing translation shows English to a Danish listener.
///   (The system draws it in the *device's* language: `-AppleLanguages` on the app alone
///   leaves it in English.)
struct ReleaseInfoPlistTests {

    private static let copyright = "© 2026 Emmanuel Opio"

    private static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// `Bundle.main` is the host app: the Info.plist that actually shipped, after Xcode has
    /// merged in the generated keys.
    @Test func builtAppDeclaresExportCompliance() {
        let value = Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool
        #expect(value == false, "ITSAppUsesNonExemptEncryption is \(String(describing: value))")
    }

    /// Not on visionOS: Xcode leaves the generated key out of a visionOS build, and the
    /// category there comes from App Store Connect alone.
    #if !os(visionOS)
    @Test func builtAppDeclaresMusicCategory() {
        let value = Bundle.main.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        #expect(value == "public.app-category.music")
    }
    #endif

    @Test func builtAppDeclaresCopyright() {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
        #expect(value == Self.copyright)
    }

    /// The extensions are not hosts the unit tests run in (Top Shelf is tvOS-only), so their
    /// generated keys are read from the project's build settings: every configuration of
    /// every target that sets a copyright must set this one.
    @Test func everyTargetSetsTheSameCopyright() throws {
        let project = try String(
            contentsOf: Self.repository.appendingPathComponent("lytter.xcodeproj/project.pbxproj"),
            encoding: .utf8)
        let values = project
            .components(separatedBy: .newlines)
            .filter { $0.contains("INFOPLIST_KEY_NSHumanReadableCopyright") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        // App, widgets and Top Shelf, Debug and Release.
        #expect(values.count == 6)
        #expect(values.allSatisfy { $0 == "INFOPLIST_KEY_NSHumanReadableCopyright = \"\(Self.copyright)\";" },
                "\(values)")
    }

    @Test func builtAppDeclaresSiriUsage() {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSSiriUsageDescription") as? String
        #expect(value?.isEmpty == false)
    }

    /// The Danish lives in the source catalog, which compiles to `da.lproj/InfoPlist.strings`.
    @Test func siriUsageDescriptionHasDanish() throws {
        let data = try Data(contentsOf: Self.repository.appendingPathComponent("lytter/InfoPlist.xcstrings"))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        let entry = try #require(strings["NSSiriUsageDescription"] as? [String: Any])
        let localizations = try #require(entry["localizations"] as? [String: Any])
        let danish = (localizations["da"] as? [String: Any])?["stringUnit"] as? [String: Any]
        #expect(danish?["state"] as? String == "translated")
        #expect((danish?["value"] as? String)?.isEmpty == false)
    }

    /// And it reaches the built app: the Danish table is in the bundle.
    ///
    /// It must carry the display name too. Once a language has an `InfoPlist.strings`, the
    /// system takes the app's name from it, and without `CFBundleDisplayName` the Shortcuts
    /// button read "-genveje" in Danish rather than "Lytter-genveje".
    @Test func builtAppCarriesDanishInfoPlistStrings() throws {
        let path = try #require(Bundle.main.path(forResource: "InfoPlist", ofType: "strings",
                                                 inDirectory: nil, forLocalization: "da"))
        let table = try #require(NSDictionary(contentsOfFile: path))
        #expect((table["NSSiriUsageDescription"] as? String)?.hasPrefix("Lytter bruger Siri") == true)
        #expect(table["CFBundleDisplayName"] as? String == "Lytter")
    }
}
