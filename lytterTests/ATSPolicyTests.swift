//
//  ATSPolicyTests.swift
//  lytterTests
//

import Foundation
import Testing

/// S8: App Transport Security is stated, not inherited, and carries no exception. Every
/// host the app talks to is HTTPS, so the only key the policy needs is
/// `NSAllowsArbitraryLoads = false`. The comparison is exact on purpose: an exception
/// domain or a media/web-content carve-out added later has to come through here and be
/// argued for, rather than slipping in alongside the explicit `false`.
struct ATSPolicyTests {

    private static var expected: NSDictionary { ["NSAllowsArbitraryLoads": false] }

    /// `Bundle.main` is the host app, so this reads the Info.plist that actually shipped
    /// in the build, after Xcode has merged in the generated keys.
    @Test func builtAppDeclaresATSWithNoExceptions() {
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? NSDictionary
        #expect(ats == Self.expected, "NSAppTransportSecurity is \(String(describing: ats))")
    }

    /// The Top Shelf extension is tvOS-only and the unit tests do not run there, so its
    /// policy is read from the source plist.
    @Test(arguments: ["lytter/Info.plist", "TopShelfExtension/Info.plist"])
    func sourcePlistDeclaresATSWithNoExceptions(path: String) throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: repository.appendingPathComponent(path))
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let ats = plist["NSAppTransportSecurity"] as? NSDictionary
        #expect(ats == Self.expected, "\(path): NSAppTransportSecurity is \(String(describing: ats))")
    }
}
