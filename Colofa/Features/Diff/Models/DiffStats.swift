////
//  DiffStats.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

nonisolated struct DiffStats: Equatable, Sendable {
    let additions: Int
    let deletions: Int

    static let zero = Self(additions: 0, deletions: 0)

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(
            additions: lhs.additions + rhs.additions,
            deletions: lhs.deletions + rhs.deletions
        )
    }
}
