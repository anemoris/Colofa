////
//  StashCreationDraft.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The open Stash sheet: what the entry will be called, and the two exceptions to what Git saves
/// by default.
///
/// Both options start off. Keeping the index and sweeping in files Git has never recorded are
/// each a departure from what Stash ordinarily means, so they are asked for rather than assumed.
nonisolated struct StashCreationDraft: Equatable, Sendable {
    var message = ""

    /// Leaves whatever is Staged in the index after the Stash is saved. The Stash still holds it;
    /// this decides only what the working tree is left looking like.
    var keepsStagedChanges = false

    /// Adds paths Git is not tracking. Ignored paths are never included, whichever way this is
    /// set: `--include-untracked` deliberately, and never `--all`.
    var includesUntrackedFiles = false

    /// Why Git refused the last attempt, or `nil` when nothing stands against the sheet as it is.
    ///
    /// Reported inside the sheet rather than over it: the message and the two options are what
    /// the user would change, and an alert would take them away to say so.
    private(set) var failure: GitFailureDetails?

    var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func recordFailure(_ failure: GitFailureDetails) {
        self.failure = failure
    }

    mutating func clearFailure() {
        failure = nil
    }

    /// What Git is asked to save.
    ///
    /// The message travels in the argument list rather than on standard input, which is where a
    /// Commit message goes: `git stash push` accepts one only as `-m`, so there is no other way
    /// to give it one. It is the user's own text and reaches the same redaction every other
    /// argument does.
    var arguments: [String] {
        var arguments = ["stash", "push"]
        if keepsStagedChanges {
            arguments.append("--keep-index")
        }
        if includesUntrackedFiles {
            arguments.append("--include-untracked")
        }
        let message = trimmedMessage
        if !message.isEmpty {
            arguments += ["-m", message]
        }
        return arguments
    }
}
