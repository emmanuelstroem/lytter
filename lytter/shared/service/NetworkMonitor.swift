//
//  NetworkMonitor.swift
//  lytter
//

import Foundation
import Network

/// Whether the device has a route to the internet, from `NWPathMonitor`.
///
/// This is what tells "you are offline" apart from "DR is not answering". A failed request
/// cannot: `DRNetworkService` waits for connectivity, so an offline request does not fail
/// as offline — it waits and then times out, exactly as a request to a DR that is down does.
/// It is also what makes recovery automatic: the moment the path comes back,
/// `DRServiceManager` reloads what failed instead of waiting for the listener to ask.
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "lytter.network-monitor", qos: .utility)

    /// Starts watching. `onChange` runs on the main actor with the current state at once,
    /// then whenever it changes.
    func start(onChange: @escaping @MainActor (Bool) -> Void) {
        #if DEBUG
        if UITestFixtures.isActive {
            UITestFixtures.simulatePath(onChange)
            return
        }
        #endif
        // Explicitly @Sendable: the handler runs on `queue`, and a closure formed here would
        // otherwise be inferred main-actor isolated and trap when called from it.
        monitor.pathUpdateHandler = { @Sendable path in
            let online = path.status == .satisfied
            Task { @MainActor in onChange(online) }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
