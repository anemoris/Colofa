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

    /// A stand-in for the Commit `git rev-parse` reports for a Branch: stable per name, so a
    /// confirmation and the read taken before the command agree with each other.
    static func branchObjectID(of branch: String) -> String {
        "ui-branch-\(branch)"
    }

    /// How many Commits the fixture says only `branch` holds.
    ///
    /// Zero unless a test asked otherwise, because an ordinary local branch in the fixture is one
    /// every other Ref already holds — the case Git's own safe deletion carries.
    static func uniqueCommitCount(of branch: String, arguments: [String]) -> Int {
        arguments.contains(UITestingArgument.unmergedBranch) ? unmergedCommitCount : 0
    }

    /// The count the unmerged fixture reports, which the confirmation shows verbatim.
    static let unmergedCommitCount = 3

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
