//
//  UserAgent.swift
//  lytter
//

import Foundation

/// How Lytter names itself to the servers it asks: the app, its version and build, and the
/// platform it runs on — "Lytter/1.0 (iOS; build 1)".
///
/// It used to send `lytter/1.0 tvOS` from every platform and every release, and nothing of
/// its own with artwork, so DR could not tell Lytter's requests apart or know which
/// version made them.
///
/// ⚠️ The format is duplicated in `TopShelfExtension/TopShelfNetworkService.swift`, which is
/// a separate target and cannot see this type. Change one and change the other.
enum UserAgent {
    nonisolated static let value = make(info: Bundle.main.infoDictionary ?? [:],
                                        platform: platform)

    nonisolated static func make(info: [String: Any], platform: String) -> String {
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        return "Lytter/\(version) (\(platform); build \(build))"
    }

    nonisolated static var platform: String {
        #if os(visionOS)
        "visionOS"
        #elseif os(tvOS)
        "tvOS"
        #elseif os(macOS)
        "macOS"
        #else
        "iOS"
        #endif
    }
}

extension URLSessionConfiguration {
    /// `.default`, with every request naming Lytter (`UserAgent`).
    nonisolated static var lytter: URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": UserAgent.value]
        return config
    }
}
