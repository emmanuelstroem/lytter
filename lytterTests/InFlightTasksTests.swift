//
//  InFlightTasksTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// The image cache coalesces concurrent requests for the same artwork onto one download.
/// Cleanup used to be unconditional, which broke that in a way nothing would notice: two
/// callers can await the same task, and by the time the second retires it a third may
/// already have registered a new one under that key.
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION
/// = MainActor, so the types under test are main-actor isolated by inference. Swift 6
/// rejects calling them from a nonisolated suite.
@MainActor
struct InFlightTasksTests {

    @Test func callersForTheSameKeyShareOneTask() {
        let registry = InFlightTasks<Int>()
        var made = 0

        let first = registry.claim("p1") { made += 1; return Task { 1 } }
        let second = registry.claim("p1") { made += 1; return Task { 2 } }

        #expect(made == 1, "the second caller should have joined the first, not started work")
        #expect(first == second)
        #expect(registry.count == 1)
    }

    @Test func differentKeysDoNotShare() {
        let registry = InFlightTasks<Int>()

        let a = registry.claim("p1") { Task { 1 } }
        let b = registry.claim("p3") { Task { 3 } }

        #expect(a != b)
        #expect(registry.count == 2)
    }

    @Test func retiringTheRegisteredTaskClearsTheKey() {
        let registry = InFlightTasks<Int>()
        let task = registry.claim("p1") { Task { 1 } }

        registry.release(task, for: "p1")

        #expect(registry.count == 0)
    }

    /// The race, as a sequence: A and B share one task; A retires it; C registers a fresh
    /// one; B — which has been waiting all along — retires *its* task. B must not take C's
    /// entry with it.
    @Test func aLateCallerCannotRetireSomeoneElsesTask() {
        let registry = InFlightTasks<Int>()

        let shared = registry.claim("p1") { Task { 1 } }        // A claims
        _ = registry.claim("p1") { Task { 99 } }                // B joins the same task
        registry.release(shared, for: "p1")                     // A finishes and retires it

        let replacement = registry.claim("p1") { Task { 2 } }   // C starts a new one
        registry.release(shared, for: "p1")                     // B finishes, retires stale

        #expect(registry.count == 1, "B retired C's task, so the next request downloads twice")
        let stillThere = registry.claim("p1") { Task { 3 } }
        #expect(stillThere == replacement)
    }

    @Test func retiringAnUnknownKeyIsHarmless() {
        let registry = InFlightTasks<Int>()
        let orphan = Task { 1 }

        registry.release(orphan, for: "never-registered")

        #expect(registry.count == 0)
    }
}
