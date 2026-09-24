//
//  Log.swift
//  lytter
//

import Foundation
import os

/// The app's loggers, one per subsystem area.
///
/// These replaced `print`, which had two problems. It writes to the console in release
/// builds as well as debug, and it has no notion of privacy — `DeepLinkHandler` was
/// printing every incoming URL verbatim, and those arrive from outside the app.
///
/// `Logger` fixes both. `.debug` messages are not persisted in release, and interpolated
/// strings are redacted as `<private>` unless explicitly marked `.public`. Anything that
/// came from outside the app, or that identifies what someone is listening to, stays
/// private; channel slugs and counts are public so the logs remain useful.
///
/// Read them with:
///
///     log stream --predicate 'subsystem == "com.eopio.lytter"' --level debug
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.eopio.lytter"

    /// Requests to DR's API — the one place to look when playback or the channel list
    /// misbehaves, and the only way to see whether polling actually stopped.
    static let network = Logger(subsystem: subsystem, category: "network")
    static let playback = Logger(subsystem: subsystem, category: "playback")
    static let deepLink = Logger(subsystem: subsystem, category: "deeplink")
    static let siri = Logger(subsystem: subsystem, category: "siri")
}
