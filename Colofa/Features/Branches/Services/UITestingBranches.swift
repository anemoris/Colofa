////
//  UITestingBranches.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// What the stubbed backend answers about branch names and blocked Checkouts.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` reads these from an actor.
nonisolated enum UITestingBranches {
    /// The tracked path the blocked-Checkout fixture reports as locally changed, and the
    /// untracked one it reports as standing in the way. Both belong to the branch fixture's
    /// Changes, so the refusal names work the Repository really reports.
    static let blockedModifiedPath = "partial 文件.txt"
    static let blockedUntrackedPath = "notes.txt"

    /// A stand-in for `git check-ref-format --branch`, covering the rules a UI test exercises.
    /// The real rules are Git's, and the integration tests are what hold Colofa to them.
    static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty,
              name != "HEAD",
              !name.hasPrefix("-"),
              !name.hasPrefix("."),
              !name.hasSuffix("/"),
              !name.hasSuffix(".lock"),
              !name.contains("..") else {
            return false
        }
        return !name.contains(where: refusedCharacters.contains)
    }

    static func comparison(arguments: [String]) -> CheckoutComparison {
        guard arguments.contains(UITestingArgument.checkoutBlocked) else {
            return .empty
        }
        return CheckoutComparison(
            changedPaths: [blockedModifiedPath, blockedUntrackedPath],
            addedPaths: [blockedUntrackedPath]
        )
    }

    private static let refusedCharacters: Set<Character> = [
        " ", "~", "^", ":", "?", "*", "[", "\\",
    ]
}
#endif
