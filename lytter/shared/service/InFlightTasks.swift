//
//  InFlightTasks.swift
//  lytter
//

import Foundation

/// Coalesces concurrent work by key, so N callers asking for the same thing share one
/// task instead of starting N.
///
/// This was a dictionary and an `NSLock` inline in `ImageCacheService`, and it had a race.
/// Cleanup was unconditional — `inFlight[key] = nil` — but two callers can await the *same*
/// task, and by the time the second one cleans up, a third may already have registered a
/// new task under that key. The second caller then wiped the third's entry, and the next
/// request downloaded an image that was already on its way.
///
/// `release` takes the task it is retiring and only removes it if it is still the
/// registered one, which is what makes that ordering harmless.
///
/// The lock is held only inside these synchronous methods. That is deliberate: `NSLock`'s
/// `lock`/`unlock` are unavailable from async contexts — a hard error under Swift 6 — and
/// keeping the critical sections out of `async` functions is both what silences it and the
/// clearer arrangement, since it makes it impossible to hold the lock across a suspension.
final class InFlightTasks<Value: Sendable>: @unchecked Sendable {

    private var tasks: [String: Task<Value, Never>] = [:]
    private let lock = NSLock()

    /// The task already running for `key`, or a newly registered one.
    ///
    /// `makeTask` runs while the lock is held, so two callers arriving together cannot
    /// both decide to start the work.
    func claim(_ key: String, makeTask: () -> Task<Value, Never>) -> Task<Value, Never> {
        lock.lock()
        defer { lock.unlock() }

        if let existing = tasks[key] { return existing }
        let created = makeTask()
        tasks[key] = created
        return created
    }

    /// Retires `task`, if it is still the one registered for `key`.
    func release(_ task: Task<Value, Never>, for key: String) {
        lock.lock()
        defer { lock.unlock() }

        if tasks[key] == task { tasks[key] = nil }
    }

    /// How many keys are currently in flight. For tests.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return tasks.count
    }
}
