//
//  UserAgentTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// Every request names Lytter, its version and the platform it runs on. It used to say
/// `lytter/1.0 tvOS` from every platform and release, and nothing with artwork.
@MainActor
struct UserAgentTests {

    @Test func itNamesTheAppItsVersionAndThePlatform() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2", "CFBundleVersion": "34"]
        #expect(UserAgent.make(info: info, platform: "macOS") == "Lytter/1.2 (macOS; build 34)")
    }

    /// The version is the bundle's and the platform the one this runs on, never a constant.
    @Test func itIsThisBuildOnThisPlatform() throws {
        #if os(visionOS)
        let platform = "visionOS"
        #elseif os(tvOS)
        let platform = "tvOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "iOS"
        #endif
        let version = try #require(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        let build = try #require(Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
        #expect(UserAgent.value == "Lytter/\(version) (\(platform); build \(build))")
    }

    /// Both of the app's sessions — the API's and the artwork's — are made from this.
    @Test func theSessionConfigurationSendsIt() {
        let headers = URLSessionConfiguration.lytter.httpAdditionalHeaders
        #expect(headers?["User-Agent"] as? String == UserAgent.value)
    }
}
