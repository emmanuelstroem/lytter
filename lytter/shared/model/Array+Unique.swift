//
//  Array+Unique.swift
//  lytter
//

import Foundation

// MARK: - Array Extension
extension Array where Element: Hashable {
    /// Order-preserving.
    ///
    /// This was `Array(Set(self))`, which discards order — and Swift seeds its hashing
    /// per process, so the district list under P4 and P5 came out in a different order on
    /// every launch.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array {
    /// Order-preserving: the first element for each key is kept.
    func uniqued<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert(key($0)).inserted }
    }
}
