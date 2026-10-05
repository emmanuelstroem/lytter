//
//  CarPlayConfigurationTests.swift
//  lytterTests
//

import Foundation
import Testing
#if os(iOS)
import CarPlay
@testable import lytter
#endif

/// The wiring CarPlay needs before it will show the app at all (F21). None of it fails a
/// build when wrong: the car's screen just never lists the app.
struct CarPlayConfigurationTests {

    private static var repository: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func plist(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repository.appendingPathComponent(path))
        return try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    #if os(iOS)
    /// Read from the Info.plist that shipped, after Xcode's generated keys: the generated
    /// scene manifest once replaced this one with an empty list of configurations.
    @MainActor
    @Test func builtAppDeclaresTheCarPlaySceneWithADelegateThatExists() throws {
        let manifest = try #require(
            Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any])
        let configurations = try #require(manifest["UISceneConfigurations"] as? [String: Any])
        let carPlay = try #require(
            configurations["CPTemplateApplicationSceneSessionRoleApplication"] as? [[String: Any]])
        let className = try #require(carPlay.first?["UISceneDelegateClassName"] as? String)

        let delegate: AnyClass? = NSClassFromString(className)
        #expect(delegate === CarPlaySceneDelegate.self, "\(className) does not resolve")
        #expect(delegate?.conforms(to: CPTemplateApplicationSceneDelegate.self) == true)
    }
    #endif

    /// The simulator's file is the device's plus CarPlay, and nothing else: a key added to
    /// one and not the other would work in one place only.
    @Test func simulatorEntitlementsAreTheDevicesPlusCarPlay() throws {
        var simulator = try Self.plist("lytter/lytter-simulator.entitlements")
        let device = try Self.plist("lytter/lytter.entitlements")

        #expect(simulator.removeValue(forKey: "com.apple.developer.carplay-audio") as? Bool == true)
        #expect(NSDictionary(dictionary: simulator) == NSDictionary(dictionary: device))
    }

    /// Until Apple grants it, the key on a device build fails every device build's signing.
    @Test func deviceEntitlementsDoNotClaimCarPlayYet() throws {
        let device = try Self.plist("lytter/lytter.entitlements")
        #expect(device["com.apple.developer.carplay-audio"] == nil)
    }
}
