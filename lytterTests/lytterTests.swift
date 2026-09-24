//
//  lytterTests.swift
//  lytterTests
//
//  Created by Emmanuel on 07/08/2025.
//

import Testing

/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION
/// = MainActor, so the types under test are main-actor isolated by inference. Swift 6
/// rejects calling them from a nonisolated suite.
@MainActor
struct lytterTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}
